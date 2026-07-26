class IPv6 {
  final String address;
  final int prefixLength;

  IPv6({required this.address, required this.prefixLength}) {
    if (prefixLength < 0 || prefixLength > 128) {
      throw ArgumentError('Prefix length must be between 0 and 128');
    }
  }

  /// Parse IPv6 from CIDR notation (e.g., "2001:db8::1/64")
  IPv6.parse(String cidr)
    : address = cidr.split('/')[0],
      prefixLength = int.parse(cidr.split('/')[1]) {
    if (prefixLength < 0 || prefixLength > 128) {
      throw ArgumentError('Prefix length must be between 0 and 128');
    }
  }

  /// Create an IPv6 from just an address, defaulting to /128 (host)
  factory IPv6.fromAddress(String address, {int prefixLength = 128}) {
    return IPv6(address: address, prefixLength: prefixLength);
  }

  /// Check if this is a valid IPv6 address format
  static bool isValidAddress(String address) {
    // IPv6 can have :: which represents consecutive zeros
    if (address.contains('::')) {
      // Should only appear once
      if (address.split('::').length > 2) return false;
    }

    // Split by colon and validate each part
    final parts = address.split(':');
    if (address.contains('::')) {
      // With compression, we should have less than 8 parts
      if (parts.length > 8) return false;
    } else {
      // Without compression, should have exactly 8 parts
      if (parts.length != 8) return false;
    }

    for (final part in parts) {
      if (part.isEmpty && !address.contains('::')) continue;
      if (part.isNotEmpty && !_isValidHexBlock(part)) return false;
    }

    return true;
  }

  /// Check if a hex block (0-ffff) is valid
  static bool _isValidHexBlock(String block) {
    if (block.length > 4) return false;
    try {
      int.parse(block, radix: 16);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Try to parse a CIDR string, returns null if invalid
  static IPv6? tryParse(String cidr) {
    try {
      if (!cidr.contains('/')) return null;
      final parts = cidr.split('/');
      if (parts.length != 2) return null;
      final prefix = int.tryParse(parts[1]);
      if (prefix == null || prefix < 0 || prefix > 128) return null;
      if (!isValidAddress(parts[0])) return null;
      return IPv6.parse(cidr);
    } catch (_) {
      return null;
    }
  }

  /// Convert to CIDR notation
  String toCIDR() => '$address/$prefixLength';

  /// Convert to full address notation (expand :: notation)
  String get fullAddress => expandIPv6(address);

  /// Expand compressed IPv6 to full format
  static String expandIPv6(String address) {
    if (!address.contains('::')) {
      return address;
    }

    final parts = address.split('::');
    if (parts.length != 2) return address;

    final left = parts[0].isEmpty ? [] : parts[0].split(':');
    final right = parts[1].isEmpty ? [] : parts[1].split(':');
    final zeros = List.generate(8 - left.length - right.length, (_) => '0');

    final expanded = [...left, ...zeros, ...right];
    return expanded.map((p) => p.padLeft(4, '0')).join(':');
  }

  /// Get network address in CIDR notation
  String get networkCIDR {
    final expanded = fullAddress;
    final parts = expanded.split(':');

    // Calculate which parts are affected by the prefix
    final completeGroups = (prefixLength / 16).floor();
    final remainingBits = prefixLength % 16;

    final networkParts = parts.sublist(0, completeGroups);

    if (remainingBits > 0 && completeGroups < 8) {
      final block = int.parse(parts[completeGroups], radix: 16);
      final mask = (0xFFFF << (16 - remainingBits)) & 0xFFFF;
      final maskedBlock = block & mask;
      networkParts.add(maskedBlock.toRadixString(16));
    }

    while (networkParts.length < 8) {
      networkParts.add('0');
    }

    return '${networkParts.join(':')}/$prefixLength';
  }

  /// Get the number of host bits
  int get hostBits => 128 - prefixLength;

  /// Copy with new address or prefix
  IPv6 copyWith({String? address, int? prefixLength}) {
    return IPv6(
      address: address ?? this.address,
      prefixLength: prefixLength ?? this.prefixLength,
    );
  }

  /// Merge with another IPv6 (other takes precedence if not empty)
  IPv6 merge(IPv6? other) {
    if (other == null) return this;
    return IPv6(
      address: other.address.isNotEmpty ? other.address : address,
      prefixLength: other.prefixLength != 128
          ? other.prefixLength
          : prefixLength,
    );
  }

  @override
  String toString() => toCIDR();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IPv6 &&
          runtimeType == other.runtimeType &&
          fullAddress == other.fullAddress &&
          prefixLength == other.prefixLength;

  @override
  int get hashCode => Object.hash(fullAddress, prefixLength);
}
