import 'package:flutter/foundation.dart';

/// Base class for all serializable network configuration objects.
/// Provides consistent interface for JSON serialization, merging, and copying.
abstract class NetworkConfig<T extends NetworkConfig<T>> {
  const NetworkConfig();

  /// Convert this config to JSON for storage
  Map<String, dynamic> toJson();

  /// Create a copy with optional field overrides
  T copyWith();

  /// Merge another config into this one (other values take precedence)
  T merge(T other);

  /// Deep equality check
  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

/// Mixin for configs that can be enabled/disabled
mixin EnableableMixin {
  bool get enabled;
}

/// Mixin for configs that have a unique identifier
mixin IdentifiableMixin {
  /// Unique identifier within the collection
  String get identifier;
}

// ============================================================================
// HSRP / VRRP / GLBP - First Hop Redundancy
// ============================================================================

/// HSRP group member configuration
class HsrpMember extends NetworkConfig<HsrpMember> {
  final int deviceId;
  final String interfaceName; // e.g., "GigabitEthernet0/0" or "Vlan10"
  final int priority;
  final bool preempt;
  final String? trackInterface; // Interface to track for priority decrement
  final int? trackDecrement;

  const HsrpMember({
    required this.deviceId,
    required this.interfaceName,
    this.priority = 100,
    this.preempt = false,
    this.trackInterface,
    this.trackDecrement,
  });

  factory HsrpMember.fromJson(Map<String, dynamic> json) {
    return HsrpMember(
      deviceId: json['device_id'],
      interfaceName: json['interface_name'] ?? '',
      priority: json['priority'] ?? 100,
      preempt: json['preempt'] ?? false,
      trackInterface: json['track_interface'],
      trackDecrement: json['track_decrement'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'interface_name': interfaceName,
    'priority': priority,
    'preempt': preempt,
    if (trackInterface != null) 'track_interface': trackInterface,
    if (trackDecrement != null) 'track_decrement': trackDecrement,
  };

  @override
  HsrpMember copyWith({
    int? deviceId,
    String? interfaceName,
    int? priority,
    bool? preempt,
    String? trackInterface,
    int? trackDecrement,
  }) => HsrpMember(
    deviceId: deviceId ?? this.deviceId,
    interfaceName: interfaceName ?? this.interfaceName,
    priority: priority ?? this.priority,
    preempt: preempt ?? this.preempt,
    trackInterface: trackInterface ?? this.trackInterface,
    trackDecrement: trackDecrement ?? this.trackDecrement,
  );

  @override
  HsrpMember merge(HsrpMember other) => copyWith(
    deviceId: other.deviceId,
    interfaceName: other.interfaceName,
    priority: other.priority,
    preempt: other.preempt,
    trackInterface: other.trackInterface,
    trackDecrement: other.trackDecrement,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HsrpMember &&
          deviceId == other.deviceId &&
          interfaceName == other.interfaceName &&
          priority == other.priority &&
          preempt == other.preempt &&
          trackInterface == other.trackInterface &&
          trackDecrement == other.trackDecrement;

  @override
  int get hashCode => Object.hash(
    deviceId,
    interfaceName,
    priority,
    preempt,
    trackInterface,
    trackDecrement,
  );
}

/// HSRP group configuration
class HsrpGroup extends NetworkConfig<HsrpGroup>
    with EnableableMixin, IdentifiableMixin {
  final String name; // Display name for the group
  final int groupNumber;
  final int vlanId; // Which VLAN/subnet this HSRP group is for
  final String? virtualIp; // Made nullable - can be set later
  final List<HsrpMember> members;
  final int helloTimer; // seconds (default 3)
  final int holdTimer; // seconds (default 10)
  final int version; // 1 or 2
  final String? authenticationKey;
  @override
  final bool enabled;

  const HsrpGroup({
    required this.name,
    required this.groupNumber,
    this.vlanId = 1,
    this.virtualIp,
    this.members = const [],
    this.helloTimer = 3,
    this.holdTimer = 10,
    this.version = 2,
    this.authenticationKey,
    this.enabled = true,
  });

  @override
  String get identifier => 'hsrp_${vlanId}_$groupNumber';

  factory HsrpGroup.fromJson(Map<String, dynamic> json) {
    return HsrpGroup(
      name: json['name'] ?? 'HSRP Group ${json['group_number'] ?? 0}',
      groupNumber: json['group_number'] ?? 0,
      vlanId: json['vlan_id'] ?? 1,
      virtualIp: json['virtual_ip'],
      members:
          (json['members'] as List<dynamic>?)
              ?.map((m) => HsrpMember.fromJson(m))
              .toList() ??
          [],
      helloTimer: json['hello_timer'] ?? 3,
      holdTimer: json['hold_timer'] ?? 10,
      version: json['version'] ?? 2,
      authenticationKey: json['authentication_key'],
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'group_number': groupNumber,
    'vlan_id': vlanId,
    if (virtualIp != null) 'virtual_ip': virtualIp,
    'members': members.map((m) => m.toJson()).toList(),
    'hello_timer': helloTimer,
    'hold_timer': holdTimer,
    'version': version,
    if (authenticationKey != null) 'authentication_key': authenticationKey,
    'enabled': enabled,
  };

  @override
  HsrpGroup copyWith({
    String? name,
    int? groupNumber,
    int? vlanId,
    String? virtualIp,
    bool clearVirtualIp = false,
    List<HsrpMember>? members,
    int? helloTimer,
    int? holdTimer,
    int? version,
    String? authenticationKey,
    bool? enabled,
  }) => HsrpGroup(
    name: name ?? this.name,
    groupNumber: groupNumber ?? this.groupNumber,
    vlanId: vlanId ?? this.vlanId,
    virtualIp: clearVirtualIp ? null : (virtualIp ?? this.virtualIp),
    members: members ?? this.members,
    helloTimer: helloTimer ?? this.helloTimer,
    holdTimer: holdTimer ?? this.holdTimer,
    version: version ?? this.version,
    authenticationKey: authenticationKey ?? this.authenticationKey,
    enabled: enabled ?? this.enabled,
  );

  @override
  HsrpGroup merge(HsrpGroup other) => copyWith(
    name: other.name,
    groupNumber: other.groupNumber,
    vlanId: other.vlanId,
    virtualIp: other.virtualIp,
    members: other.members,
    helloTimer: other.helloTimer,
    holdTimer: other.holdTimer,
    version: other.version,
    authenticationKey: other.authenticationKey,
    enabled: other.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HsrpGroup &&
          name == other.name &&
          groupNumber == other.groupNumber &&
          vlanId == other.vlanId &&
          virtualIp == other.virtualIp &&
          listEquals(members, other.members) &&
          helloTimer == other.helloTimer &&
          holdTimer == other.holdTimer &&
          version == other.version &&
          authenticationKey == other.authenticationKey &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    name,
    groupNumber,
    vlanId,
    virtualIp,
    Object.hashAll(members),
    helloTimer,
    holdTimer,
    version,
    authenticationKey,
    enabled,
  );
}

// ============================================================================
// OSPF Configuration
// ============================================================================

/// OSPF network statement
class OspfNetwork extends NetworkConfig<OspfNetwork> {
  final String network; // e.g., "192.168.1.0"
  final String wildcardMask; // e.g., "0.0.0.255"
  final int areaId;

  const OspfNetwork({
    required this.network,
    required this.wildcardMask,
    required this.areaId,
  });

  factory OspfNetwork.fromJson(Map<String, dynamic> json) {
    return OspfNetwork(
      network: json['network'] ?? '',
      wildcardMask: json['wildcard_mask'] ?? '0.0.0.255',
      areaId: json['area_id'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'network': network,
    'wildcard_mask': wildcardMask,
    'area_id': areaId,
  };

  @override
  OspfNetwork copyWith({String? network, String? wildcardMask, int? areaId}) =>
      OspfNetwork(
        network: network ?? this.network,
        wildcardMask: wildcardMask ?? this.wildcardMask,
        areaId: areaId ?? this.areaId,
      );

  @override
  OspfNetwork merge(OspfNetwork other) => copyWith(
    network: other.network,
    wildcardMask: other.wildcardMask,
    areaId: other.areaId,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OspfNetwork &&
          network == other.network &&
          wildcardMask == other.wildcardMask &&
          areaId == other.areaId;

  @override
  int get hashCode => Object.hash(network, wildcardMask, areaId);
}

/// OSPF interface settings
class OspfInterfaceConfig extends NetworkConfig<OspfInterfaceConfig> {
  final String interfaceName;
  final int? cost;
  final int? priority; // DR election priority
  final int? helloInterval;
  final int? deadInterval;
  final OspfNetworkType? networkType;
  final bool passive;
  final String? authenticationKey;
  final OspfAuthType? authType;

  const OspfInterfaceConfig({
    required this.interfaceName,
    this.cost,
    this.priority,
    this.helloInterval,
    this.deadInterval,
    this.networkType,
    this.passive = false,
    this.authenticationKey,
    this.authType,
  });

  factory OspfInterfaceConfig.fromJson(Map<String, dynamic> json) {
    return OspfInterfaceConfig(
      interfaceName: json['interface_name'] ?? '',
      cost: json['cost'],
      priority: json['priority'],
      helloInterval: json['hello_interval'],
      deadInterval: json['dead_interval'],
      networkType: json['network_type'] != null
          ? OspfNetworkType.values.firstWhere(
              (e) => e.name == json['network_type'],
              orElse: () => OspfNetworkType.broadcast,
            )
          : null,
      passive: json['passive'] ?? false,
      authenticationKey: json['authentication_key'],
      authType: json['auth_type'] != null
          ? OspfAuthType.values.firstWhere(
              (e) => e.name == json['auth_type'],
              orElse: () => OspfAuthType.none,
            )
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'interface_name': interfaceName,
    if (cost != null) 'cost': cost,
    if (priority != null) 'priority': priority,
    if (helloInterval != null) 'hello_interval': helloInterval,
    if (deadInterval != null) 'dead_interval': deadInterval,
    if (networkType != null) 'network_type': networkType!.name,
    'passive': passive,
    if (authenticationKey != null) 'authentication_key': authenticationKey,
    if (authType != null) 'auth_type': authType!.name,
  };

  @override
  OspfInterfaceConfig copyWith({
    String? interfaceName,
    int? cost,
    int? priority,
    int? helloInterval,
    int? deadInterval,
    OspfNetworkType? networkType,
    bool? passive,
    String? authenticationKey,
    OspfAuthType? authType,
  }) => OspfInterfaceConfig(
    interfaceName: interfaceName ?? this.interfaceName,
    cost: cost ?? this.cost,
    priority: priority ?? this.priority,
    helloInterval: helloInterval ?? this.helloInterval,
    deadInterval: deadInterval ?? this.deadInterval,
    networkType: networkType ?? this.networkType,
    passive: passive ?? this.passive,
    authenticationKey: authenticationKey ?? this.authenticationKey,
    authType: authType ?? this.authType,
  );

  @override
  OspfInterfaceConfig merge(OspfInterfaceConfig other) => copyWith(
    interfaceName: other.interfaceName,
    cost: other.cost,
    priority: other.priority,
    helloInterval: other.helloInterval,
    deadInterval: other.deadInterval,
    networkType: other.networkType,
    passive: other.passive,
    authenticationKey: other.authenticationKey,
    authType: other.authType,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OspfInterfaceConfig &&
          interfaceName == other.interfaceName &&
          cost == other.cost &&
          priority == other.priority &&
          helloInterval == other.helloInterval &&
          deadInterval == other.deadInterval &&
          networkType == other.networkType &&
          passive == other.passive &&
          authenticationKey == other.authenticationKey &&
          authType == other.authType;

  @override
  int get hashCode => Object.hash(
    interfaceName,
    cost,
    priority,
    helloInterval,
    deadInterval,
    networkType,
    passive,
    authenticationKey,
    authType,
  );
}

enum OspfNetworkType {
  broadcast,
  pointToPoint,
  nonBroadcast,
  pointToMultipoint,
}

enum OspfAuthType { none, plaintext, md5 }

enum OspfAreaType { normal, stub, totallyStub, nssa, totallyNssa }

/// OSPF member (a device participating in OSPF)
class OspfMember extends NetworkConfig<OspfMember> {
  final int deviceId;
  final String? routerId; // Usually loopback or highest IP
  final List<OspfNetwork> networks;
  final List<OspfInterfaceConfig> interfaceConfigs;
  final bool defaultInformationOriginate;
  final bool defaultInformationAlways;

  const OspfMember({
    required this.deviceId,
    this.routerId,
    this.networks = const [],
    this.interfaceConfigs = const [],
    this.defaultInformationOriginate = false,
    this.defaultInformationAlways = false,
  });

  factory OspfMember.fromJson(Map<String, dynamic> json) {
    return OspfMember(
      deviceId: json['device_id'],
      routerId: json['router_id'],
      networks:
          (json['networks'] as List<dynamic>?)
              ?.map((n) => OspfNetwork.fromJson(n))
              .toList() ??
          [],
      interfaceConfigs:
          (json['interface_configs'] as List<dynamic>?)
              ?.map((c) => OspfInterfaceConfig.fromJson(c))
              .toList() ??
          [],
      defaultInformationOriginate:
          json['default_information_originate'] ?? false,
      defaultInformationAlways: json['default_information_always'] ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    if (routerId != null) 'router_id': routerId,
    'networks': networks.map((n) => n.toJson()).toList(),
    'interface_configs': interfaceConfigs.map((c) => c.toJson()).toList(),
    'default_information_originate': defaultInformationOriginate,
    'default_information_always': defaultInformationAlways,
  };

  @override
  OspfMember copyWith({
    int? deviceId,
    String? routerId,
    List<OspfNetwork>? networks,
    List<OspfInterfaceConfig>? interfaceConfigs,
    bool? defaultInformationOriginate,
    bool? defaultInformationAlways,
  }) => OspfMember(
    deviceId: deviceId ?? this.deviceId,
    routerId: routerId ?? this.routerId,
    networks: networks ?? this.networks,
    interfaceConfigs: interfaceConfigs ?? this.interfaceConfigs,
    defaultInformationOriginate:
        defaultInformationOriginate ?? this.defaultInformationOriginate,
    defaultInformationAlways:
        defaultInformationAlways ?? this.defaultInformationAlways,
  );

  @override
  OspfMember merge(OspfMember other) => copyWith(
    deviceId: other.deviceId,
    routerId: other.routerId,
    networks: other.networks,
    interfaceConfigs: other.interfaceConfigs,
    defaultInformationOriginate: other.defaultInformationOriginate,
    defaultInformationAlways: other.defaultInformationAlways,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OspfMember &&
          deviceId == other.deviceId &&
          routerId == other.routerId &&
          listEquals(networks, other.networks) &&
          listEquals(interfaceConfigs, other.interfaceConfigs) &&
          defaultInformationOriginate == other.defaultInformationOriginate &&
          defaultInformationAlways == other.defaultInformationAlways;

  @override
  int get hashCode => Object.hash(
    deviceId,
    routerId,
    Object.hashAll(networks),
    Object.hashAll(interfaceConfigs),
    defaultInformationOriginate,
    defaultInformationAlways,
  );
}

/// OSPF Area configuration
class OspfArea extends NetworkConfig<OspfArea> {
  final int areaId;
  final OspfAreaType type;
  final bool noSummary; // For stub/NSSA areas
  final int? defaultCost; // For stub areas

  const OspfArea({
    required this.areaId,
    this.type = OspfAreaType.normal,
    this.noSummary = false,
    this.defaultCost,
  });

  factory OspfArea.fromJson(Map<String, dynamic> json) {
    return OspfArea(
      areaId: json['area_id'] ?? 0,
      type: OspfAreaType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => OspfAreaType.normal,
      ),
      noSummary: json['no_summary'] ?? false,
      defaultCost: json['default_cost'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'area_id': areaId,
    'type': type.name,
    'no_summary': noSummary,
    if (defaultCost != null) 'default_cost': defaultCost,
  };

  @override
  OspfArea copyWith({
    int? areaId,
    OspfAreaType? type,
    bool? noSummary,
    int? defaultCost,
  }) => OspfArea(
    areaId: areaId ?? this.areaId,
    type: type ?? this.type,
    noSummary: noSummary ?? this.noSummary,
    defaultCost: defaultCost ?? this.defaultCost,
  );

  @override
  OspfArea merge(OspfArea other) => copyWith(
    areaId: other.areaId,
    type: other.type,
    noSummary: other.noSummary,
    defaultCost: other.defaultCost,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OspfArea &&
          areaId == other.areaId &&
          type == other.type &&
          noSummary == other.noSummary &&
          defaultCost == other.defaultCost;

  @override
  int get hashCode => Object.hash(areaId, type, noSummary, defaultCost);
}

/// OSPF domain configuration (process)
class OspfDomain extends NetworkConfig<OspfDomain>
    with EnableableMixin, IdentifiableMixin {
  final int processId;
  final List<OspfArea> areas;
  final List<OspfMember> members;
  final int? referenceBandwidth; // For auto-cost calculation
  @override
  final bool enabled;

  const OspfDomain({
    required this.processId,
    this.areas = const [],
    this.members = const [],
    this.referenceBandwidth,
    this.enabled = true,
  });

  @override
  String get identifier => 'ospf_$processId';

  factory OspfDomain.fromJson(Map<String, dynamic> json) {
    return OspfDomain(
      processId: json['process_id'] ?? 1,
      areas:
          (json['areas'] as List<dynamic>?)
              ?.map((a) => OspfArea.fromJson(a))
              .toList() ??
          [],
      members:
          (json['members'] as List<dynamic>?)
              ?.map((m) => OspfMember.fromJson(m))
              .toList() ??
          [],
      referenceBandwidth: json['reference_bandwidth'],
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'process_id': processId,
    'areas': areas.map((a) => a.toJson()).toList(),
    'members': members.map((m) => m.toJson()).toList(),
    if (referenceBandwidth != null) 'reference_bandwidth': referenceBandwidth,
    'enabled': enabled,
  };

  @override
  OspfDomain copyWith({
    int? processId,
    List<OspfArea>? areas,
    List<OspfMember>? members,
    int? referenceBandwidth,
    bool? enabled,
  }) => OspfDomain(
    processId: processId ?? this.processId,
    areas: areas ?? this.areas,
    members: members ?? this.members,
    referenceBandwidth: referenceBandwidth ?? this.referenceBandwidth,
    enabled: enabled ?? this.enabled,
  );

  @override
  OspfDomain merge(OspfDomain other) => copyWith(
    processId: other.processId,
    areas: other.areas,
    members: other.members,
    referenceBandwidth: other.referenceBandwidth,
    enabled: other.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OspfDomain &&
          processId == other.processId &&
          listEquals(areas, other.areas) &&
          listEquals(members, other.members) &&
          referenceBandwidth == other.referenceBandwidth &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    processId,
    Object.hashAll(areas),
    Object.hashAll(members),
    referenceBandwidth,
    enabled,
  );
}

// ============================================================================
// EIGRP Configuration
// ============================================================================

/// EIGRP member configuration
class EigrpMember extends NetworkConfig<EigrpMember> {
  final int deviceId;
  final String? routerId;
  final List<String> networks; // Networks to advertise (with wildcard masks)
  final List<String> passiveInterfaces;
  final bool autoSummary;

  const EigrpMember({
    required this.deviceId,
    this.routerId,
    this.networks = const [],
    this.passiveInterfaces = const [],
    this.autoSummary = false,
  });

  factory EigrpMember.fromJson(Map<String, dynamic> json) {
    return EigrpMember(
      deviceId: json['device_id'],
      routerId: json['router_id'],
      networks:
          (json['networks'] as List<dynamic>?)
              ?.map((n) => n.toString())
              .toList() ??
          [],
      passiveInterfaces:
          (json['passive_interfaces'] as List<dynamic>?)
              ?.map((i) => i.toString())
              .toList() ??
          [],
      autoSummary: json['auto_summary'] ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    if (routerId != null) 'router_id': routerId,
    'networks': networks,
    'passive_interfaces': passiveInterfaces,
    'auto_summary': autoSummary,
  };

  @override
  EigrpMember copyWith({
    int? deviceId,
    String? routerId,
    List<String>? networks,
    List<String>? passiveInterfaces,
    bool? autoSummary,
  }) => EigrpMember(
    deviceId: deviceId ?? this.deviceId,
    routerId: routerId ?? this.routerId,
    networks: networks ?? this.networks,
    passiveInterfaces: passiveInterfaces ?? this.passiveInterfaces,
    autoSummary: autoSummary ?? this.autoSummary,
  );

  @override
  EigrpMember merge(EigrpMember other) => copyWith(
    deviceId: other.deviceId,
    routerId: other.routerId,
    networks: other.networks,
    passiveInterfaces: other.passiveInterfaces,
    autoSummary: other.autoSummary,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EigrpMember &&
          deviceId == other.deviceId &&
          routerId == other.routerId &&
          listEquals(networks, other.networks) &&
          listEquals(passiveInterfaces, other.passiveInterfaces) &&
          autoSummary == other.autoSummary;

  @override
  int get hashCode => Object.hash(
    deviceId,
    routerId,
    Object.hashAll(networks),
    Object.hashAll(passiveInterfaces),
    autoSummary,
  );
}

/// EIGRP domain configuration
class EigrpDomain extends NetworkConfig<EigrpDomain>
    with EnableableMixin, IdentifiableMixin {
  final int asNumber;
  final List<EigrpMember> members;
  final bool namedMode; // EIGRP named mode vs classic
  final String? namedInstanceName;
  @override
  final bool enabled;

  const EigrpDomain({
    required this.asNumber,
    this.members = const [],
    this.namedMode = false,
    this.namedInstanceName,
    this.enabled = true,
  });

  @override
  String get identifier => 'eigrp_$asNumber';

  factory EigrpDomain.fromJson(Map<String, dynamic> json) {
    return EigrpDomain(
      asNumber: json['as_number'] ?? 1,
      members:
          (json['members'] as List<dynamic>?)
              ?.map((m) => EigrpMember.fromJson(m))
              .toList() ??
          [],
      namedMode: json['named_mode'] ?? false,
      namedInstanceName: json['named_instance_name'],
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'as_number': asNumber,
    'members': members.map((m) => m.toJson()).toList(),
    'named_mode': namedMode,
    if (namedInstanceName != null) 'named_instance_name': namedInstanceName,
    'enabled': enabled,
  };

  @override
  EigrpDomain copyWith({
    int? asNumber,
    List<EigrpMember>? members,
    bool? namedMode,
    String? namedInstanceName,
    bool? enabled,
  }) => EigrpDomain(
    asNumber: asNumber ?? this.asNumber,
    members: members ?? this.members,
    namedMode: namedMode ?? this.namedMode,
    namedInstanceName: namedInstanceName ?? this.namedInstanceName,
    enabled: enabled ?? this.enabled,
  );

  @override
  EigrpDomain merge(EigrpDomain other) => copyWith(
    asNumber: other.asNumber,
    members: other.members,
    namedMode: other.namedMode,
    namedInstanceName: other.namedInstanceName,
    enabled: other.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EigrpDomain &&
          asNumber == other.asNumber &&
          listEquals(members, other.members) &&
          namedMode == other.namedMode &&
          namedInstanceName == other.namedInstanceName &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    asNumber,
    Object.hashAll(members),
    namedMode,
    namedInstanceName,
    enabled,
  );
}

// ============================================================================
// BGP Configuration
// ============================================================================

/// BGP neighbor configuration
class BgpNeighbor extends NetworkConfig<BgpNeighbor> with EnableableMixin {
  final String neighborAddress; // Resolved IP address or peer-group name
  final int? neighborDeviceId; // Selected peer device (optional)
  final String? neighborInterfaceKey; // Selected peer interface key (optional)
  final int remoteAs;
  final String? description;
  final String? updateSource; // Interface name for update-source
  final bool ebgpMultihop;
  final int? ebgpMultihopTtl;
  final String? password;
  final bool nextHopSelf;
  final bool routeReflectorClient;
  final bool softReconfigurationInbound;
  final String? peerGroup; // Peer group membership
  @override
  final bool enabled;

  const BgpNeighbor({
    required this.neighborAddress,
    this.neighborDeviceId,
    this.neighborInterfaceKey,
    required this.remoteAs,
    this.description,
    this.updateSource,
    this.ebgpMultihop = false,
    this.ebgpMultihopTtl,
    this.password,
    this.nextHopSelf = false,
    this.routeReflectorClient = false,
    this.softReconfigurationInbound = false,
    this.peerGroup,
    this.enabled = true,
  });

  factory BgpNeighbor.fromJson(Map<String, dynamic> json) {
    return BgpNeighbor(
      neighborAddress: json['neighbor_address'] ?? '',
      neighborDeviceId: json['neighbor_device_id'],
      neighborInterfaceKey: json['neighbor_interface_key'],
      remoteAs: json['remote_as'] ?? 0,
      description: json['description'],
      updateSource: json['update_source'],
      ebgpMultihop: json['ebgp_multihop'] ?? false,
      ebgpMultihopTtl: json['ebgp_multihop_ttl'],
      password: json['password'],
      nextHopSelf: json['next_hop_self'] ?? false,
      routeReflectorClient: json['route_reflector_client'] ?? false,
      softReconfigurationInbound: json['soft_reconfiguration_inbound'] ?? false,
      peerGroup: json['peer_group'],
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'neighbor_address': neighborAddress,
    if (neighborDeviceId != null) 'neighbor_device_id': neighborDeviceId,
    if (neighborInterfaceKey != null)
      'neighbor_interface_key': neighborInterfaceKey,
    'remote_as': remoteAs,
    if (description != null) 'description': description,
    if (updateSource != null) 'update_source': updateSource,
    'ebgp_multihop': ebgpMultihop,
    if (ebgpMultihopTtl != null) 'ebgp_multihop_ttl': ebgpMultihopTtl,
    if (password != null) 'password': password,
    'next_hop_self': nextHopSelf,
    'route_reflector_client': routeReflectorClient,
    'soft_reconfiguration_inbound': softReconfigurationInbound,
    if (peerGroup != null) 'peer_group': peerGroup,
    'enabled': enabled,
  };

  @override
  BgpNeighbor copyWith({
    String? neighborAddress,
    int? neighborDeviceId,
    String? neighborInterfaceKey,
    int? remoteAs,
    String? description,
    String? updateSource,
    bool? ebgpMultihop,
    int? ebgpMultihopTtl,
    String? password,
    bool? nextHopSelf,
    bool? routeReflectorClient,
    bool? softReconfigurationInbound,
    String? peerGroup,
    bool? enabled,
  }) => BgpNeighbor(
    neighborAddress: neighborAddress ?? this.neighborAddress,
    neighborDeviceId: neighborDeviceId ?? this.neighborDeviceId,
    neighborInterfaceKey: neighborInterfaceKey ?? this.neighborInterfaceKey,
    remoteAs: remoteAs ?? this.remoteAs,
    description: description ?? this.description,
    updateSource: updateSource ?? this.updateSource,
    ebgpMultihop: ebgpMultihop ?? this.ebgpMultihop,
    ebgpMultihopTtl: ebgpMultihopTtl ?? this.ebgpMultihopTtl,
    password: password ?? this.password,
    nextHopSelf: nextHopSelf ?? this.nextHopSelf,
    routeReflectorClient: routeReflectorClient ?? this.routeReflectorClient,
    softReconfigurationInbound:
        softReconfigurationInbound ?? this.softReconfigurationInbound,
    peerGroup: peerGroup ?? this.peerGroup,
    enabled: enabled ?? this.enabled,
  );

  @override
  BgpNeighbor merge(BgpNeighbor other) => copyWith(
    neighborAddress: other.neighborAddress,
    neighborDeviceId: other.neighborDeviceId,
    neighborInterfaceKey: other.neighborInterfaceKey,
    remoteAs: other.remoteAs,
    description: other.description,
    updateSource: other.updateSource,
    ebgpMultihop: other.ebgpMultihop,
    ebgpMultihopTtl: other.ebgpMultihopTtl,
    password: other.password,
    nextHopSelf: other.nextHopSelf,
    routeReflectorClient: other.routeReflectorClient,
    softReconfigurationInbound: other.softReconfigurationInbound,
    peerGroup: other.peerGroup,
    enabled: other.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BgpNeighbor &&
          neighborAddress == other.neighborAddress &&
          neighborDeviceId == other.neighborDeviceId &&
          neighborInterfaceKey == other.neighborInterfaceKey &&
          remoteAs == other.remoteAs &&
          description == other.description &&
          updateSource == other.updateSource &&
          ebgpMultihop == other.ebgpMultihop &&
          ebgpMultihopTtl == other.ebgpMultihopTtl &&
          password == other.password &&
          nextHopSelf == other.nextHopSelf &&
          routeReflectorClient == other.routeReflectorClient &&
          softReconfigurationInbound == other.softReconfigurationInbound &&
          peerGroup == other.peerGroup &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    neighborAddress,
    neighborDeviceId,
    neighborInterfaceKey,
    remoteAs,
    description,
    updateSource,
    ebgpMultihop,
    ebgpMultihopTtl,
    password,
    nextHopSelf,
    routeReflectorClient,
    softReconfigurationInbound,
    peerGroup,
    enabled,
  );
}

/// BGP network advertisement
class BgpNetwork extends NetworkConfig<BgpNetwork> {
  final String network; // Network address
  final String? mask; // Subnet mask (optional, uses classful if not specified)
  final String? routeMap; // Route-map name

  const BgpNetwork({required this.network, this.mask, this.routeMap});

  factory BgpNetwork.fromJson(Map<String, dynamic> json) {
    return BgpNetwork(
      network: json['network'] ?? '',
      mask: json['mask'],
      routeMap: json['route_map'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'network': network,
    if (mask != null) 'mask': mask,
    if (routeMap != null) 'route_map': routeMap,
  };

  @override
  BgpNetwork copyWith({String? network, String? mask, String? routeMap}) =>
      BgpNetwork(
        network: network ?? this.network,
        mask: mask ?? this.mask,
        routeMap: routeMap ?? this.routeMap,
      );

  @override
  BgpNetwork merge(BgpNetwork other) => copyWith(
    network: other.network,
    mask: other.mask,
    routeMap: other.routeMap,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BgpNetwork &&
          network == other.network &&
          mask == other.mask &&
          routeMap == other.routeMap;

  @override
  int get hashCode => Object.hash(network, mask, routeMap);
}

/// BGP member configuration (per device)
class BgpMember extends NetworkConfig<BgpMember> {
  final int deviceId;
  final String? routerId;
  final List<BgpNeighbor> neighbors;
  final List<BgpNetwork> networks;
  final List<String>
  redistributeProtocols; // e.g., ['ospf 1', 'static', 'connected']
  final bool synchronization;
  final bool autoSummary;

  const BgpMember({
    required this.deviceId,
    this.routerId,
    this.neighbors = const [],
    this.networks = const [],
    this.redistributeProtocols = const [],
    this.synchronization = false,
    this.autoSummary = false,
  });

  factory BgpMember.fromJson(Map<String, dynamic> json) {
    return BgpMember(
      deviceId: json['device_id'],
      routerId: json['router_id'],
      neighbors:
          (json['neighbors'] as List<dynamic>?)
              ?.map((n) => BgpNeighbor.fromJson(n))
              .toList() ??
          [],
      networks:
          (json['networks'] as List<dynamic>?)
              ?.map((n) => BgpNetwork.fromJson(n))
              .toList() ??
          [],
      redistributeProtocols:
          (json['redistribute_protocols'] as List<dynamic>?)
              ?.map((p) => p.toString())
              .toList() ??
          [],
      synchronization: json['synchronization'] ?? false,
      autoSummary: json['auto_summary'] ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    if (routerId != null) 'router_id': routerId,
    'neighbors': neighbors.map((n) => n.toJson()).toList(),
    'networks': networks.map((n) => n.toJson()).toList(),
    'redistribute_protocols': redistributeProtocols,
    'synchronization': synchronization,
    'auto_summary': autoSummary,
  };

  @override
  BgpMember copyWith({
    int? deviceId,
    String? routerId,
    List<BgpNeighbor>? neighbors,
    List<BgpNetwork>? networks,
    List<String>? redistributeProtocols,
    bool? synchronization,
    bool? autoSummary,
  }) => BgpMember(
    deviceId: deviceId ?? this.deviceId,
    routerId: routerId ?? this.routerId,
    neighbors: neighbors ?? this.neighbors,
    networks: networks ?? this.networks,
    redistributeProtocols: redistributeProtocols ?? this.redistributeProtocols,
    synchronization: synchronization ?? this.synchronization,
    autoSummary: autoSummary ?? this.autoSummary,
  );

  @override
  BgpMember merge(BgpMember other) => copyWith(
    deviceId: other.deviceId,
    routerId: other.routerId,
    neighbors: other.neighbors,
    networks: other.networks,
    redistributeProtocols: other.redistributeProtocols,
    synchronization: other.synchronization,
    autoSummary: other.autoSummary,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BgpMember &&
          deviceId == other.deviceId &&
          routerId == other.routerId &&
          listEquals(neighbors, other.neighbors) &&
          listEquals(networks, other.networks) &&
          listEquals(redistributeProtocols, other.redistributeProtocols) &&
          synchronization == other.synchronization &&
          autoSummary == other.autoSummary;

  @override
  int get hashCode => Object.hash(
    deviceId,
    routerId,
    Object.hashAll(neighbors),
    Object.hashAll(networks),
    Object.hashAll(redistributeProtocols),
    synchronization,
    autoSummary,
  );
}

/// BGP AS configuration
class BgpDomain extends NetworkConfig<BgpDomain>
    with EnableableMixin, IdentifiableMixin {
  final int asNumber;
  final List<BgpMember> members;
  final bool logNeighborChanges;
  @override
  final bool enabled;

  const BgpDomain({
    required this.asNumber,
    this.members = const [],
    this.logNeighborChanges = true,
    this.enabled = true,
  });

  @override
  String get identifier => 'bgp_$asNumber';

  factory BgpDomain.fromJson(Map<String, dynamic> json) {
    return BgpDomain(
      asNumber: json['as_number'] ?? 65000,
      members:
          (json['members'] as List<dynamic>?)
              ?.map((m) => BgpMember.fromJson(m))
              .toList() ??
          [],
      logNeighborChanges: json['log_neighbor_changes'] ?? true,
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'as_number': asNumber,
    'members': members.map((m) => m.toJson()).toList(),
    'log_neighbor_changes': logNeighborChanges,
    'enabled': enabled,
  };

  @override
  BgpDomain copyWith({
    int? asNumber,
    List<BgpMember>? members,
    bool? logNeighborChanges,
    bool? enabled,
  }) => BgpDomain(
    asNumber: asNumber ?? this.asNumber,
    members: members ?? this.members,
    logNeighborChanges: logNeighborChanges ?? this.logNeighborChanges,
    enabled: enabled ?? this.enabled,
  );

  @override
  BgpDomain merge(BgpDomain other) => copyWith(
    asNumber: other.asNumber,
    members: other.members,
    logNeighborChanges: other.logNeighborChanges,
    enabled: other.enabled,
  );

  BgpMember? getMember(int deviceId) {
    for (final member in members) {
      if (member.deviceId == deviceId) return member;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BgpDomain &&
          asNumber == other.asNumber &&
          listEquals(members, other.members) &&
          logNeighborChanges == other.logNeighborChanges &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    asNumber,
    Object.hashAll(members),
    logNeighborChanges,
    enabled,
  );
}

// ============================================================================
// VRF Configuration
// ============================================================================

/// VRF Route Target configuration
class VrfRouteTarget extends NetworkConfig<VrfRouteTarget> {
  final String target; // e.g., "65000:1"
  final bool import;
  final bool export;

  const VrfRouteTarget({
    required this.target,
    this.import = true,
    this.export = true,
  });

  factory VrfRouteTarget.fromJson(Map<String, dynamic> json) {
    return VrfRouteTarget(
      target: json['target'] ?? '',
      import: json['import'] ?? true,
      export: json['export'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'target': target,
    'import': import,
    'export': export,
  };

  @override
  VrfRouteTarget copyWith({String? target, bool? import, bool? export}) =>
      VrfRouteTarget(
        target: target ?? this.target,
        import: import ?? this.import,
        export: export ?? this.export,
      );

  @override
  VrfRouteTarget merge(VrfRouteTarget other) => copyWith(
    target: other.target,
    import: other.import,
    export: other.export,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VrfRouteTarget &&
          target == other.target &&
          import == other.import &&
          export == other.export;

  @override
  int get hashCode => Object.hash(target, import, export);
}

/// VRF instance configuration
class VrfInstance extends NetworkConfig<VrfInstance>
    with EnableableMixin, IdentifiableMixin {
  final String name;
  final String? description;
  final String? routeDistinguisher; // e.g., "65000:1"
  final List<VrfRouteTarget> routeTargets;
  final List<String> interfaces; // Interfaces assigned to this VRF
  @override
  final bool enabled;

  const VrfInstance({
    required this.name,
    this.description,
    this.routeDistinguisher,
    this.routeTargets = const [],
    this.interfaces = const [],
    this.enabled = true,
  });

  @override
  String get identifier => 'vrf_$name';

  factory VrfInstance.fromJson(Map<String, dynamic> json) {
    return VrfInstance(
      name: json['name'] ?? '',
      description: json['description'],
      routeDistinguisher: json['route_distinguisher'],
      routeTargets:
          (json['route_targets'] as List<dynamic>?)
              ?.map((rt) => VrfRouteTarget.fromJson(rt))
              .toList() ??
          [],
      interfaces:
          (json['interfaces'] as List<dynamic>?)
              ?.map((i) => i.toString())
              .toList() ??
          [],
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    if (routeDistinguisher != null) 'route_distinguisher': routeDistinguisher,
    'route_targets': routeTargets.map((rt) => rt.toJson()).toList(),
    'interfaces': interfaces,
    'enabled': enabled,
  };

  @override
  VrfInstance copyWith({
    String? name,
    String? description,
    String? routeDistinguisher,
    List<VrfRouteTarget>? routeTargets,
    List<String>? interfaces,
    bool? enabled,
  }) => VrfInstance(
    name: name ?? this.name,
    description: description ?? this.description,
    routeDistinguisher: routeDistinguisher ?? this.routeDistinguisher,
    routeTargets: routeTargets ?? this.routeTargets,
    interfaces: interfaces ?? this.interfaces,
    enabled: enabled ?? this.enabled,
  );

  @override
  VrfInstance merge(VrfInstance other) => copyWith(
    name: other.name,
    description: other.description,
    routeDistinguisher: other.routeDistinguisher,
    routeTargets: other.routeTargets,
    interfaces: other.interfaces,
    enabled: other.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VrfInstance &&
          name == other.name &&
          description == other.description &&
          routeDistinguisher == other.routeDistinguisher &&
          listEquals(routeTargets, other.routeTargets) &&
          listEquals(interfaces, other.interfaces) &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    name,
    description,
    routeDistinguisher,
    Object.hashAll(routeTargets),
    Object.hashAll(interfaces),
    enabled,
  );
}

/// VRF configuration per device
class VrfConfig extends NetworkConfig<VrfConfig> {
  final int deviceId;
  final List<VrfInstance> vrfInstances;

  const VrfConfig({required this.deviceId, this.vrfInstances = const []});

  factory VrfConfig.fromJson(Map<String, dynamic> json) {
    return VrfConfig(
      deviceId: json['device_id'],
      vrfInstances:
          (json['vrf_instances'] as List<dynamic>?)
              ?.map((v) => VrfInstance.fromJson(v))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'vrf_instances': vrfInstances.map((v) => v.toJson()).toList(),
  };

  @override
  VrfConfig copyWith({int? deviceId, List<VrfInstance>? vrfInstances}) =>
      VrfConfig(
        deviceId: deviceId ?? this.deviceId,
        vrfInstances: vrfInstances ?? this.vrfInstances,
      );

  @override
  VrfConfig merge(VrfConfig other) =>
      copyWith(deviceId: other.deviceId, vrfInstances: other.vrfInstances);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VrfConfig &&
          deviceId == other.deviceId &&
          listEquals(vrfInstances, other.vrfInstances);

  @override
  int get hashCode => Object.hash(deviceId, Object.hashAll(vrfInstances));
}

// ============================================================================
// Switch Stacking Configuration
// ============================================================================

/// Stack member switch configuration
class StackMember extends NetworkConfig<StackMember> with EnableableMixin {
  final int deviceId;
  final int stackMemberNumber; // 1-8 typically
  final int priority; // 1-15, higher = more likely to be master
  final bool isMaster;
  @override
  final bool enabled;

  const StackMember({
    required this.deviceId,
    required this.stackMemberNumber,
    this.priority = 1,
    this.isMaster = false,
    this.enabled = true,
  });

  factory StackMember.fromJson(Map<String, dynamic> json) {
    return StackMember(
      deviceId: json['device_id'],
      stackMemberNumber: json['stack_member_number'] ?? 1,
      priority: json['priority'] ?? 1,
      isMaster: json['is_master'] ?? false,
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'stack_member_number': stackMemberNumber,
    'priority': priority,
    'is_master': isMaster,
    'enabled': enabled,
  };

  @override
  StackMember copyWith({
    int? deviceId,
    int? stackMemberNumber,
    int? priority,
    bool? isMaster,
    bool? enabled,
  }) => StackMember(
    deviceId: deviceId ?? this.deviceId,
    stackMemberNumber: stackMemberNumber ?? this.stackMemberNumber,
    priority: priority ?? this.priority,
    isMaster: isMaster ?? this.isMaster,
    enabled: enabled ?? this.enabled,
  );

  @override
  StackMember merge(StackMember other) => copyWith(
    deviceId: other.deviceId,
    stackMemberNumber: other.stackMemberNumber,
    priority: other.priority,
    isMaster: other.isMaster,
    enabled: other.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StackMember &&
          deviceId == other.deviceId &&
          stackMemberNumber == other.stackMemberNumber &&
          priority == other.priority &&
          isMaster == other.isMaster &&
          enabled == other.enabled;

  @override
  int get hashCode =>
      Object.hash(deviceId, stackMemberNumber, priority, isMaster, enabled);
}

/// Switch stack configuration
class SwitchStack extends NetworkConfig<SwitchStack>
    with EnableableMixin, IdentifiableMixin {
  final String name;
  final List<StackMember> members;
  final String? macAddress; // Virtual MAC for the stack
  @override
  final bool enabled;

  const SwitchStack({
    required this.name,
    this.members = const [],
    this.macAddress,
    this.enabled = true,
  });

  @override
  String get identifier => 'stack_$name';

  factory SwitchStack.fromJson(Map<String, dynamic> json) {
    return SwitchStack(
      name: json['name'] ?? 'Stack1',
      members:
          (json['members'] as List<dynamic>?)
              ?.map((m) => StackMember.fromJson(m))
              .toList() ??
          [],
      macAddress: json['mac_address'],
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'name': name,
    'members': members.map((m) => m.toJson()).toList(),
    if (macAddress != null) 'mac_address': macAddress,
    'enabled': enabled,
  };

  @override
  SwitchStack copyWith({
    String? name,
    List<StackMember>? members,
    String? macAddress,
    bool? enabled,
  }) => SwitchStack(
    name: name ?? this.name,
    members: members ?? this.members,
    macAddress: macAddress ?? this.macAddress,
    enabled: enabled ?? this.enabled,
  );

  @override
  SwitchStack merge(SwitchStack other) => copyWith(
    name: other.name,
    members: other.members,
    macAddress: other.macAddress,
    enabled: other.enabled,
  );

  StackMember? getMaster() {
    for (final member in members) {
      if (member.isMaster) return member;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SwitchStack &&
          name == other.name &&
          listEquals(members, other.members) &&
          macAddress == other.macAddress &&
          enabled == other.enabled;

  @override
  int get hashCode =>
      Object.hash(name, Object.hashAll(members), macAddress, enabled);
}

// ============================================================================
// Static Routing
// ============================================================================

/// Static route configuration
class StaticRoute extends NetworkConfig<StaticRoute> with EnableableMixin {
  final int deviceId;
  final String destinationNetwork; // e.g., "0.0.0.0/0" or "192.168.0.0/16"
  final String? nextHop; // Next hop IP
  final String? exitInterface; // Exit interface name
  final int? adminDistance;
  final String? name; // Route name/tag
  @override
  final bool enabled;

  const StaticRoute({
    required this.deviceId,
    required this.destinationNetwork,
    this.nextHop,
    this.exitInterface,
    this.adminDistance,
    this.name,
    this.enabled = true,
  });

  factory StaticRoute.fromJson(Map<String, dynamic> json) {
    return StaticRoute(
      deviceId: json['device_id'],
      destinationNetwork: json['destination_network'] ?? '',
      nextHop: json['next_hop'],
      exitInterface: json['exit_interface'],
      adminDistance: json['admin_distance'],
      name: json['name'],
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'destination_network': destinationNetwork,
    if (nextHop != null) 'next_hop': nextHop,
    if (exitInterface != null) 'exit_interface': exitInterface,
    if (adminDistance != null) 'admin_distance': adminDistance,
    if (name != null) 'name': name,
    'enabled': enabled,
  };

  @override
  StaticRoute copyWith({
    int? deviceId,
    String? destinationNetwork,
    String? nextHop,
    String? exitInterface,
    int? adminDistance,
    String? name,
    bool? enabled,
  }) => StaticRoute(
    deviceId: deviceId ?? this.deviceId,
    destinationNetwork: destinationNetwork ?? this.destinationNetwork,
    nextHop: nextHop ?? this.nextHop,
    exitInterface: exitInterface ?? this.exitInterface,
    adminDistance: adminDistance ?? this.adminDistance,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
  );

  @override
  StaticRoute merge(StaticRoute other) => copyWith(
    deviceId: other.deviceId,
    destinationNetwork: other.destinationNetwork,
    nextHop: other.nextHop,
    exitInterface: other.exitInterface,
    adminDistance: other.adminDistance,
    name: other.name,
    enabled: other.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaticRoute &&
          deviceId == other.deviceId &&
          destinationNetwork == other.destinationNetwork &&
          nextHop == other.nextHop &&
          exitInterface == other.exitInterface &&
          adminDistance == other.adminDistance &&
          name == other.name &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    deviceId,
    destinationNetwork,
    nextHop,
    exitInterface,
    adminDistance,
    name,
    enabled,
  );
}

// ============================================================================
// Spanning Tree Configuration
// ============================================================================

enum SpanningTreeMode { pvstPlus, rapidPvst, mst }

/// Spanning Tree domain configuration
class SpanningTreeDomain extends NetworkConfig<SpanningTreeDomain>
    with EnableableMixin, IdentifiableMixin {
  final SpanningTreeMode mode;
  final List<SpanningTreeVlanConfig> vlanConfigs;
  final List<SpanningTreeMember> members;
  @override
  final bool enabled;

  const SpanningTreeDomain({
    this.mode = SpanningTreeMode.rapidPvst,
    this.vlanConfigs = const [],
    this.members = const [],
    this.enabled = true,
  });

  @override
  String get identifier => 'stp_${mode.name}';

  factory SpanningTreeDomain.fromJson(Map<String, dynamic> json) {
    return SpanningTreeDomain(
      mode: SpanningTreeMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => SpanningTreeMode.rapidPvst,
      ),
      vlanConfigs:
          (json['vlan_configs'] as List<dynamic>?)
              ?.map((c) => SpanningTreeVlanConfig.fromJson(c))
              .toList() ??
          [],
      members:
          (json['members'] as List<dynamic>?)
              ?.map((m) => SpanningTreeMember.fromJson(m))
              .toList() ??
          [],
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'vlan_configs': vlanConfigs.map((c) => c.toJson()).toList(),
    'members': members.map((m) => m.toJson()).toList(),
    'enabled': enabled,
  };

  @override
  SpanningTreeDomain copyWith({
    SpanningTreeMode? mode,
    List<SpanningTreeVlanConfig>? vlanConfigs,
    List<SpanningTreeMember>? members,
    bool? enabled,
  }) => SpanningTreeDomain(
    mode: mode ?? this.mode,
    vlanConfigs: vlanConfigs ?? this.vlanConfigs,
    members: members ?? this.members,
    enabled: enabled ?? this.enabled,
  );

  @override
  SpanningTreeDomain merge(SpanningTreeDomain other) => copyWith(
    mode: other.mode,
    vlanConfigs: other.vlanConfigs,
    members: other.members,
    enabled: other.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpanningTreeDomain &&
          mode == other.mode &&
          listEquals(vlanConfigs, other.vlanConfigs) &&
          listEquals(members, other.members) &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    mode,
    Object.hashAll(vlanConfigs),
    Object.hashAll(members),
    enabled,
  );
}

/// Spanning Tree per-VLAN configuration
class SpanningTreeVlanConfig extends NetworkConfig<SpanningTreeVlanConfig> {
  final int vlanId;
  final int? priority; // Bridge priority (multiple of 4096)
  final int? rootDeviceId; // Intended root bridge device

  const SpanningTreeVlanConfig({
    required this.vlanId,
    this.priority,
    this.rootDeviceId,
  });

  factory SpanningTreeVlanConfig.fromJson(Map<String, dynamic> json) {
    return SpanningTreeVlanConfig(
      vlanId: json['vlan_id'] ?? 1,
      priority: json['priority'],
      rootDeviceId: json['root_device_id'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'vlan_id': vlanId,
    if (priority != null) 'priority': priority,
    if (rootDeviceId != null) 'root_device_id': rootDeviceId,
  };

  @override
  SpanningTreeVlanConfig copyWith({
    int? vlanId,
    int? priority,
    int? rootDeviceId,
  }) => SpanningTreeVlanConfig(
    vlanId: vlanId ?? this.vlanId,
    priority: priority ?? this.priority,
    rootDeviceId: rootDeviceId ?? this.rootDeviceId,
  );

  @override
  SpanningTreeVlanConfig merge(SpanningTreeVlanConfig other) => copyWith(
    vlanId: other.vlanId,
    priority: other.priority,
    rootDeviceId: other.rootDeviceId,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpanningTreeVlanConfig &&
          vlanId == other.vlanId &&
          priority == other.priority &&
          rootDeviceId == other.rootDeviceId;

  @override
  int get hashCode => Object.hash(vlanId, priority, rootDeviceId);
}

/// Spanning Tree member (per-device settings)
class SpanningTreeMember extends NetworkConfig<SpanningTreeMember> {
  final int deviceId;
  final Map<int, int> vlanPriorities; // vlanId -> priority
  final bool bpduGuardDefault;
  final bool portfastDefault;

  const SpanningTreeMember({
    required this.deviceId,
    this.vlanPriorities = const {},
    this.bpduGuardDefault = false,
    this.portfastDefault = false,
  });

  factory SpanningTreeMember.fromJson(Map<String, dynamic> json) {
    return SpanningTreeMember(
      deviceId: json['device_id'],
      vlanPriorities:
          (json['vlan_priorities'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(int.parse(k), v as int),
          ) ??
          {},
      bpduGuardDefault: json['bpdu_guard_default'] ?? false,
      portfastDefault: json['portfast_default'] ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'vlan_priorities': vlanPriorities.map((k, v) => MapEntry(k.toString(), v)),
    'bpdu_guard_default': bpduGuardDefault,
    'portfast_default': portfastDefault,
  };

  @override
  SpanningTreeMember copyWith({
    int? deviceId,
    Map<int, int>? vlanPriorities,
    bool? bpduGuardDefault,
    bool? portfastDefault,
  }) => SpanningTreeMember(
    deviceId: deviceId ?? this.deviceId,
    vlanPriorities: vlanPriorities ?? this.vlanPriorities,
    bpduGuardDefault: bpduGuardDefault ?? this.bpduGuardDefault,
    portfastDefault: portfastDefault ?? this.portfastDefault,
  );

  @override
  SpanningTreeMember merge(SpanningTreeMember other) => copyWith(
    deviceId: other.deviceId,
    vlanPriorities: other.vlanPriorities,
    bpduGuardDefault: other.bpduGuardDefault,
    portfastDefault: other.portfastDefault,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpanningTreeMember &&
          deviceId == other.deviceId &&
          mapEquals(vlanPriorities, other.vlanPriorities) &&
          bpduGuardDefault == other.bpduGuardDefault &&
          portfastDefault == other.portfastDefault;

  @override
  int get hashCode => Object.hash(
    deviceId,
    Object.hashAll(vlanPriorities.entries),
    bpduGuardDefault,
    portfastDefault,
  );
}

// ============================================================================
// VTP Configuration
// ============================================================================

enum VtpMode { server, client, transparent, off }

enum VtpVersion { v1, v2, v3 }

/// VTP domain configuration
class VtpDomain extends NetworkConfig<VtpDomain>
    with EnableableMixin, IdentifiableMixin {
  final String domainName;
  final VtpVersion version;
  final String? password;
  final List<VtpMember> members;
  @override
  final bool enabled;

  const VtpDomain({
    required this.domainName,
    this.version = VtpVersion.v2,
    this.password,
    this.members = const [],
    this.enabled = true,
  });

  @override
  String get identifier => 'vtp_$domainName';

  factory VtpDomain.fromJson(Map<String, dynamic> json) {
    return VtpDomain(
      domainName: json['domain_name'] ?? '',
      version: VtpVersion.values.firstWhere(
        (e) => e.name == json['version'],
        orElse: () => VtpVersion.v2,
      ),
      password: json['password'],
      members:
          (json['members'] as List<dynamic>?)
              ?.map((m) => VtpMember.fromJson(m))
              .toList() ??
          [],
      enabled: json['enabled'] ?? true,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'domain_name': domainName,
    'version': version.name,
    if (password != null) 'password': password,
    'members': members.map((m) => m.toJson()).toList(),
    'enabled': enabled,
  };

  @override
  VtpDomain copyWith({
    String? domainName,
    VtpVersion? version,
    String? password,
    List<VtpMember>? members,
    bool? enabled,
  }) => VtpDomain(
    domainName: domainName ?? this.domainName,
    version: version ?? this.version,
    password: password ?? this.password,
    members: members ?? this.members,
    enabled: enabled ?? this.enabled,
  );

  @override
  VtpDomain merge(VtpDomain other) => copyWith(
    domainName: other.domainName,
    version: other.version,
    password: other.password,
    members: other.members,
    enabled: other.enabled,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VtpDomain &&
          domainName == other.domainName &&
          version == other.version &&
          password == other.password &&
          listEquals(members, other.members) &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    domainName,
    version,
    password,
    Object.hashAll(members),
    enabled,
  );
}

/// VTP member configuration
class VtpMember extends NetworkConfig<VtpMember> {
  final int deviceId;
  final VtpMode mode;
  final bool pruning;

  const VtpMember({
    required this.deviceId,
    this.mode = VtpMode.client,
    this.pruning = false,
  });

  factory VtpMember.fromJson(Map<String, dynamic> json) {
    return VtpMember(
      deviceId: json['device_id'],
      mode: VtpMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => VtpMode.client,
      ),
      pruning: json['pruning'] ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'mode': mode.name,
    'pruning': pruning,
  };

  @override
  VtpMember copyWith({int? deviceId, VtpMode? mode, bool? pruning}) =>
      VtpMember(
        deviceId: deviceId ?? this.deviceId,
        mode: mode ?? this.mode,
        pruning: pruning ?? this.pruning,
      );

  @override
  VtpMember merge(VtpMember other) => copyWith(
    deviceId: other.deviceId,
    mode: other.mode,
    pruning: other.pruning,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VtpMember &&
          deviceId == other.deviceId &&
          mode == other.mode &&
          pruning == other.pruning;

  @override
  int get hashCode => Object.hash(deviceId, mode, pruning);
}

// ============================================================================
// Topology Data - Device Positions and Connections
// ============================================================================

/// A connection between two device ports in the topology
/// Types of virtual devices that can be placed on topology
enum VirtualDeviceType { pc, server, cloud, phone }

/// A virtual device on the topology (e.g., PC, Server)
/// These are not real network devices but can be connected to show endpoints
class VirtualDevice {
  final String id; // Unique identifier (UUID)
  final VirtualDeviceType type;
  final String name;
  final String? ipAddress;
  final String? macAddress;
  final double x;
  final double y;

  const VirtualDevice({
    required this.id,
    required this.type,
    required this.name,
    this.ipAddress,
    this.macAddress,
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    if (ipAddress != null) 'ip_address': ipAddress,
    if (macAddress != null) 'mac_address': macAddress,
    'x': x,
    'y': y,
  };

  factory VirtualDevice.fromJson(Map<String, dynamic> json) {
    return VirtualDevice(
      id: json['id'],
      type: VirtualDeviceType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => VirtualDeviceType.pc,
      ),
      name: json['name'] ?? 'Device',
      ipAddress: json['ip_address'],
      macAddress: json['mac_address'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  VirtualDevice copyWith({
    String? id,
    VirtualDeviceType? type,
    String? name,
    String? ipAddress,
    bool clearIpAddress = false,
    String? macAddress,
    bool clearMacAddress = false,
    double? x,
    double? y,
  }) => VirtualDevice(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    ipAddress: clearIpAddress ? null : (ipAddress ?? this.ipAddress),
    macAddress: clearMacAddress ? null : (macAddress ?? this.macAddress),
    x: x ?? this.x,
    y: y ?? this.y,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VirtualDevice &&
          id == other.id &&
          type == other.type &&
          name == other.name &&
          ipAddress == other.ipAddress &&
          macAddress == other.macAddress &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(id, type, name, ipAddress, macAddress, x, y);
}

/// Connection involving a virtual device
class VirtualConnection {
  final String virtualDeviceId;
  final int realDeviceId;
  final String realDevicePort;

  const VirtualConnection({
    required this.virtualDeviceId,
    required this.realDeviceId,
    required this.realDevicePort,
  });

  Map<String, dynamic> toJson() => {
    'virtual_device_id': virtualDeviceId,
    'real_device_id': realDeviceId,
    'real_device_port': realDevicePort,
  };

  factory VirtualConnection.fromJson(Map<String, dynamic> json) {
    return VirtualConnection(
      virtualDeviceId: json['virtual_device_id'],
      realDeviceId: json['real_device_id'],
      realDevicePort: json['real_device_port'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VirtualConnection &&
          virtualDeviceId == other.virtualDeviceId &&
          realDeviceId == other.realDeviceId &&
          realDevicePort == other.realDevicePort;

  @override
  int get hashCode =>
      Object.hash(virtualDeviceId, realDeviceId, realDevicePort);
}

class TopologyConnection {
  final int sourceDeviceId;
  final String sourcePort;
  final int targetDeviceId;
  final String targetPort;

  const TopologyConnection({
    required this.sourceDeviceId,
    required this.sourcePort,
    required this.targetDeviceId,
    required this.targetPort,
  });

  Map<String, dynamic> toJson() => {
    'source_device_id': sourceDeviceId,
    'source_port': sourcePort,
    'target_device_id': targetDeviceId,
    'target_port': targetPort,
  };

  factory TopologyConnection.fromJson(Map<String, dynamic> json) {
    return TopologyConnection(
      sourceDeviceId: json['source_device_id'],
      sourcePort: json['source_port'],
      targetDeviceId: json['target_device_id'],
      targetPort: json['target_port'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopologyConnection &&
          sourceDeviceId == other.sourceDeviceId &&
          sourcePort == other.sourcePort &&
          targetDeviceId == other.targetDeviceId &&
          targetPort == other.targetPort;

  @override
  int get hashCode =>
      Object.hash(sourceDeviceId, sourcePort, targetDeviceId, targetPort);
}

/// Position of a device on the topology canvas
class TopologyPosition {
  final int deviceId;
  final double x;
  final double y;

  const TopologyPosition({
    required this.deviceId,
    required this.x,
    required this.y,
  });

  Map<String, dynamic> toJson() => {'device_id': deviceId, 'x': x, 'y': y};

  factory TopologyPosition.fromJson(Map<String, dynamic> json) {
    return TopologyPosition(
      deviceId: json['device_id'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  TopologyPosition copyWith({double? x, double? y}) =>
      TopologyPosition(deviceId: deviceId, x: x ?? this.x, y: y ?? this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopologyPosition &&
          deviceId == other.deviceId &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(deviceId, x, y);
}

/// Topology data storing device positions and connections
class TopologyData extends NetworkConfig<TopologyData> {
  final List<TopologyPosition> positions;
  final List<TopologyConnection> connections;
  final List<VirtualDevice> virtualDevices;
  final List<VirtualConnection> virtualConnections;

  const TopologyData({
    this.positions = const [],
    this.connections = const [],
    this.virtualDevices = const [],
    this.virtualConnections = const [],
  });

  @override
  Map<String, dynamic> toJson() => {
    'positions': positions.map((p) => p.toJson()).toList(),
    'connections': connections.map((c) => c.toJson()).toList(),
    'virtual_devices': virtualDevices.map((v) => v.toJson()).toList(),
    'virtual_connections': virtualConnections.map((v) => v.toJson()).toList(),
  };

  factory TopologyData.fromJson(Map<String, dynamic> json) {
    return TopologyData(
      positions:
          (json['positions'] as List<dynamic>?)
              ?.map((p) => TopologyPosition.fromJson(p))
              .toList() ??
          [],
      connections:
          (json['connections'] as List<dynamic>?)
              ?.map((c) => TopologyConnection.fromJson(c))
              .toList() ??
          [],
      virtualDevices:
          (json['virtual_devices'] as List<dynamic>?)
              ?.map((v) => VirtualDevice.fromJson(v))
              .toList() ??
          [],
      virtualConnections:
          (json['virtual_connections'] as List<dynamic>?)
              ?.map((v) => VirtualConnection.fromJson(v))
              .toList() ??
          [],
    );
  }

  @override
  TopologyData copyWith({
    List<TopologyPosition>? positions,
    List<TopologyConnection>? connections,
    List<VirtualDevice>? virtualDevices,
    List<VirtualConnection>? virtualConnections,
  }) => TopologyData(
    positions: positions ?? this.positions,
    connections: connections ?? this.connections,
    virtualDevices: virtualDevices ?? this.virtualDevices,
    virtualConnections: virtualConnections ?? this.virtualConnections,
  );

  @override
  TopologyData merge(TopologyData other) => copyWith(
    positions: other.positions.isNotEmpty ? other.positions : positions,
    connections: other.connections.isNotEmpty ? other.connections : connections,
    virtualDevices: other.virtualDevices.isNotEmpty
        ? other.virtualDevices
        : virtualDevices,
    virtualConnections: other.virtualConnections.isNotEmpty
        ? other.virtualConnections
        : virtualConnections,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopologyData &&
          listEquals(positions, other.positions) &&
          listEquals(connections, other.connections) &&
          listEquals(virtualDevices, other.virtualDevices) &&
          listEquals(virtualConnections, other.virtualConnections);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(positions),
    Object.hashAll(connections),
    Object.hashAll(virtualDevices),
    Object.hashAll(virtualConnections),
  );
}

// ============================================================================
// Project Properties - Root Container
// ============================================================================

/// Root container for all project-level network service configurations.
/// Stored in the `properties` JSONB column of `projects_v2` table.
class ProjectProperties extends NetworkConfig<ProjectProperties> {
  // First Hop Redundancy
  final List<HsrpGroup> hsrpGroups;

  // Routing
  final List<OspfDomain> ospfDomains;
  final List<EigrpDomain> eigrpDomains;
  final List<BgpDomain> bgpDomains;
  final List<StaticRoute> staticRoutes;

  // VRF
  final List<VrfConfig> vrfConfigs;

  // Layer 2
  final SpanningTreeDomain? spanningTree;
  final VtpDomain? vtpDomain;

  // Stacking
  final List<SwitchStack> switchStacks;

  // Topology
  final TopologyData? topology;

  const ProjectProperties({
    this.hsrpGroups = const [],
    this.ospfDomains = const [],
    this.eigrpDomains = const [],
    this.bgpDomains = const [],
    this.staticRoutes = const [],
    this.vrfConfigs = const [],
    this.spanningTree,
    this.vtpDomain,
    this.switchStacks = const [],
    this.topology,
  });

  factory ProjectProperties.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProjectProperties();

    return ProjectProperties(
      hsrpGroups:
          (json['hsrp_groups'] as List<dynamic>?)
              ?.map((g) => HsrpGroup.fromJson(g))
              .toList() ??
          [],
      ospfDomains:
          (json['ospf_domains'] as List<dynamic>?)
              ?.map((d) => OspfDomain.fromJson(d))
              .toList() ??
          [],
      eigrpDomains:
          (json['eigrp_domains'] as List<dynamic>?)
              ?.map((d) => EigrpDomain.fromJson(d))
              .toList() ??
          [],
      bgpDomains:
          (json['bgp_domains'] as List<dynamic>?)
              ?.map((d) => BgpDomain.fromJson(d))
              .toList() ??
          [],
      staticRoutes:
          (json['static_routes'] as List<dynamic>?)
              ?.map((r) => StaticRoute.fromJson(r))
              .toList() ??
          [],
      vrfConfigs:
          (json['vrf_configs'] as List<dynamic>?)
              ?.map((v) => VrfConfig.fromJson(v))
              .toList() ??
          [],
      spanningTree: json['spanning_tree'] != null
          ? SpanningTreeDomain.fromJson(json['spanning_tree'])
          : null,
      vtpDomain: json['vtp_domain'] != null
          ? VtpDomain.fromJson(json['vtp_domain'])
          : null,
      switchStacks:
          (json['switch_stacks'] as List<dynamic>?)
              ?.map((s) => SwitchStack.fromJson(s))
              .toList() ??
          [],
      topology: json['topology'] != null
          ? TopologyData.fromJson(json['topology'])
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'hsrp_groups': hsrpGroups.map((g) => g.toJson()).toList(),
    'ospf_domains': ospfDomains.map((d) => d.toJson()).toList(),
    'eigrp_domains': eigrpDomains.map((d) => d.toJson()).toList(),
    'bgp_domains': bgpDomains.map((d) => d.toJson()).toList(),
    'static_routes': staticRoutes.map((r) => r.toJson()).toList(),
    'vrf_configs': vrfConfigs.map((v) => v.toJson()).toList(),
    if (spanningTree != null) 'spanning_tree': spanningTree!.toJson(),
    if (vtpDomain != null) 'vtp_domain': vtpDomain!.toJson(),
    'switch_stacks': switchStacks.map((s) => s.toJson()).toList(),
    if (topology != null) 'topology': topology!.toJson(),
  };

  @override
  ProjectProperties copyWith({
    List<HsrpGroup>? hsrpGroups,
    List<OspfDomain>? ospfDomains,
    List<EigrpDomain>? eigrpDomains,
    List<BgpDomain>? bgpDomains,
    List<StaticRoute>? staticRoutes,
    List<VrfConfig>? vrfConfigs,
    SpanningTreeDomain? spanningTree,
    VtpDomain? vtpDomain,
    List<SwitchStack>? switchStacks,
    TopologyData? topology,
  }) => ProjectProperties(
    hsrpGroups: hsrpGroups ?? this.hsrpGroups,
    ospfDomains: ospfDomains ?? this.ospfDomains,
    eigrpDomains: eigrpDomains ?? this.eigrpDomains,
    bgpDomains: bgpDomains ?? this.bgpDomains,
    staticRoutes: staticRoutes ?? this.staticRoutes,
    vrfConfigs: vrfConfigs ?? this.vrfConfigs,
    spanningTree: spanningTree ?? this.spanningTree,
    vtpDomain: vtpDomain ?? this.vtpDomain,
    switchStacks: switchStacks ?? this.switchStacks,
    topology: topology ?? this.topology,
  );

  @override
  ProjectProperties merge(ProjectProperties other) => copyWith(
    hsrpGroups: other.hsrpGroups.isNotEmpty ? other.hsrpGroups : hsrpGroups,
    ospfDomains: other.ospfDomains.isNotEmpty ? other.ospfDomains : ospfDomains,
    eigrpDomains: other.eigrpDomains.isNotEmpty
        ? other.eigrpDomains
        : eigrpDomains,
    bgpDomains: other.bgpDomains.isNotEmpty ? other.bgpDomains : bgpDomains,
    staticRoutes: other.staticRoutes.isNotEmpty
        ? other.staticRoutes
        : staticRoutes,
    vrfConfigs: other.vrfConfigs.isNotEmpty ? other.vrfConfigs : vrfConfigs,
    spanningTree: other.spanningTree ?? spanningTree,
    vtpDomain: other.vtpDomain ?? vtpDomain,
    switchStacks: other.switchStacks.isNotEmpty
        ? other.switchStacks
        : switchStacks,
    topology: other.topology ?? topology,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectProperties &&
          listEquals(hsrpGroups, other.hsrpGroups) &&
          listEquals(ospfDomains, other.ospfDomains) &&
          listEquals(eigrpDomains, other.eigrpDomains) &&
          listEquals(bgpDomains, other.bgpDomains) &&
          listEquals(staticRoutes, other.staticRoutes) &&
          listEquals(vrfConfigs, other.vrfConfigs) &&
          spanningTree == other.spanningTree &&
          vtpDomain == other.vtpDomain &&
          listEquals(switchStacks, other.switchStacks) &&
          topology == other.topology;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(hsrpGroups),
    Object.hashAll(ospfDomains),
    Object.hashAll(eigrpDomains),
    Object.hashAll(bgpDomains),
    Object.hashAll(staticRoutes),
    Object.hashAll(vrfConfigs),
    spanningTree,
    vtpDomain,
    Object.hashAll(switchStacks),
    topology,
  );

  /// Check if any services are configured
  bool get isEmpty =>
      hsrpGroups.isEmpty &&
      ospfDomains.isEmpty &&
      eigrpDomains.isEmpty &&
      bgpDomains.isEmpty &&
      staticRoutes.isEmpty &&
      vrfConfigs.isEmpty &&
      spanningTree == null &&
      vtpDomain == null &&
      switchStacks.isEmpty;

  bool get isNotEmpty => !isEmpty;
}
