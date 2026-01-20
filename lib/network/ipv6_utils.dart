import 'package:ktracer_center/network/ipv6.dart';

/// Extension methods for IPv6 providing network math utilities
extension IPv6Utils on IPv6 {
  /// Get prefix length
  int get prefixLen => prefixLength;

  /// Get the number of total addresses in the network
  BigInt get totalAddresses {
    return BigInt.one << hostBits;
  }

  /// Get the number of usable host addresses (excluding network and last)
  BigInt get usableAddresses {
    if (hostBits == 0) return BigInt.zero;
    return totalAddresses - BigInt.one;
  }

  /// Check if another IP is in the same network
  bool isInSameNetwork(IPv6 other) {
    return IPv6Math.getNetworkAddress(fullAddress, prefixLength) ==
        IPv6Math.getNetworkAddress(other.fullAddress, other.prefixLength);
  }

  /// Check if a given address string is within this network
  bool containsAddress(String addressStr) {
    final expanded = IPv6.expandIPv6(addressStr);
    return IPv6Math.getNetworkAddress(expanded, prefixLength) ==
        IPv6Math.getNetworkAddress(fullAddress, prefixLength);
  }

  /// Create a new IPv6 with a different address but same prefix length
  IPv6 withAddress(String newAddress) {
    return IPv6(address: newAddress, prefixLength: prefixLength);
  }

  /// Create a new IPv6 with a different prefix length
  IPv6 withPrefixLength(int prefix) {
    return IPv6(address: address, prefixLength: prefix);
  }
}

/// Helper class for IPv6 network math operations
class IPv6Math {
  /// Check if address is valid IPv6 format
  static bool isValidAddress(String address) {
    return IPv6.isValidAddress(address);
  }

  /// Get the network address for a given IPv6 and prefix
  static String getNetworkAddress(String address, int prefixLength) {
    final expanded = IPv6.expandIPv6(address);
    final parts = expanded
        .split(':')
        .map((p) => int.parse(p, radix: 16))
        .toList();

    // Calculate which parts are affected by the prefix
    final completeGroups = (prefixLength / 16).floor();
    final remainingBits = prefixLength % 16;

    final networkParts = parts.sublist(0, completeGroups);

    if (remainingBits > 0 && completeGroups < 8) {
      final block = parts[completeGroups];
      final mask = (0xFFFF << (16 - remainingBits)) & 0xFFFF;
      final maskedBlock = block & mask;
      networkParts.add(maskedBlock);
    }

    while (networkParts.length < 8) {
      networkParts.add(0);
    }

    return networkParts.map((p) => p.toRadixString(16)).join(':');
  }

  /// Convert IPv6 address to canonical form (lowercase with :: compression if beneficial)
  static String toCanonical(String address) {
    if (!isValidAddress(address)) return '';

    final expanded = IPv6.expandIPv6(address);
    final parts = expanded
        .split(':')
        .map((p) => int.parse(p, radix: 16).toRadixString(16))
        .toList();

    // Find longest sequence of zeros to compress
    int longestStart = -1;
    int longestLen = 0;
    int currentStart = -1;
    int currentLen = 0;

    for (int i = 0; i < parts.length; i++) {
      if (parts[i] == '0') {
        if (currentStart == -1) {
          currentStart = i;
          currentLen = 1;
        } else {
          currentLen++;
        }
      } else {
        if (currentLen > longestLen) {
          longestStart = currentStart;
          longestLen = currentLen;
        }
        currentStart = -1;
        currentLen = 0;
      }
    }

    if (currentLen > longestLen) {
      longestStart = currentStart;
      longestLen = currentLen;
    }

    // Compress the longest sequence of zeros
    if (longestLen > 1) {
      final before = parts.sublist(0, longestStart);
      final after = parts.sublist(longestStart + longestLen);

      if (longestStart == 0) {
        return '::${after.join(':')}';
      } else if (longestStart + longestLen == 8) {
        return '${before.join(':')}::';
      } else {
        return '${before.join(':')}::${after.join(':')}';
      }
    }

    return parts.join(':');
  }

  /// Get broadcast address (all host bits set to 1) - not typically used in IPv6
  /// but included for API compatibility
  static String getBroadcastAddress(String address, int prefixLength) {
    final expanded = IPv6.expandIPv6(address);
    final parts = expanded
        .split(':')
        .map((p) => int.parse(p, radix: 16))
        .toList();

    final completeGroups = (prefixLength / 16).floor();
    final remainingBits = prefixLength % 16;

    if (remainingBits > 0 && completeGroups < 8) {
      final mask = (0xFFFF >> (16 - remainingBits)) & 0xFFFF;
      parts[completeGroups] |= mask;
    }

    for (int i = completeGroups + (remainingBits > 0 ? 1 : 0); i < 8; i++) {
      parts[i] = 0xFFFF;
    }

    return parts.map((p) => p.toRadixString(16)).join(':');
  }

  /// Check if address is a link-local address (fe80::/10)
  static bool isLinkLocal(String address) {
    if (!isValidAddress(address)) return false;
    final expanded = IPv6.expandIPv6(address);
    return expanded.toLowerCase().startsWith('fe80:');
  }

  /// Check if address is a loopback address (::1)
  static bool isLoopback(String address) {
    if (!isValidAddress(address)) return false;
    return address == '::1' ||
        IPv6.expandIPv6(address) == '0000:0000:0000:0000:0000:0000:0000:0001';
  }

  /// Check if address is multicast (ff00::/8)
  static bool isMulticast(String address) {
    if (!isValidAddress(address)) return false;
    final expanded = IPv6.expandIPv6(address);
    return expanded.toLowerCase().startsWith('ff');
  }

  /// Check if address is unspecified (::)
  static bool isUnspecified(String address) {
    if (!isValidAddress(address)) return false;
    return address == '::' ||
        IPv6.expandIPv6(address) == '0000:0000:0000:0000:0000:0000:0000:0000';
  }

  /// Check if address is global unicast (2000::/3)
  static bool isGlobalUnicast(String address) {
    if (!isValidAddress(address)) return false;
    if (isLinkLocal(address) ||
        isLoopback(address) ||
        isMulticast(address) ||
        isUnspecified(address)) {
      return false;
    }
    // Global unicast addresses typically start with 2 or 3 (2000::/3)
    final firstChar = IPv6.expandIPv6(address).split(':')[0].toLowerCase();
    if (firstChar.isEmpty) return false;
    final firstByte = int.tryParse(firstChar.substring(0, 1), radix: 16) ?? 0;
    return firstByte >= 2 && firstByte <= 3;
  }
}
