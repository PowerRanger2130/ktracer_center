import 'package:ktracer_center/network/port.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/ipv6.dart';

enum SwitchportMode { access, trunk }

enum PortSecurityViolation { shutdown, protect, restrict }

enum SpanningTreeGuard { none, root, loop }

class Switchport extends Port {
  final int vlan;
  final SwitchportMode mode;
  final int? nativeVlan;
  final String? allowedVlans;

  // Protected port (PVLAN edge)
  final bool protectedPort;

  // Port Security
  final bool portSecurityEnabled;
  final Set<String>? portSecurityMacAddresses;
  final bool portSecuritySticky;
  final PortSecurityViolation portSecurityViolation;
  final int portSecurityMaximum;

  // Spanning Tree
  final bool spanningTreePortfast;
  final bool spanningTreeBpduGuard;
  final bool spanningTreeBpduFilter;
  final int? spanningTreeCost;
  final int? spanningTreePortPriority;
  final SpanningTreeGuard spanningTreeGuard;

  // Channel group membership (null if not in a channel)
  final int? channelGroup;

  Switchport({
    super.id,
    super.deviceId,
    required super.name,
    super.description,
    super.enabled = true,
    this.vlan = 1,
    this.mode = SwitchportMode.access,
    this.nativeVlan,
    this.allowedVlans,
    // Protected port
    this.protectedPort = false,
    // Port Security
    this.portSecurityEnabled = false,
    this.portSecurityMacAddresses,
    this.portSecuritySticky = false,
    this.portSecurityViolation = PortSecurityViolation.shutdown,
    this.portSecurityMaximum = 1,
    // Spanning Tree
    this.spanningTreePortfast = false,
    this.spanningTreeBpduGuard = false,
    this.spanningTreeBpduFilter = false,
    this.spanningTreeCost,
    this.spanningTreePortPriority,
    this.spanningTreeGuard = SpanningTreeGuard.none,
    // Channel group
    this.channelGroup,
  });

  factory Switchport.fromJson(Map<String, dynamic> json) {
    return Switchport(
      id: json['id'],
      deviceId: json['device_id'],
      name: json['name'],
      description: json['description'],
      enabled: json['enabled'] ?? true,
      vlan: json['vlan'] ?? 1,
      mode: SwitchportMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => SwitchportMode.access,
      ),
      nativeVlan: json['nativeVlan'],
      allowedVlans: json['allowedVlans'],
      protectedPort: json['protectedPort'] ?? false,
      portSecurityEnabled: json['portSecurityEnabled'] ?? false,
      portSecurityMacAddresses: json['portSecurityMacAddresses'] != null
          ? Set<String>.from(json['portSecurityMacAddresses'])
          : null,
      portSecuritySticky: json['portSecuritySticky'] ?? false,
      portSecurityViolation: PortSecurityViolation.values.firstWhere(
        (e) => e.name == json['portSecurityViolation'],
        orElse: () => PortSecurityViolation.shutdown,
      ),
      portSecurityMaximum: json['portSecurityMaximum'] ?? 1,
      spanningTreePortfast: json['spanningTreePortfast'] ?? false,
      spanningTreeBpduGuard: json['spanningTreeBpduGuard'] ?? false,
      spanningTreeBpduFilter: json['spanningTreeBpduFilter'] ?? false,
      spanningTreeCost: json['spanningTreeCost'],
      spanningTreePortPriority: json['spanningTreePortPriority'],
      spanningTreeGuard: SpanningTreeGuard.values.firstWhere(
        (e) => e.name == json['spanningTreeGuard'],
        orElse: () => SpanningTreeGuard.none,
      ),
      channelGroup: json['channelGroup'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'name': name,
      'description': description,
      'enabled': enabled,
      'is_switchport': true,
      'vlan': vlan,
      'mode': mode.name,
      'nativeVlan': nativeVlan,
      'allowedVlans': allowedVlans,
      'protectedPort': protectedPort,
      'portSecurityEnabled': portSecurityEnabled,
      'portSecurityMacAddresses': portSecurityMacAddresses?.toList(),
      'portSecuritySticky': portSecuritySticky,
      'portSecurityViolation': portSecurityViolation.name,
      'portSecurityMaximum': portSecurityMaximum,
      'spanningTreePortfast': spanningTreePortfast,
      'spanningTreeBpduGuard': spanningTreeBpduGuard,
      'spanningTreeBpduFilter': spanningTreeBpduFilter,
      'spanningTreeCost': spanningTreeCost,
      'spanningTreePortPriority': spanningTreePortPriority,
      'spanningTreeGuard': spanningTreeGuard.name,
      'channelGroup': channelGroup,
    };
  }

  @override
  Switchport copyWith({
    int? id,
    int? deviceId,
    String? name,
    String? description,
    bool? enabled,
    IpAssignmentMode? ipAssignment, // From Port, ignored for Switchport
    Ipv6AssignmentMode? ipv6Assignment, // From Port, ignored for Switchport
    IPv4? ipAddress, // From Port, ignored for Switchport
    String? ipv4AccessGroupIn, // From Port, ignored for Switchport
    String? ipv4AccessGroupOut, // From Port, ignored for Switchport
    String? ipv4HelperAddress, // From Port, ignored for Switchport
    DhcpRelayInformationMode?
    dhcpRelayInformation, // From Port, ignored for Switchport
    IPv6? ipv6Address, // From Port, ignored for Switchport
    int? vlan,
    SwitchportMode? mode,
    int? nativeVlan,
    String? allowedVlans,
    bool? protectedPort,
    bool? portSecurityEnabled,
    Set<String>? portSecurityMacAddresses,
    bool? portSecuritySticky,
    PortSecurityViolation? portSecurityViolation,
    int? portSecurityMaximum,
    bool? spanningTreePortfast,
    bool? spanningTreeBpduGuard,
    bool? spanningTreeBpduFilter,
    int? spanningTreeCost,
    int? spanningTreePortPriority,
    SpanningTreeGuard? spanningTreeGuard,
    int? channelGroup,
  }) {
    return Switchport(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      description: description ?? this.description,
      enabled: enabled ?? this.enabled,
      vlan: vlan ?? this.vlan,
      mode: mode ?? this.mode,
      nativeVlan: nativeVlan ?? this.nativeVlan,
      allowedVlans: allowedVlans ?? this.allowedVlans,
      protectedPort: protectedPort ?? this.protectedPort,
      portSecurityEnabled: portSecurityEnabled ?? this.portSecurityEnabled,
      portSecurityMacAddresses:
          portSecurityMacAddresses ?? this.portSecurityMacAddresses,
      portSecuritySticky: portSecuritySticky ?? this.portSecuritySticky,
      portSecurityViolation:
          portSecurityViolation ?? this.portSecurityViolation,
      portSecurityMaximum: portSecurityMaximum ?? this.portSecurityMaximum,
      spanningTreePortfast: spanningTreePortfast ?? this.spanningTreePortfast,
      spanningTreeBpduGuard:
          spanningTreeBpduGuard ?? this.spanningTreeBpduGuard,
      spanningTreeBpduFilter:
          spanningTreeBpduFilter ?? this.spanningTreeBpduFilter,
      spanningTreeCost: spanningTreeCost ?? this.spanningTreeCost,
      spanningTreePortPriority:
          spanningTreePortPriority ?? this.spanningTreePortPriority,
      spanningTreeGuard: spanningTreeGuard ?? this.spanningTreeGuard,
      channelGroup: channelGroup ?? this.channelGroup,
    );
  }

  @override
  Switchport merge(covariant Switchport? other) {
    if (other == null) return this;
    return Switchport(
      id: other.id ?? id,
      deviceId: other.deviceId ?? deviceId,
      name: other.name.isNotEmpty ? other.name : name,
      description: other.description ?? description,
      enabled: other.enabled,
      vlan: other.vlan,
      mode: other.mode,
      nativeVlan: other.nativeVlan ?? nativeVlan,
      allowedVlans: other.allowedVlans ?? allowedVlans,
      protectedPort: other.protectedPort,
      portSecurityEnabled: other.portSecurityEnabled,
      portSecurityMacAddresses:
          other.portSecurityMacAddresses ?? portSecurityMacAddresses,
      portSecuritySticky: other.portSecuritySticky,
      portSecurityViolation: other.portSecurityViolation,
      portSecurityMaximum: other.portSecurityMaximum,
      spanningTreePortfast: other.spanningTreePortfast,
      spanningTreeBpduGuard: other.spanningTreeBpduGuard,
      spanningTreeBpduFilter: other.spanningTreeBpduFilter,
      spanningTreeCost: other.spanningTreeCost ?? spanningTreeCost,
      spanningTreePortPriority:
          other.spanningTreePortPriority ?? spanningTreePortPriority,
      spanningTreeGuard: other.spanningTreeGuard,
      channelGroup: other.channelGroup ?? channelGroup,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Switchport) return false;
    // Compare MAC addresses set
    if (portSecurityMacAddresses?.length !=
        other.portSecurityMacAddresses?.length) {
      return false;
    }
    if (portSecurityMacAddresses != null &&
        other.portSecurityMacAddresses != null) {
      for (final mac in portSecurityMacAddresses!) {
        if (!other.portSecurityMacAddresses!.contains(mac)) return false;
      }
    }
    return id == other.id &&
        deviceId == other.deviceId &&
        name == other.name &&
        description == other.description &&
        enabled == other.enabled &&
        vlan == other.vlan &&
        mode == other.mode &&
        nativeVlan == other.nativeVlan &&
        allowedVlans == other.allowedVlans &&
        protectedPort == other.protectedPort &&
        portSecurityEnabled == other.portSecurityEnabled &&
        portSecuritySticky == other.portSecuritySticky &&
        portSecurityViolation == other.portSecurityViolation &&
        portSecurityMaximum == other.portSecurityMaximum &&
        spanningTreePortfast == other.spanningTreePortfast &&
        spanningTreeBpduGuard == other.spanningTreeBpduGuard &&
        spanningTreeBpduFilter == other.spanningTreeBpduFilter &&
        spanningTreeCost == other.spanningTreeCost &&
        spanningTreePortPriority == other.spanningTreePortPriority &&
        spanningTreeGuard == other.spanningTreeGuard &&
        channelGroup == other.channelGroup;
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    name,
    description,
    enabled,
    vlan,
    mode,
    nativeVlan,
    allowedVlans,
    protectedPort,
    portSecurityEnabled,
    portSecurityMacAddresses != null
        ? Object.hashAll(portSecurityMacAddresses!)
        : null,
    portSecuritySticky,
    portSecurityViolation,
    portSecurityMaximum,
    spanningTreePortfast,
    spanningTreeBpduGuard,
    spanningTreeBpduFilter,
    Object.hash(
      spanningTreeCost,
      spanningTreePortPriority,
      spanningTreeGuard,
      channelGroup,
    ),
  );
}
