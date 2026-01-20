import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/ipv4_utils.dart';

/// Represents a change to an interface's IP address
class IpAddressChange {
  /// The previous IP address (null if newly assigned)
  final IPv4? oldAddress;

  /// The new IP address (null if removed)
  final IPv4? newAddress;

  /// Type of interface that changed
  final InterfaceChangeSource source;

  /// Interface index (for ports)
  final int? interfaceIndex;

  /// VLAN ID (for VLANs)
  final int? vlanId;

  IpAddressChange({
    this.oldAddress,
    this.newAddress,
    required this.source,
    this.interfaceIndex,
    this.vlanId,
  });

  /// Whether the network changed (not just the host portion)
  bool get networkChanged {
    if (oldAddress == null || newAddress == null) return true;

    final oldNet = IPv4Network.fromIPv4(oldAddress!);
    final newNet = IPv4Network.fromIPv4(newAddress!);

    return oldNet.networkAddressInt != newNet.networkAddressInt ||
        oldNet.prefixLength != newNet.prefixLength;
  }

  /// Whether the prefix length changed
  bool get prefixChanged {
    if (oldAddress == null || newAddress == null) return true;
    return oldAddress!.prefixLength != newAddress!.prefixLength;
  }

  /// Get the offset change if networks are related
  /// Returns the difference in network addresses if the prefix is the same
  int? get networkOffsetChange {
    if (oldAddress == null || newAddress == null) return null;
    if (prefixChanged) return null;

    final oldNet = IPv4Network.fromIPv4(oldAddress!);
    final newNet = IPv4Network.fromIPv4(newAddress!);

    return newNet.networkAddressInt - oldNet.networkAddressInt;
  }
}

/// Source of an IP address change
enum InterfaceChangeSource { port, vlan }

/// Service to handle IP address change propagation
class IpChangeRelayService {
  IpChangeRelayService._();

  /// Preview what changes would be made without applying them
  static IpChangePreview previewIpChange(
    NetDevice device,
    IpAddressChange change,
  ) {
    final dhcpPoolChanges = <DhcpPoolChangePreview>[];

    // Find all DHCP pools that reference this interface
    final affectedPools = _findAffectedDhcpPools(device, change);

    for (final poolEntry in affectedPools.entries) {
      final poolIndex = poolEntry.key;
      final pool = poolEntry.value;

      final update = _calculatePoolUpdate(pool, change);
      if (update.hasChanges) {
        dhcpPoolChanges.add(
          DhcpPoolChangePreview(
            poolName: pool.name,
            poolIndex: poolIndex,
            update: update,
            originalPool: pool,
          ),
        );
      }
    }

    return IpChangePreview(dhcpPoolChanges: dhcpPoolChanges);
  }

  /// Apply a previewed change
  static Future<IpChangeResult> applyPreviewedChange(
    NetDevice device,
    IpChangePreview preview,
  ) async {
    final result = IpChangeResult();

    if (!preview.hasChanges) {
      return result;
    }

    final poolUpdates = <int, DhcpPoolUpdate>{};
    for (final poolChange in preview.dhcpPoolChanges) {
      poolUpdates[poolChange.poolIndex] = poolChange.update;
      result.affectedPools.add(poolChange.poolName);
    }

    if (poolUpdates.isNotEmpty) {
      await _applyPoolUpdates(device, poolUpdates);
      result.success = true;
    }

    return result;
  }

  /// Handle an IP address change and update dependent configurations
  /// This applies changes immediately without confirmation
  static Future<IpChangeResult> handleIpChange(
    NetDevice device,
    IpAddressChange change,
  ) async {
    final preview = previewIpChange(device, change);
    return applyPreviewedChange(device, preview);
  }

  /// Find all DHCP pools affected by an interface change
  static Map<int, DhcpPoolConfig> _findAffectedDhcpPools(
    NetDevice device,
    IpAddressChange change,
  ) {
    final result = <int, DhcpPoolConfig>{};
    final pools = device.dhcpPools;

    for (int i = 0; i < pools.length; i++) {
      final pool = pools[i];

      bool isAffected = false;

      switch (change.source) {
        case InterfaceChangeSource.port:
          isAffected = pool.interfaceIndex == change.interfaceIndex;
          break;
        case InterfaceChangeSource.vlan:
          isAffected = pool.vlanId == change.vlanId;
          break;
      }

      if (isAffected) {
        result[i] = pool;
      }
    }

    return result;
  }

  /// Calculate updates needed for a DHCP pool based on an IP change
  static DhcpPoolUpdate _calculatePoolUpdate(
    DhcpPoolConfig pool,
    IpAddressChange change,
  ) {
    final update = DhcpPoolUpdate();

    if (change.newAddress == null) {
      // IP was removed - disable the pool but keep configuration
      update.enabled = false;
      return update;
    }

    final newNetwork = IPv4Network.fromIPv4(change.newAddress!);

    // Always update network address and mask
    update.network = newNetwork.networkAddress;
    update.subnetMask = newNetwork.subnetMask;

    // Handle address relay (offset-based migration)
    if (change.oldAddress != null && !change.prefixChanged) {
      final oldNetwork = IPv4Network.fromIPv4(change.oldAddress!);
      final offset =
          newNetwork.networkAddressInt - oldNetwork.networkAddressInt;

      // Relay default router
      if (pool.defaultRouter != null && pool.defaultRouter!.isNotEmpty) {
        final relayedRouter = _relayAddress(
          pool.defaultRouter!,
          offset,
          oldNetwork,
          newNetwork,
        );
        if (relayedRouter != null) {
          update.defaultRouter = relayedRouter;
        }
      }

      // Relay exclude start
      if (pool.excludeStart != null && pool.excludeStart!.isNotEmpty) {
        final relayedStart = _relayAddress(
          pool.excludeStart!,
          offset,
          oldNetwork,
          newNetwork,
        );
        if (relayedStart != null) {
          update.excludeStart = relayedStart;
        }
      }

      // Relay exclude end
      if (pool.excludeEnd != null && pool.excludeEnd!.isNotEmpty) {
        final relayedEnd = _relayAddress(
          pool.excludeEnd!,
          offset,
          oldNetwork,
          newNetwork,
        );
        if (relayedEnd != null) {
          update.excludeEnd = relayedEnd;
        }
      }
    } else if (change.oldAddress != null && change.prefixChanged) {
      // Prefix changed - try to preserve relative position if possible
      final oldNetwork = IPv4Network.fromIPv4(change.oldAddress!);

      // Relay with potential clamping
      if (pool.defaultRouter != null && pool.defaultRouter!.isNotEmpty) {
        final relayedRouter = _relayAddressWithClamping(
          pool.defaultRouter!,
          oldNetwork,
          newNetwork,
        );
        update.defaultRouter = relayedRouter;
      }

      if (pool.excludeStart != null && pool.excludeStart!.isNotEmpty) {
        final relayedStart = _relayAddressWithClamping(
          pool.excludeStart!,
          oldNetwork,
          newNetwork,
        );
        update.excludeStart = relayedStart;
      }

      if (pool.excludeEnd != null && pool.excludeEnd!.isNotEmpty) {
        final relayedEnd = _relayAddressWithClamping(
          pool.excludeEnd!,
          oldNetwork,
          newNetwork,
        );
        update.excludeEnd = relayedEnd;
      }
    } else {
      // New IP assigned - set default router to gateway
      update.defaultRouter = change.newAddress!.address;
    }

    return update;
  }

  /// Relay an address by applying an offset
  /// Returns null if the address was not in the old network
  static String? _relayAddress(
    String address,
    int offset,
    IPv4Network oldNetwork,
    IPv4Network newNetwork,
  ) {
    final addrInt = IPv4Math.addressToInt(address);
    if (addrInt == null) return null;

    // Check if address was in old network
    if (!oldNetwork.containsInt(addrInt)) return null;

    // Apply offset
    final newAddrInt = addrInt + offset;

    // Verify new address is in new network and valid
    if (!newNetwork.containsInt(newAddrInt)) return null;
    if (newNetwork.isNetworkAddress(newAddrInt)) {
      // Bump to first usable
      return IPv4Math.intToAddress(newAddrInt + 1);
    }
    if (newNetwork.isBroadcastAddress(newAddrInt)) {
      // Bump to last usable
      return IPv4Math.intToAddress(newAddrInt - 1);
    }

    return IPv4Math.intToAddress(newAddrInt);
  }

  /// Relay an address with clamping when prefix changes
  static String _relayAddressWithClamping(
    String address,
    IPv4Network oldNetwork,
    IPv4Network newNetwork,
  ) {
    final addrInt = IPv4Math.addressToInt(address);
    if (addrInt == null) {
      // Invalid address - use first usable in new network
      return newNetwork.addressAtOffset(1) ?? newNetwork.networkAddress;
    }

    // Get relative offset in old network
    final oldOffset = oldNetwork.offsetOf(address);
    if (oldOffset == null) {
      // Address wasn't in old network - use first usable
      return newNetwork.addressAtOffset(1) ?? newNetwork.networkAddress;
    }

    // Check if offset is valid in new network
    if (oldOffset < newNetwork.totalAddresses) {
      final newAddr = newNetwork.addressAtOffset(oldOffset);
      if (newAddr != null) {
        final newAddrInt = IPv4Math.addressToInt(newAddr)!;
        // Avoid network and broadcast addresses
        if (newNetwork.isNetworkAddress(newAddrInt)) {
          return newNetwork.addressAtOffset(1) ?? newNetwork.networkAddress;
        }
        if (newNetwork.isBroadcastAddress(newAddrInt)) {
          return newNetwork.addressAtOffset(newNetwork.totalAddresses - 2) ??
              newNetwork.broadcastAddress;
        }
        return newAddr;
      }
    }

    // Offset doesn't fit - clamp to last usable address
    return newNetwork.addressAtOffset(newNetwork.totalAddresses - 2) ??
        newNetwork.broadcastAddress;
  }

  /// Apply pool updates to the database
  static Future<void> _applyPoolUpdates(
    NetDevice device,
    Map<int, DhcpPoolUpdate> updates,
  ) async {
    final pools = device.dhcpPools;
    final updatedPools = <DhcpPoolConfig>[];

    for (int i = 0; i < pools.length; i++) {
      final pool = pools[i];
      final update = updates[i];

      if (update != null) {
        updatedPools.add(
          DhcpPoolConfig(
            name: pool.name,
            interfaceIndex: pool.interfaceIndex,
            vlanId: pool.vlanId,
            network: update.network ?? pool.network,
            subnetMask: update.subnetMask ?? pool.subnetMask,
            defaultRouter: update.defaultRouter ?? pool.defaultRouter,
            dnsServer: pool.dnsServer,
            dnsServerSecondary: pool.dnsServerSecondary,
            domainName: pool.domainName,
            leaseTime: pool.leaseTime,
            excludeStart: update.excludeStart ?? pool.excludeStart,
            excludeEnd: update.excludeEnd ?? pool.excludeEnd,
            enabled: update.enabled ?? pool.enabled,
          ),
        );
      } else {
        updatedPools.add(pool);
      }
    }

    await Database.updateDeviceConfig(device.id, {
      'dhcp_pools': updatedPools.map((p) => p.toJson()).toList(),
    });
  }
}

/// Result of an IP change relay operation
class IpChangeResult {
  bool success = false;
  List<String> affectedPools = [];
  List<String> errors = [];

  bool get hasAffectedPools => affectedPools.isNotEmpty;
}

/// Preview of changes that will be made
class IpChangePreview {
  final List<DhcpPoolChangePreview> dhcpPoolChanges;

  IpChangePreview({required this.dhcpPoolChanges});

  bool get hasChanges => dhcpPoolChanges.isNotEmpty;

  /// Get a human-readable summary of all changes
  List<String> get changeSummary {
    final summary = <String>[];
    for (final poolChange in dhcpPoolChanges) {
      summary.add('DHCP Pool "${poolChange.poolName}":');
      for (final change in poolChange.changes) {
        summary.add('  • $change');
      }
    }
    return summary;
  }
}

/// Preview of changes to a single DHCP pool
class DhcpPoolChangePreview {
  final String poolName;
  final int poolIndex;
  final DhcpPoolUpdate update;
  final DhcpPoolConfig originalPool;

  DhcpPoolChangePreview({
    required this.poolName,
    required this.poolIndex,
    required this.update,
    required this.originalPool,
  });

  /// Get human-readable list of changes
  List<String> get changes {
    final result = <String>[];
    if (update.network != null && update.network != originalPool.network) {
      result.add('Network: ${originalPool.network} → ${update.network}');
    }
    if (update.subnetMask != null &&
        update.subnetMask != originalPool.subnetMask) {
      result.add(
        'Subnet Mask: ${originalPool.subnetMask} → ${update.subnetMask}',
      );
    }
    if (update.defaultRouter != null &&
        update.defaultRouter != originalPool.defaultRouter) {
      result.add(
        'Default Router: ${originalPool.defaultRouter ?? "(none)"} → ${update.defaultRouter}',
      );
    }
    if (update.excludeStart != null &&
        update.excludeStart != originalPool.excludeStart) {
      result.add(
        'Exclude Start: ${originalPool.excludeStart ?? "(none)"} → ${update.excludeStart}',
      );
    }
    if (update.excludeEnd != null &&
        update.excludeEnd != originalPool.excludeEnd) {
      result.add(
        'Exclude End: ${originalPool.excludeEnd ?? "(none)"} → ${update.excludeEnd}',
      );
    }
    if (update.enabled != null && update.enabled != originalPool.enabled) {
      result.add('Enabled: ${originalPool.enabled} → ${update.enabled}');
    }
    return result;
  }
}

/// Updates to apply to a DHCP pool
class DhcpPoolUpdate {
  String? network;
  String? subnetMask;
  String? defaultRouter;
  String? excludeStart;
  String? excludeEnd;
  bool? enabled;

  bool get hasChanges =>
      network != null ||
      subnetMask != null ||
      defaultRouter != null ||
      excludeStart != null ||
      excludeEnd != null ||
      enabled != null;
}

/// Extension to calculate relay when updating an interface IP
extension IpRelayExtension on NetDevice {
  /// Check if changing an interface's IP would affect any DHCP pools
  bool hasAffectedDhcpPools({int? interfaceIndex, int? vlanId}) {
    for (final pool in dhcpPools) {
      if (interfaceIndex != null && pool.interfaceIndex == interfaceIndex) {
        return true;
      }
      if (vlanId != null && pool.vlanId == vlanId) {
        return true;
      }
    }
    return false;
  }

  /// Get affected DHCP pool names
  List<String> getAffectedDhcpPoolNames({int? interfaceIndex, int? vlanId}) {
    return dhcpPools
        .where(
          (pool) =>
              (interfaceIndex != null &&
                  pool.interfaceIndex == interfaceIndex) ||
              (vlanId != null && pool.vlanId == vlanId),
        )
        .map((p) => p.name)
        .toList();
  }
}

/// Mixin to add IP change relay handling to form controllers
mixin IpChangeRelayMixin {
  NetDevice? _relayDevice;
  int? _relayInterfaceIndex;
  int? _relayVlanId;
  String? _previousIpCidr;

  /// Set up relay for an interface
  void setupIpRelay({
    required NetDevice device,
    int? interfaceIndex,
    int? vlanId,
    String? currentIpCidr,
  }) {
    _relayDevice = device;
    _relayInterfaceIndex = interfaceIndex;
    _relayVlanId = vlanId;
    _previousIpCidr = currentIpCidr;
  }

  /// Call this when IP changes
  Future<IpChangeResult?> handleIpChangeRelay(String newIpCidr) async {
    if (_relayDevice == null) return null;

    final oldIp = _previousIpCidr != null && _previousIpCidr!.isNotEmpty
        ? IPv4.tryParse(_previousIpCidr!)
        : null;
    final newIp = newIpCidr.isNotEmpty ? IPv4.tryParse(newIpCidr) : null;

    // Check if anything actually changed
    if (oldIp?.toCIDR() == newIp?.toCIDR()) return null;

    final change = IpAddressChange(
      oldAddress: oldIp,
      newAddress: newIp,
      source: _relayVlanId != null
          ? InterfaceChangeSource.vlan
          : InterfaceChangeSource.port,
      interfaceIndex: _relayInterfaceIndex,
      vlanId: _relayVlanId,
    );

    final result = await IpChangeRelayService.handleIpChange(
      _relayDevice!,
      change,
    );

    // Update previous for next change
    _previousIpCidr = newIpCidr;

    return result;
  }

  /// Clear relay setup
  void clearIpRelay() {
    _relayDevice = null;
    _relayInterfaceIndex = null;
    _relayVlanId = null;
    _previousIpCidr = null;
  }
}
