class IPv4 {
  final String address;
  final String subnetMask;

  IPv4({required this.address, required this.subnetMask});

  static String _cidrToSubnetMask(int cidr) {
    final mask = (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF;
    return '${(mask >> 24) & 0xFF}.${(mask >> 16) & 0xFF}.${(mask >> 8) & 0xFF}.${mask & 0xFF}';
  }

  IPv4.parse(String cidr)
    : address = cidr.split('/')[0],
      subnetMask = _cidrToSubnetMask(int.parse(cidr.split('/')[1]));

  /// Create an IPv4 from just an address, defaulting to /32 (host)
  factory IPv4.fromAddress(String address, {int prefixLength = 32}) {
    return IPv4(address: address, subnetMask: _cidrToSubnetMask(prefixLength));
  }

  /// Check if this is a valid IPv4 address format
  static bool isValidAddress(String address) {
    final parts = address.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    return true;
  }

  static String prefixLengthToSubnetMask(int cidr) {
    if (cidr < 0 || cidr > 32) return '';
    final mask = (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF;
    return '${(mask >> 24) & 0xFF}.${(mask >> 16) & 0xFF}.${(mask >> 8) & 0xFF}.${mask & 0xFF}';
  }

  static int subnetMaskToPrefixLength(String mask) {
    final parts = mask.split('.');
    if (parts.length != 4) throw const FormatException('Invalid mask');

    int val = 0;
    for (var part in parts) {
      val = (val << 8) | int.parse(part);
    }

    int count = 0;
    for (int i = 0; i < 32; i++) {
      if ((val & (1 << (31 - i))) != 0) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  String toCIDR() {
    final prefix = subnetMaskToPrefixLength(subnetMask);
    return '$address/$prefix';
  }

  /// Try to parse a CIDR string, returns null if invalid
  static IPv4? tryParse(String cidr) {
    try {
      if (!cidr.contains('/')) return null;
      final parts = cidr.split('/');
      if (parts.length != 2) return null;
      final prefix = int.tryParse(parts[1]);
      if (prefix == null || prefix < 0 || prefix > 32) return null;
      // Validate IP address format
      final ipParts = parts[0].split('.');
      if (ipParts.length != 4) return null;
      for (final part in ipParts) {
        final num = int.tryParse(part);
        if (num == null || num < 0 || num > 255) return null;
      }
      return IPv4.parse(cidr);
    } catch (_) {
      return null;
    }
  }

  IPv4 copyWith({String? address, String? subnetMask}) {
    return IPv4(
      address: address ?? this.address,
      subnetMask: subnetMask ?? this.subnetMask,
    );
  }

  IPv4 merge(IPv4? other) {
    if (other == null) return this;
    return IPv4(
      address: other.address.isNotEmpty ? other.address : address,
      subnetMask: other.subnetMask.isNotEmpty ? other.subnetMask : subnetMask,
    );
  }

  /// Get the network address by applying the subnet mask
  String get networkAddress {
    final addrParts = address.split('.');
    final maskParts = subnetMask.split('.');
    if (addrParts.length != 4 || maskParts.length != 4) return address;

    final networkParts = <String>[];
    for (int i = 0; i < 4; i++) {
      final addrOctet = int.tryParse(addrParts[i]) ?? 0;
      final maskOctet = int.tryParse(maskParts[i]) ?? 255;
      networkParts.add((addrOctet & maskOctet).toString());
    }
    return networkParts.join('.');
  }

  /// Get the network in CIDR notation (network address with prefix)
  String get networkCIDR {
    final prefix = subnetMaskToPrefixLength(subnetMask);
    return '$networkAddress/$prefix';
  }

  /// Create an IPv4 representing the network that contains this address
  IPv4 get network => IPv4(address: networkAddress, subnetMask: subnetMask);

  /// Get prefix length for this subnet
  int get prefixLength => subnetMaskToPrefixLength(subnetMask);

  /// Convert a host IP address to a network CIDR with given prefix
  /// Example: "192.168.1.50" with prefix 24 -> "192.168.1.0/24"
  static String addressToNetworkCIDR(String address, {int prefixLength = 24}) {
    if (!isValidAddress(address)) return '$address/$prefixLength';
    final ip = IPv4.fromAddress(address, prefixLength: prefixLength);
    return ip.networkCIDR;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IPv4 &&
          runtimeType == other.runtimeType &&
          address == other.address &&
          subnetMask == other.subnetMask;

  @override
  int get hashCode => Object.hash(address, subnetMask);

  @override
  String toString() => toCIDR();
}
