import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/ipv6.dart';

enum IpAssignmentMode { staticAddress, dhcp }

enum Ipv6AssignmentMode { staticAddress, automatic }

enum DhcpRelayInformationMode { defaultBehavior, trusted }

extension IpAssignmentModeX on IpAssignmentMode {
  static IpAssignmentMode fromStorage(dynamic value) {
    switch (value?.toString()) {
      case 'dhcp':
        return IpAssignmentMode.dhcp;
      case 'static':
      case 'staticAddress':
      default:
        return IpAssignmentMode.staticAddress;
    }
  }

  String get storageValue {
    switch (this) {
      case IpAssignmentMode.staticAddress:
        return 'static';
      case IpAssignmentMode.dhcp:
        return 'dhcp';
    }
  }
}

extension Ipv6AssignmentModeX on Ipv6AssignmentMode {
  static Ipv6AssignmentMode fromStorage(dynamic value) {
    switch (value?.toString()) {
      case 'automatic':
      case 'auto':
      case 'autoconfig':
        return Ipv6AssignmentMode.automatic;
      case 'static':
      case 'staticAddress':
      default:
        return Ipv6AssignmentMode.staticAddress;
    }
  }

  String get storageValue {
    switch (this) {
      case Ipv6AssignmentMode.staticAddress:
        return 'static';
      case Ipv6AssignmentMode.automatic:
        return 'automatic';
    }
  }
}

extension DhcpRelayInformationModeX on DhcpRelayInformationMode {
  static DhcpRelayInformationMode fromStorage(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'trusted':
      case 'trust':
      case 'enabled':
      case 'true':
        return DhcpRelayInformationMode.trusted;
      case 'default':
      case 'none':
      case 'untrusted':
      case 'false':
      default:
        return DhcpRelayInformationMode.defaultBehavior;
    }
  }

  String get storageValue {
    switch (this) {
      case DhcpRelayInformationMode.defaultBehavior:
        return 'default';
      case DhcpRelayInformationMode.trusted:
        return 'trusted';
    }
  }
}

class Port {
  int? id;
  int? deviceId;
  final String name;
  final String? description;
  final bool enabled;
  final IpAssignmentMode ipAssignment;
  final Ipv6AssignmentMode ipv6Assignment;
  final IPv4? ipAddress;
  final IPv6? ipv6Address;
  final String? ipv4AccessGroupIn;
  final String? ipv4AccessGroupOut;
  final String? ipv4HelperAddress;
  final DhcpRelayInformationMode dhcpRelayInformation;

  Port({
    this.id,
    this.deviceId,
    required this.name,
    this.description,
    this.enabled = true,
    this.ipAssignment = IpAssignmentMode.staticAddress,
    this.ipv6Assignment = Ipv6AssignmentMode.staticAddress,
    this.ipAddress,
    this.ipv6Address,
    this.ipv4AccessGroupIn,
    this.ipv4AccessGroupOut,
    this.ipv4HelperAddress,
    this.dhcpRelayInformation = DhcpRelayInformationMode.defaultBehavior,
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

    final ipAssignment = IpAssignmentModeX.fromStorage(json['ip_assignment']);
    final ipv6Assignment = Ipv6AssignmentModeX.fromStorage(
      json['ipv6_assignment'],
    );
    final dhcpRelayInformation = DhcpRelayInformationModeX.fromStorage(
      json['dhcpRelayInformation'] ?? json['dhcp_relay_information'],
    );

    return Port(
      id: json['id'],
      deviceId: json['device_id'],
      name: json['name'],
      description: json['description'],
      enabled: json['enabled'] ?? true,
      ipAssignment: ipAssignment,
      ipv6Assignment: ipv6Assignment,
      ipAddress: ip,
      ipv6Address: ipv6,
      ipv4AccessGroupIn: _normalizeAclReference(
        json['ipv4AccessGroupIn'] ?? json['access_group_in'] ?? json['acl_in'],
      ),
      ipv4AccessGroupOut: _normalizeAclReference(
        json['ipv4AccessGroupOut'] ??
            json['access_group_out'] ??
            json['acl_out'],
      ),
      ipv4HelperAddress: _normalizeOptionalString(
        json['ipv4HelperAddress'] ??
            json['ipv4_helper_address'] ??
            json['helper_address'],
      ),
      dhcpRelayInformation: dhcpRelayInformation,
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
      if (ipAssignment != IpAssignmentMode.staticAddress)
        'ip_assignment': ipAssignment.storageValue,
      if (ipv6Assignment != Ipv6AssignmentMode.staticAddress)
        'ipv6_assignment': ipv6Assignment.storageValue,
      if (ipAddress != null) 'ip_cidr': ipAddress!.toCIDR(),
      if (ipv6Address != null) 'ipv6_cidr': ipv6Address!.toCIDR(),
      if (ipv4AccessGroupIn != null && ipv4AccessGroupIn!.isNotEmpty)
        'ipv4AccessGroupIn': ipv4AccessGroupIn,
      if (ipv4AccessGroupOut != null && ipv4AccessGroupOut!.isNotEmpty)
        'ipv4AccessGroupOut': ipv4AccessGroupOut,
      if (ipv4HelperAddress != null && ipv4HelperAddress!.isNotEmpty)
        'ipv4HelperAddress': ipv4HelperAddress,
      if (dhcpRelayInformation != DhcpRelayInformationMode.defaultBehavior)
        'dhcpRelayInformation': dhcpRelayInformation.storageValue,
    };
  }

  Port copyWith({
    int? id,
    int? deviceId,
    String? name,
    String? description,
    bool? enabled,
    IpAssignmentMode? ipAssignment,
    Ipv6AssignmentMode? ipv6Assignment,
    IPv4? ipAddress,
    IPv6? ipv6Address,
    String? ipv4AccessGroupIn,
    String? ipv4AccessGroupOut,
    String? ipv4HelperAddress,
    DhcpRelayInformationMode? dhcpRelayInformation,
  }) {
    return Port(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      ipAssignment: ipAssignment ?? this.ipAssignment,
      ipv6Assignment: ipv6Assignment ?? this.ipv6Assignment,
      ipAddress: ipAddress ?? this.ipAddress,
      ipv6Address: ipv6Address ?? this.ipv6Address,
      ipv4AccessGroupIn: ipv4AccessGroupIn ?? this.ipv4AccessGroupIn,
      ipv4AccessGroupOut: ipv4AccessGroupOut ?? this.ipv4AccessGroupOut,
      ipv4HelperAddress: ipv4HelperAddress ?? this.ipv4HelperAddress,
      dhcpRelayInformation: dhcpRelayInformation ?? this.dhcpRelayInformation,
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
      ipAssignment: other.ipAssignment,
      ipv6Assignment: other.ipv6Assignment,
      ipAddress: other.ipAddress ?? ipAddress,
      ipv6Address: other.ipv6Address ?? ipv6Address,
      ipv4AccessGroupIn: other.ipv4AccessGroupIn ?? ipv4AccessGroupIn,
      ipv4AccessGroupOut: other.ipv4AccessGroupOut ?? ipv4AccessGroupOut,
      ipv4HelperAddress: other.ipv4HelperAddress ?? ipv4HelperAddress,
      dhcpRelayInformation: other.dhcpRelayInformation,
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
          ipAssignment == other.ipAssignment &&
          ipv6Assignment == other.ipv6Assignment &&
          ipAddress == other.ipAddress &&
          ipv6Address == other.ipv6Address &&
          ipv4AccessGroupIn == other.ipv4AccessGroupIn &&
          ipv4AccessGroupOut == other.ipv4AccessGroupOut &&
          ipv4HelperAddress == other.ipv4HelperAddress &&
          dhcpRelayInformation == other.dhcpRelayInformation;

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    name,
    description,
    enabled,
    ipAssignment,
    ipv6Assignment,
    ipAddress,
    ipv6Address,
    ipv4AccessGroupIn,
    ipv4AccessGroupOut,
    ipv4HelperAddress,
    dhcpRelayInformation,
  );
}

String? _normalizeAclReference(dynamic value) {
  return _normalizeOptionalString(value);
}

String? _normalizeOptionalString(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  return raw;
}
