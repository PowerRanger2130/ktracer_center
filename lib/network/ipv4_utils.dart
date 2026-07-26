import 'package:ktracer_center/network/ipv4.dart';

/// Extension methods for IPv4 providing network math utilities
extension IPv4Utils on IPv4 {
  /// Convert IP address to 32-bit integer
  int get addressInt {
    final parts = address.split('.').map(int.parse).toList();
    return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
  }

  /// Convert subnet mask to 32-bit integer
  int get maskInt {
    final parts = subnetMask.split('.').map(int.parse).toList();
    return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
  }

  /// Get prefix length (CIDR notation)
  int get prefixLength => IPv4.subnetMaskToPrefixLength(subnetMask);

  /// Get network address as integer
  int get networkAddressInt => addressInt & maskInt;

  /// Get network address as string
  String get networkAddress => IPv4Math.intToAddress(networkAddressInt);

  /// Get broadcast address as integer
  int get broadcastAddressInt => networkAddressInt | (~maskInt & 0xFFFFFFFF);

  /// Get broadcast address as string
  String get broadcastAddress => IPv4Math.intToAddress(broadcastAddressInt);

  /// Get the number of host bits
  int get hostBits => 32 - prefixLength;

  /// Get the number of total addresses in the network
  int get totalAddresses => 1 << hostBits;

  /// Get the number of usable host addresses (excluding network and broadcast)
  int get usableAddresses => hostBits <= 1 ? 0 : totalAddresses - 2;

  /// Get the first usable host address
  String get firstUsableAddress =>
      hostBits <= 1 ? address : IPv4Math.intToAddress(networkAddressInt + 1);

  /// Get the last usable host address
  String get lastUsableAddress =>
      hostBits <= 1 ? address : IPv4Math.intToAddress(broadcastAddressInt - 1);

  /// Check if this address is the network address
  bool get isNetworkAddress => addressInt == networkAddressInt;

  /// Check if this address is the broadcast address
  bool get isBroadcastAddress => addressInt == broadcastAddressInt;

  /// Check if this is a usable host address (not network or broadcast)
  bool get isUsableHostAddress =>
      !isNetworkAddress && !isBroadcastAddress && hostBits > 1;

  /// Check if another IP is in the same network
  bool isInSameNetwork(IPv4 other) {
    return (addressInt & maskInt) == (other.addressInt & maskInt);
  }

  /// Check if a given address string is within this network
  bool containsAddress(String addressStr) {
    final otherInt = IPv4Math.addressToInt(addressStr);
    if (otherInt == null) return false;
    return (otherInt & maskInt) == networkAddressInt;
  }

  /// Get the offset of this address from the network address
  int get offsetFromNetwork => addressInt - networkAddressInt;

  /// Get a new IPv4 with an address at a specific offset from network
  IPv4? atOffset(int offset) {
    if (offset < 0 || offset >= totalAddresses) return null;
    return IPv4(
      address: IPv4Math.intToAddress(networkAddressInt + offset),
      subnetMask: subnetMask,
    );
  }

  /// Create a new IPv4 with a different address but same mask
  IPv4 withAddress(String newAddress) {
    return IPv4(address: newAddress, subnetMask: subnetMask);
  }

  /// Create a new IPv4 with a different mask
  IPv4 withMask(String newMask) {
    return IPv4(address: address, subnetMask: newMask);
  }

  /// Create a new IPv4 with a different prefix length
  IPv4 withPrefixLength(int prefix) {
    return IPv4(
      address: address,
      subnetMask: IPv4.prefixLengthToSubnetMask(prefix),
    );
  }
}

/// Static utility functions for IPv4 math
class IPv4Math {
  IPv4Math._();

  /// Convert a dotted-decimal address to a 32-bit integer
  static int? addressToInt(String address) {
    final parts = address.split('.');
    if (parts.length != 4) return null;
    try {
      int result = 0;
      for (final part in parts) {
        final num = int.parse(part);
        if (num < 0 || num > 255) return null;
        result = (result << 8) | num;
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Convert a 32-bit integer to a dotted-decimal address
  static String intToAddress(int value) {
    return '${(value >> 24) & 0xFF}.${(value >> 16) & 0xFF}.${(value >> 8) & 0xFF}.${value & 0xFF}';
  }

  /// Parse a CIDR string and return (address, prefix) or null if invalid
  static (String, int)? parseCIDR(String cidr) {
    if (!cidr.contains('/')) return null;
    final parts = cidr.split('/');
    if (parts.length != 2) return null;
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 0 || prefix > 32) return null;
    if (addressToInt(parts[0]) == null) return null;
    return (parts[0], prefix);
  }

  /// Calculate network address from address and mask
  static String calculateNetworkAddress(String address, String mask) {
    final addrInt = addressToInt(address);
    final maskInt = addressToInt(mask);
    if (addrInt == null || maskInt == null) return address;
    return intToAddress(addrInt & maskInt);
  }

  /// Calculate broadcast address from network address and mask
  static String calculateBroadcastAddress(String networkAddress, String mask) {
    final netInt = addressToInt(networkAddress);
    final maskInt = addressToInt(mask);
    if (netInt == null || maskInt == null) return networkAddress;
    return intToAddress(netInt | (~maskInt & 0xFFFFFFFF));
  }

  /// Check if an address is within a network
  static bool isAddressInNetwork(
    String address,
    String networkAddress,
    String mask,
  ) {
    final addrInt = addressToInt(address);
    final netInt = addressToInt(networkAddress);
    final maskInt = addressToInt(mask);
    if (addrInt == null || netInt == null || maskInt == null) return false;
    return (addrInt & maskInt) == netInt;
  }

  /// Validate an IP address string
  static bool isValidAddress(String address) {
    return addressToInt(address) != null;
  }

  /// Validate a subnet mask string
  static bool isValidMask(String mask) {
    final maskInt = addressToInt(mask);
    if (maskInt == null) return false;
    // Check that it's a valid mask (contiguous 1s followed by 0s)
    final inverted = ~maskInt & 0xFFFFFFFF;
    return (inverted & (inverted + 1)) == 0;
  }

  /// Get prefix length from subnet mask
  static int? maskToPrefixLength(String mask) {
    final maskInt = addressToInt(mask);
    if (maskInt == null) return null;
    int count = 0;
    int m = maskInt;
    while ((m & 0x80000000) != 0) {
      count++;
      m <<= 1;
    }
    // Verify remaining bits are 0
    if ((m & 0xFFFFFFFF) != 0) return null;
    return count;
  }

  /// Convert prefix length to subnet mask
  static String prefixToMask(int prefix) {
    if (prefix < 0 || prefix > 32) return '0.0.0.0';
    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    return intToAddress(mask);
  }
}

/// Represents a network with address and prefix for calculations
class IPv4Network {
  final int networkAddressInt;
  final int prefixLength;

  IPv4Network({required this.networkAddressInt, required this.prefixLength});

  factory IPv4Network.fromIPv4(IPv4 ip) {
    final ext = ip;
    return IPv4Network(
      networkAddressInt: ext.networkAddressInt,
      prefixLength: ext.prefixLength,
    );
  }

  factory IPv4Network.fromCIDR(String cidr) {
    final parsed = IPv4Math.parseCIDR(cidr);
    if (parsed == null) {
      throw FormatException('Invalid CIDR: $cidr');
    }
    final (address, prefix) = parsed;
    final addrInt = IPv4Math.addressToInt(address)!;
    final maskInt = prefix == 0
        ? 0
        : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    return IPv4Network(
      networkAddressInt: addrInt & maskInt,
      prefixLength: prefix,
    );
  }

  static IPv4Network? tryFromCIDR(String cidr) {
    try {
      return IPv4Network.fromCIDR(cidr);
    } catch (_) {
      return null;
    }
  }

  int get maskInt =>
      prefixLength == 0 ? 0 : (0xFFFFFFFF << (32 - prefixLength)) & 0xFFFFFFFF;
  int get broadcastAddressInt => networkAddressInt | (~maskInt & 0xFFFFFFFF);
  int get totalAddresses => 1 << (32 - prefixLength);
  int get usableAddresses => prefixLength >= 31 ? 0 : totalAddresses - 2;

  String get networkAddress => IPv4Math.intToAddress(networkAddressInt);
  String get broadcastAddress => IPv4Math.intToAddress(broadcastAddressInt);
  String get subnetMask => IPv4Math.intToAddress(maskInt);
  String get cidr => '$networkAddress/$prefixLength';

  /// Check if an address integer is within this network
  bool containsInt(int addressInt) {
    return (addressInt & maskInt) == networkAddressInt;
  }

  /// Check if an address string is within this network
  bool containsAddress(String address) {
    final addrInt = IPv4Math.addressToInt(address);
    if (addrInt == null) return false;
    return containsInt(addrInt);
  }

  /// Check if an address is the network address
  bool isNetworkAddress(int addressInt) => addressInt == networkAddressInt;

  /// Check if an address is the broadcast address
  bool isBroadcastAddress(int addressInt) => addressInt == broadcastAddressInt;

  /// Check if an address is usable (not network or broadcast)
  bool isUsableAddress(int addressInt) {
    if (!containsInt(addressInt)) return false;
    if (prefixLength >= 31) return true; // /31 and /32 are special
    return !isNetworkAddress(addressInt) && !isBroadcastAddress(addressInt);
  }

  /// Get address at offset from network address
  String? addressAtOffset(int offset) {
    if (offset < 0 || offset >= totalAddresses) return null;
    return IPv4Math.intToAddress(networkAddressInt + offset);
  }

  /// Get offset of an address from network address
  int? offsetOf(String address) {
    final addrInt = IPv4Math.addressToInt(address);
    if (addrInt == null || !containsInt(addrInt)) return null;
    return addrInt - networkAddressInt;
  }

  @override
  String toString() => cidr;
}

/// Result of IP address validation within a network context
class IpValidationResult {
  final bool isValid;
  final String? error;
  final String? normalizedAddress;

  const IpValidationResult._({
    required this.isValid,
    this.error,
    this.normalizedAddress,
  });

  factory IpValidationResult.valid(String address) =>
      IpValidationResult._(isValid: true, normalizedAddress: address);

  factory IpValidationResult.invalid(String error) =>
      IpValidationResult._(isValid: false, error: error);
}

/// Validator for IP addresses within a network context
class NetworkConstrainedIpValidator {
  final IPv4Network network;
  final bool allowNetworkAddress;
  final bool allowBroadcastAddress;
  final Set<String> excludedAddresses;

  NetworkConstrainedIpValidator({
    required this.network,
    this.allowNetworkAddress = false,
    this.allowBroadcastAddress = false,
    this.excludedAddresses = const {},
  });

  /// Validate an IP address within this network's constraints
  IpValidationResult validate(String address) {
    // Check basic format
    final addrInt = IPv4Math.addressToInt(address);
    if (addrInt == null) {
      return IpValidationResult.invalid('Invalid IP address format');
    }

    // Check if in network
    if (!network.containsInt(addrInt)) {
      return IpValidationResult.invalid(
        'Address is outside network ${network.cidr}',
      );
    }

    // Check network address
    if (!allowNetworkAddress && network.isNetworkAddress(addrInt)) {
      return IpValidationResult.invalid(
        'Cannot use network address (${network.networkAddress})',
      );
    }

    // Check broadcast address
    if (!allowBroadcastAddress && network.isBroadcastAddress(addrInt)) {
      return IpValidationResult.invalid(
        'Cannot use broadcast address (${network.broadcastAddress})',
      );
    }

    // Check excluded addresses
    if (excludedAddresses.contains(address)) {
      return IpValidationResult.invalid('This address is reserved');
    }

    return IpValidationResult.valid(address);
  }

  /// Validate that an address is valid for DHCP range start
  IpValidationResult validateRangeStart(String address, String? endAddress) {
    final result = validate(address);
    if (!result.isValid) return result;

    if (endAddress != null && endAddress.isNotEmpty) {
      final startInt = IPv4Math.addressToInt(address)!;
      final endInt = IPv4Math.addressToInt(endAddress);
      if (endInt != null && startInt > endInt) {
        return IpValidationResult.invalid(
          'Start address must be less than or equal to end address',
        );
      }
    }

    return result;
  }

  /// Validate that an address is valid for DHCP range end
  IpValidationResult validateRangeEnd(String address, String? startAddress) {
    final result = validate(address);
    if (!result.isValid) return result;

    if (startAddress != null && startAddress.isNotEmpty) {
      final endInt = IPv4Math.addressToInt(address)!;
      final startInt = IPv4Math.addressToInt(startAddress);
      if (startInt != null && endInt < startInt) {
        return IpValidationResult.invalid(
          'End address must be greater than or equal to start address',
        );
      }
    }

    return result;
  }
}

/// Helper to check for IP address conflicts on a device
class IpConflictChecker {
  final List<_InterfaceIp> _interfaceIps = [];

  IpConflictChecker();

  /// Build a conflict checker from a device
  factory IpConflictChecker.fromDevice(
    dynamic device, {
    int? excludePortIndex,
    int? excludeVlanId,
  }) {
    final checker = IpConflictChecker();

    // Add port IPs
    if (device.interfaces != null) {
      for (int i = 0; i < device.interfaces.length; i++) {
        if (i == excludePortIndex) continue;
        final port = device.interfaces[i];
        if (port.ipAddress != null) {
          checker._interfaceIps.add(
            _InterfaceIp(
              address: port.ipAddress!.address,
              subnetMask: port.ipAddress!.subnetMask,
              interfaceName: port.name,
              isVlan: false,
            ),
          );
        }
      }
    }

    // Add VLAN IPs
    if (device.vlans != null) {
      for (final vlan in device.vlans) {
        if (vlan.vlanId == excludeVlanId) continue;
        if (vlan.ipAddress != null) {
          checker._interfaceIps.add(
            _InterfaceIp(
              address: vlan.ipAddress!.address,
              subnetMask: vlan.ipAddress!.subnetMask,
              interfaceName: 'VLAN ${vlan.vlanId}',
              isVlan: true,
            ),
          );
        }
      }
    }

    return checker;
  }

  /// Check if an IP address conflicts with any existing interface
  /// Returns the conflicting interface name if there's a conflict, null otherwise
  String? checkConflict(String address) {
    final addrInt = IPv4Math.addressToInt(address);
    if (addrInt == null) return null;

    for (final iface in _interfaceIps) {
      final ifaceInt = IPv4Math.addressToInt(iface.address);
      if (ifaceInt == addrInt) {
        return iface.interfaceName;
      }
    }

    return null;
  }

  /// Check if an IP/subnet overlaps with any existing interface's network
  /// This catches cases like assigning 192.168.40.3/24 and 192.168.40.5/24
  /// to different interfaces (same subnet = conflict)
  /// Returns (conflictType, interfaceName) or null if no conflict
  IpConflictResult? checkConflictWithSubnet(String address, String subnetMask) {
    final addrInt = IPv4Math.addressToInt(address);
    final maskInt = IPv4Math.addressToInt(subnetMask);
    if (addrInt == null || maskInt == null) return null;

    final networkInt = addrInt & maskInt;

    for (final iface in _interfaceIps) {
      final ifaceAddrInt = IPv4Math.addressToInt(iface.address);
      final ifaceMaskInt = IPv4Math.addressToInt(iface.subnetMask);
      if (ifaceAddrInt == null || ifaceMaskInt == null) continue;

      // Check exact IP match first
      if (ifaceAddrInt == addrInt) {
        return IpConflictResult(
          type: IpConflictType.exactMatch,
          interfaceName: iface.interfaceName,
          message: 'IP address already used by ${iface.interfaceName}',
        );
      }

      // Check if same network (overlapping subnet)
      final ifaceNetworkInt = ifaceAddrInt & ifaceMaskInt;

      // If both are in the same subnet (using either mask)
      // Check if new address is in existing interface's network
      if ((addrInt & ifaceMaskInt) == ifaceNetworkInt) {
        return IpConflictResult(
          type: IpConflictType.sameSubnet,
          interfaceName: iface.interfaceName,
          message:
              'Subnet ${IPv4Math.intToAddress(networkInt)}/${IPv4Math.maskToPrefixLength(subnetMask)} overlaps with ${iface.interfaceName} (${iface.address}/${IPv4Math.maskToPrefixLength(iface.subnetMask)})',
        );
      }

      // Check if existing interface's address is in new network
      if ((ifaceAddrInt & maskInt) == networkInt) {
        return IpConflictResult(
          type: IpConflictType.sameSubnet,
          interfaceName: iface.interfaceName,
          message:
              'Subnet ${IPv4Math.intToAddress(networkInt)}/${IPv4Math.maskToPrefixLength(subnetMask)} overlaps with ${iface.interfaceName} (${iface.address}/${IPv4Math.maskToPrefixLength(iface.subnetMask)})',
        );
      }
    }

    return null;
  }

  /// Get all IPs that are in use
  Set<String> get usedAddresses => _interfaceIps.map((i) => i.address).toSet();
}

/// Result of an IP conflict check
class IpConflictResult {
  final IpConflictType type;
  final String interfaceName;
  final String message;

  IpConflictResult({
    required this.type,
    required this.interfaceName,
    required this.message,
  });
}

/// Type of IP conflict
enum IpConflictType {
  /// Exact same IP address
  exactMatch,

  /// Same subnet/network assigned to different interfaces
  sameSubnet,
}

class _InterfaceIp {
  final String address;
  final String subnetMask;
  final String interfaceName;
  final bool isVlan;

  _InterfaceIp({
    required this.address,
    required this.subnetMask,
    required this.interfaceName,
    required this.isVlan,
  });
}
