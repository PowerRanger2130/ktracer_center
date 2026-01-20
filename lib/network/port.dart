import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/ipv6.dart';

class Port {
  int? id;
  int? deviceId;
  final String name;
  final String? description;
  final bool enabled;
  final IPv4? ipAddress;
  final IPv6? ipv6Address;

  Port({
    this.id,
    this.deviceId,
    required this.name,
    this.description,
    this.enabled = true,
    this.ipAddress,
    this.ipv6Address,
  });

  factory Port.fromJson(Map<String, dynamic> json) {
    IPv4? ip;
    // Support both CIDR format and legacy separate fields
    if (json['ip_cidr'] != null && (json['ip_cidr'] as String).contains('/')) {
      ip = IPv4.tryParse(json['ip_cidr']);
    } else if (json['ip_address'] != null && json['subnet_mask'] != null) {
      ip = IPv4(address: json['ip_address'], subnetMask: json['subnet_mask']);
    }

    IPv6? ipv6;
    if (json['ipv6_cidr'] != null &&
        (json['ipv6_cidr'] as String).contains('/')) {
      ipv6 = IPv6.tryParse(json['ipv6_cidr']);
    }

    return Port(
      id: json['id'],
      deviceId: json['device_id'],
      name: json['name'],
      description: json['description'],
      enabled: json['enabled'] ?? true,
      ipAddress: ip,
      ipv6Address: ipv6,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'name': name,
      'description': description,
      'enabled': enabled,
      'is_switchport': false,
      if (ipAddress != null) 'ip_cidr': ipAddress!.toCIDR(),
      if (ipv6Address != null) 'ipv6_cidr': ipv6Address!.toCIDR(),
    };
  }

  Port copyWith({
    int? id,
    int? deviceId,
    String? name,
    String? description,
    bool? enabled,
    IPv4? ipAddress,
    IPv6? ipv6Address,
  }) {
    return Port(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      ipAddress: ipAddress ?? this.ipAddress,
      ipv6Address: ipv6Address ?? this.ipv6Address,
    );
  }

  Port merge(covariant Port? other) {
    if (other == null) return this;
    return Port(
      id: other.id ?? id,
      deviceId: other.deviceId ?? deviceId,
      name: other.name.isNotEmpty ? other.name : name,
      description: other.description ?? description,
      enabled: other.enabled,
      ipAddress: other.ipAddress ?? ipAddress,
      ipv6Address: other.ipv6Address ?? ipv6Address,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Port &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          deviceId == other.deviceId &&
          name == other.name &&
          description == other.description &&
          enabled == other.enabled &&
          ipAddress == other.ipAddress &&
          ipv6Address == other.ipv6Address;

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    name,
    description,
    enabled,
    ipAddress,
    ipv6Address,
  );
}
