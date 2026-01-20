import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/devices/switchport.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/port.dart';

/// Types of network interfaces
enum InterfaceType {
  /// Physical port (e.g., FastEthernet0/1)
  physicalPort,

  /// Subinterface (e.g., GigabitEthernet0/0.10)
  subinterface,

  /// VLAN SVI (e.g., VLAN 10)
  vlanSvi,

  /// Loopback interface
  loopback,

  /// Port-channel / EtherChannel
  portChannel,

  /// Tunnel interface (GRE, IPsec, etc.)
  tunnel,
}

/// A unified descriptor for any network interface
/// This abstracts away the differences between physical ports, VLANs, subinterfaces, etc.
class InterfaceDescriptor {
  /// Type of interface
  final InterfaceType type;

  /// Display name (e.g., "FastEthernet0/1", "VLAN 10", "GigabitEthernet0/0.10")
  final String name;

  /// Optional description set by user
  final String? description;

  /// IP address if configured
  final IPv4? ipAddress;

  /// Whether the interface is administratively enabled
  final bool enabled;

  /// Index in the device's interfaces list (for physical ports)
  final int? interfaceIndex;

  /// VLAN ID (for VLANs or subinterfaces)
  final int? vlanId;

  /// Port-channel number (for port-channels)
  final int? portChannelNumber;

  /// Switchport mode (for switchports)
  final SwitchportMode? switchportMode;

  /// Access VLAN (for access mode switchports)
  final int? accessVlan;

  /// Native VLAN (for trunk mode switchports)
  final int? nativeVlan;

  /// Whether this is a switchport (L2) or routed port (L3)
  final bool isSwitchport;

  /// Original port object (for reference)
  final Port? sourcePort;

  /// Original VLAN config (for reference)
  final VlanConfig? sourceVlan;

  InterfaceDescriptor({
    required this.type,
    required this.name,
    this.description,
    this.ipAddress,
    this.enabled = true,
    this.interfaceIndex,
    this.vlanId,
    this.portChannelNumber,
    this.switchportMode,
    this.accessVlan,
    this.nativeVlan,
    this.isSwitchport = false,
    this.sourcePort,
    this.sourceVlan,
  });

  /// Create from a physical port
  factory InterfaceDescriptor.fromPort(Port port, int index) {
    final isSwitchport = port is Switchport;
    return InterfaceDescriptor(
      type: port.name.contains('.')
          ? InterfaceType.subinterface
          : InterfaceType.physicalPort,
      name: port.name,
      description: port.description,
      ipAddress: port.ipAddress,
      enabled: port.enabled,
      interfaceIndex: index,
      vlanId: port.name.contains('.')
          ? int.tryParse(port.name.split('.').last)
          : (isSwitchport ? (port).vlan : null),
      switchportMode: isSwitchport ? (port).mode : null,
      accessVlan: isSwitchport ? (port).vlan : null,
      nativeVlan: isSwitchport ? (port).nativeVlan : null,
      isSwitchport: isSwitchport,
      sourcePort: port,
    );
  }

  /// Create from a VLAN config (SVI)
  factory InterfaceDescriptor.fromVlan(VlanConfig vlan, int index) {
    return InterfaceDescriptor(
      type: InterfaceType.vlanSvi,
      name: 'VLAN ${vlan.vlanId}',
      description: vlan.name.isNotEmpty ? vlan.name : null,
      ipAddress: vlan.ipAddress,
      enabled: vlan.enabled,
      interfaceIndex: index,
      vlanId: vlan.vlanId,
      isSwitchport: false,
      sourceVlan: vlan,
    );
  }

  /// Create from a tunnel config
  factory InterfaceDescriptor.fromTunnel(TunnelConfig tunnel) {
    IPv4? ip;
    if (tunnel.tunnelIpAddress != null) {
      ip = IPv4.tryParse(tunnel.tunnelIpAddress!);
    }
    return InterfaceDescriptor(
      type: InterfaceType.tunnel,
      name: 'Tunnel${tunnel.tunnelNumber}',
      description: tunnel.description.isNotEmpty ? tunnel.description : null,
      ipAddress: ip,
      enabled: true,
      interfaceIndex: tunnel.tunnelNumber,
      isSwitchport: false,
    );
  }

  /// Get all interfaces from a device
  static List<InterfaceDescriptor> fromDevice(
    NetDevice device, {
    bool includeTunnels = false,
  }) {
    final descriptors = <InterfaceDescriptor>[];

    // Add physical ports
    final ports = device.interfaces;
    for (int i = 0; i < ports.length; i++) {
      descriptors.add(InterfaceDescriptor.fromPort(ports[i], i));
    }

    // Add VLANs (SVIs)
    final vlans = device.vlans;
    for (int i = 0; i < vlans.length; i++) {
      descriptors.add(InterfaceDescriptor.fromVlan(vlans[i], i));
    }

    // Add tunnel interfaces
    if (includeTunnels) {
      final tunnels = device.tunnels;
      for (final tunnel in tunnels) {
        descriptors.add(InterfaceDescriptor.fromTunnel(tunnel));
      }
    }

    return descriptors;
  }

  // ---- Display helpers ----

  /// Get shortened interface name (Fa0/1 instead of FastEthernet0/1)
  String get shortName {
    return name
        .replaceAll('FastEthernet', 'Fa')
        .replaceAll('GigabitEthernet', 'Gi')
        .replaceAll('TenGigabitEthernet', 'Te')
        .replaceAll('Ethernet', 'Eth');
  }

  /// Get display name with optional VLAN name
  String get displayName {
    if (type == InterfaceType.vlanSvi && description != null) {
      return 'VLAN $vlanId ($description)';
    }
    return name;
  }

  /// Get display name with IP address
  String get displayNameWithIp {
    if (ipAddress != null) {
      return '$displayName - ${ipAddress!.toCIDR()}';
    }
    return displayName;
  }

  /// Get network in CIDR notation (if IP is configured)
  String? get networkCidr {
    if (ipAddress == null) return null;
    final parts = ipAddress!.address.split('.');
    final maskParts = ipAddress!.subnetMask.split('.');
    final networkParts = <String>[];
    for (int i = 0; i < 4; i++) {
      networkParts.add(
        (int.parse(parts[i]) & int.parse(maskParts[i])).toString(),
      );
    }
    return '${networkParts.join('.')}/${IPv4.subnetMaskToPrefixLength(ipAddress!.subnetMask)}';
  }

  /// Get appropriate icon for this interface type
  IconData get icon {
    switch (type) {
      case InterfaceType.physicalPort:
        return isSwitchport
            ? FluentIcons.plug_solid
            : FluentIcons.plug_connected;
      case InterfaceType.subinterface:
        return FluentIcons.flow;
      case InterfaceType.vlanSvi:
        return FluentIcons.virtual_network;
      case InterfaceType.loopback:
        return FluentIcons.sync;
      case InterfaceType.portChannel:
        return FluentIcons.link;
      case InterfaceType.tunnel:
        return FluentIcons.communications;
    }
  }

  /// Get color based on interface state
  Color? get statusColor {
    if (!enabled) return Colors.grey;
    if (ipAddress != null) return Colors.green;
    return null;
  }

  /// Unique key for this interface (for use in ComboBox values, etc.)
  String get key {
    switch (type) {
      case InterfaceType.vlanSvi:
        return 'vlan:$vlanId';
      case InterfaceType.physicalPort:
      case InterfaceType.subinterface:
        return 'port:$interfaceIndex';
      case InterfaceType.loopback:
        return 'loopback:$interfaceIndex';
      case InterfaceType.portChannel:
        return 'portchannel:$portChannelNumber';
      case InterfaceType.tunnel:
        return 'tunnel:$interfaceIndex';
    }
  }

  /// Check if this interface has an IP address
  bool get hasIpAddress => ipAddress != null;

  /// Check if this is a Layer 3 interface (routed port, SVI, or tunnel)
  bool get isLayer3 =>
      !isSwitchport ||
      type == InterfaceType.vlanSvi ||
      type == InterfaceType.tunnel;

  @override
  String toString() => 'InterfaceDescriptor($displayName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InterfaceDescriptor && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// Filter options for interface selection
class InterfaceFilter {
  /// Only include interfaces with IP addresses
  final bool requireIpAddress;

  /// Only include enabled interfaces
  final bool requireEnabled;

  /// Only include Layer 3 interfaces (routed ports, SVIs, tunnels)
  final bool onlyLayer3;

  /// Only include Layer 2 interfaces (switchports)
  final bool onlyLayer2;

  /// Include specific interface types
  final Set<InterfaceType>? includeTypes;

  /// Exclude specific interface types
  final Set<InterfaceType>? excludeTypes;

  /// Exclude specific VLAN IDs
  final Set<int>? excludeVlanIds;

  /// Exclude specific interface indices
  final Set<int>? excludeInterfaceIndices;

  /// Exclude specific interface keys (e.g., 'port:0', 'vlan:10', 'tunnel:0')
  final Set<String>? excludeKeys;

  /// Custom filter function
  final bool Function(InterfaceDescriptor)? customFilter;

  const InterfaceFilter({
    this.requireIpAddress = false,
    this.requireEnabled = false,
    this.onlyLayer3 = false,
    this.onlyLayer2 = false,
    this.includeTypes,
    this.excludeTypes,
    this.excludeVlanIds,
    this.excludeInterfaceIndices,
    this.excludeKeys,
    this.customFilter,
  });

  /// Filter that only shows interfaces with IP addresses
  static const withIpAddress = InterfaceFilter(requireIpAddress: true);

  /// Filter that only shows enabled interfaces
  static const enabledOnly = InterfaceFilter(requireEnabled: true);

  /// Filter that only shows Layer 3 interfaces with IP addresses
  static const layer3WithIp = InterfaceFilter(
    requireIpAddress: true,
    onlyLayer3: true,
  );

  /// Filter that only shows physical ports
  static const physicalPortsOnly = InterfaceFilter(
    includeTypes: {InterfaceType.physicalPort},
  );

  /// Filter that only shows VLANs
  static const vlansOnly = InterfaceFilter(
    includeTypes: {InterfaceType.vlanSvi},
  );

  /// No filtering
  static const none = InterfaceFilter();

  /// Apply this filter to a list of interfaces
  List<InterfaceDescriptor> apply(List<InterfaceDescriptor> interfaces) {
    return interfaces.where(matches).toList();
  }

  /// Check if an interface matches this filter
  bool matches(InterfaceDescriptor iface) {
    if (requireIpAddress && iface.ipAddress == null) return false;
    if (requireEnabled && !iface.enabled) return false;
    if (onlyLayer3 && !iface.isLayer3) return false;
    if (onlyLayer2 && iface.isLayer3) return false;
    if (includeTypes != null && !includeTypes!.contains(iface.type)) {
      return false;
    }
    if (excludeTypes != null && excludeTypes!.contains(iface.type)) {
      return false;
    }
    if (excludeVlanIds != null &&
        iface.vlanId != null &&
        excludeVlanIds!.contains(iface.vlanId)) {
      return false;
    }
    if (excludeInterfaceIndices != null &&
        iface.interfaceIndex != null &&
        excludeInterfaceIndices!.contains(iface.interfaceIndex)) {
      return false;
    }
    if (excludeKeys != null && excludeKeys!.contains(iface.key)) {
      return false;
    }
    if (customFilter != null && !customFilter!(iface)) return false;
    return true;
  }

  /// Create a new filter with additional requirements
  InterfaceFilter copyWith({
    bool? requireIpAddress,
    bool? requireEnabled,
    bool? onlyLayer3,
    bool? onlyLayer2,
    Set<InterfaceType>? includeTypes,
    Set<InterfaceType>? excludeTypes,
    Set<int>? excludeVlanIds,
    Set<int>? excludeInterfaceIndices,
    Set<String>? excludeKeys,
    bool Function(InterfaceDescriptor)? customFilter,
  }) {
    return InterfaceFilter(
      requireIpAddress: requireIpAddress ?? this.requireIpAddress,
      requireEnabled: requireEnabled ?? this.requireEnabled,
      onlyLayer3: onlyLayer3 ?? this.onlyLayer3,
      onlyLayer2: onlyLayer2 ?? this.onlyLayer2,
      includeTypes: includeTypes ?? this.includeTypes,
      excludeTypes: excludeTypes ?? this.excludeTypes,
      excludeVlanIds: excludeVlanIds ?? this.excludeVlanIds,
      excludeInterfaceIndices:
          excludeInterfaceIndices ?? this.excludeInterfaceIndices,
      excludeKeys: excludeKeys ?? this.excludeKeys,
      customFilter: customFilter ?? this.customFilter,
    );
  }
}
