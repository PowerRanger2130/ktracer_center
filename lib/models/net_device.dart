import 'dart:ui';

import 'package:ktracer_center/devices/device_preset.dart';
import 'package:ktracer_center/devices/lab_inventory.dart';
import 'package:ktracer_center/devices/switchport.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/ipv6.dart';
import 'package:ktracer_center/network/port.dart';

/// Sentinel value for copyWith methods to distinguish between "not provided" and "null"
const Object _undefined = Object();

/// A device configuration within a project.
/// References a preset and stores all config in a single JSONB field.
class NetDevice {
  int id;
  final int projectId;
  final int presetId;
  int? realId; // Assigned physical device (null if not yet allocated)

  /// All configuration stored in JSONB
  Map<String, dynamic> config;

  NetDevice({
    required this.id,
    required this.projectId,
    required this.presetId,
    this.realId,
    Map<String, dynamic>? config,
  }) : config = config ?? {};

  // ---- Preset-derived properties ----

  DevicePreset get preset => DevicePresets.getById(presetId);
  LabDevice? get labDevice =>
      realId != null ? LabInventory.getByRealId(realId!) : null;

  String get sku => preset.sku;
  String get name => preset.name;
  NetDeviceCategory get category => preset.category;
  Color? get color => preset.color;
  bool get hasSsh => preset.hasSsh;

  // ---- Config accessors ----

  String get hostname =>
      config['hostname'] ?? labDevice?.defaultHostname ?? 'Device';
  set hostname(String value) => config['hostname'] = value;

  String? get description => config['description'];
  set description(String? value) => config['description'] = value;

  bool get domainLookup => config['domain_lookup'] ?? true;
  set domainLookup(bool value) => config['domain_lookup'] = value;

  String? get defaultGatewayIpv4 {
    final value = config['default_gateway_ipv4'];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  set defaultGatewayIpv4(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      config.remove('default_gateway_ipv4');
      return;
    }
    config['default_gateway_ipv4'] = trimmed;
  }

  /// Device group name for organizing devices in the navigation
  String? get deviceGroup => config['device_group'];
  set deviceGroup(String? value) => config['device_group'] = value;

  /// Sort order for devices within a group (lower numbers appear first)
  int get sortOrder => config['sort_order'] ?? 0;
  set sortOrder(int value) => config['sort_order'] = value;

  /// Get ports from config, or default ports from preset.
  /// Config can store ports as either:
  /// - List: Full port definitions
  /// - Map: Sparse overrides keyed by port index (e.g., {"0": {...}, "5": {...}})
  List<Port> get interfaces {
    final interfacesData = config['ports'];
    final defaultInterfaces = preset.defaultInterfaces();

    if (interfacesData == null) {
      return defaultInterfaces;
    }

    // Handle List format - full port definitions
    if (interfacesData is List) {
      return interfacesData.map((p) => _portFromJson(p)).toList();
    }

    // Handle Map format - sparse overrides merged with defaults
    if (interfacesData is Map<String, dynamic>) {
      return List.generate(defaultInterfaces.length, (index) {
        final override = interfacesData['$index'];
        if (override != null && override is Map<String, dynamic>) {
          // Merge default port data with overrides
          final defaultJson = _portToJson(defaultInterfaces[index]);
          final mergedJson = {...defaultJson, ...override};
          return _portFromJson(mergedJson);
        }
        return defaultInterfaces[index];
      });
    }

    return defaultInterfaces;
  }

  set interfaces(List<Port> value) {
    config['ports'] = value.map((p) => _portToJson(p)).toList();
  }

  /// Get VLANs from config, or default from preset
  List<VlanConfig> get vlans {
    final vlansList = config['vlans'] as List<dynamic>?;
    if (vlansList == null) {
      final defaultConfig = preset.defaultConfig();
      final defaultVlans = defaultConfig['vlans'] as List<dynamic>?;
      if (defaultVlans != null) {
        return defaultVlans.map((v) => VlanConfig.fromJson(v)).toList();
      }
      return [VlanConfig(vlanId: 1, name: 'Default')];
    }
    return vlansList.map((v) => VlanConfig.fromJson(v)).toList();
  }

  set vlans(List<VlanConfig> value) {
    config['vlans'] = value.map((v) => v.toJson()).toList();
  }

  /// Get channel groups from config
  List<ChannelGroupConfig> get channelGroups {
    final groupsList = config['channel_groups'] as List<dynamic>?;
    if (groupsList == null) return [];
    return groupsList.map((g) => ChannelGroupConfig.fromJson(g)).toList();
  }

  set channelGroups(List<ChannelGroupConfig> value) {
    config['channel_groups'] = value.map((g) => g.toJson()).toList();
  }

  /// Get DHCP pools from config
  List<DhcpPoolConfig> get dhcpPools {
    final poolsList = config['dhcp_pools'] as List<dynamic>?;
    if (poolsList == null) return [];
    return poolsList.map((p) => DhcpPoolConfig.fromJson(p)).toList();
  }

  set dhcpPools(List<DhcpPoolConfig> value) {
    config['dhcp_pools'] = value.map((p) => p.toJson()).toList();
  }

  /// Get ACLs from config
  List<AclConfig> get acls {
    final aclsList = config['acls'] as List<dynamic>?;
    if (aclsList == null) return [];
    return aclsList.map((a) => AclConfig.fromJson(a)).toList();
  }

  set acls(List<AclConfig> value) {
    config['acls'] = value.map((a) => a.toJson()).toList();
  }

  /// Get NAT rules from config
  List<NatRule> get natRules {
    final rulesList = config['nat_rules'] as List<dynamic>?;
    if (rulesList == null) return [];
    return rulesList.map((r) => NatRule.fromJson(r)).toList();
  }

  set natRules(List<NatRule> value) {
    config['nat_rules'] = value.map((r) => r.toJson()).toList();
  }

  /// Get tunnel configurations from config
  List<TunnelConfig> get tunnels {
    final tunnelsList = config['tunnels'] as List<dynamic>?;
    if (tunnelsList == null) return [];
    return tunnelsList.map((t) => TunnelConfig.fromJson(t)).toList();
  }

  set tunnels(List<TunnelConfig> value) {
    config['tunnels'] = value.map((t) => t.toJson()).toList();
  }

  /// Get static routes from config
  List<StaticRouteConfig> get staticRoutes {
    final routesList = config['static_routes'] as List<dynamic>?;
    if (routesList == null) return [];
    return routesList.map((r) => StaticRouteConfig.fromJson(r)).toList();
  }

  set staticRoutes(List<StaticRouteConfig> value) {
    config['static_routes'] = value.map((r) => r.toJson()).toList();
  }

  // ---- Serialization ----

  factory NetDevice.fromJson(Map<String, dynamic> json) {
    return NetDevice(
      id: json['id'],
      projectId: json['project_id'],
      presetId: json['preset_id'],
      // realId is not stored in DB - will be assigned during device locking
      config: json['config'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'preset_id': presetId,
      // realId is not stored in DB - will be assigned during device locking
      'config': config,
    };
  }

  /// Create insert data (without id)
  Map<String, dynamic> toInsertJson() {
    return {
      'project_id': projectId,
      'preset_id': presetId,
      // realId is not stored in DB - will be assigned during device locking
      'config': config,
    };
  }

  // ---- Port serialization helpers ----

  static Port _portFromJson(Map<String, dynamic> json) {
    final isSwitchport = json['is_switchport'] ?? false;
    if (isSwitchport) {
      return Switchport.fromJson(json);
    }
    return Port.fromJson(json);
  }

  static Map<String, dynamic> _portToJson(Port port) {
    return port.toJson();
  }
}

/// VLAN configuration stored in device config JSONB
class VlanConfig {
  int? id;
  final int vlanId;
  String name;
  String? description;
  bool enabled;
  IPv4? ipAddress;
  IPv6? ipv6Address;

  VlanConfig({
    this.id,
    required this.vlanId,
    required this.name,
    this.description,
    this.enabled = true,
    this.ipAddress,
    this.ipv6Address,
  });

  factory VlanConfig.fromJson(Map<String, dynamic> json) {
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

    // Support both 'vlan_id' and 'id' for VLAN ID (AI sometimes uses 'id')
    final vlanId = json['vlan_id'] as int? ?? json['id'] as int? ?? 1;

    return VlanConfig(
      id: json['id'] as int?,
      vlanId: vlanId,
      name: json['name'] as String? ?? 'VLAN $vlanId',
      description: json['description'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      ipAddress: ip,
      ipv6Address: ipv6,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'vlan_id': vlanId,
      'name': name,
      'description': description,
      'enabled': enabled,
      if (ipAddress != null) 'ip_cidr': ipAddress!.toCIDR(),
      if (ipv6Address != null) 'ipv6_cidr': ipv6Address!.toCIDR(),
    };
  }

  /// Creates a copy with the given fields replaced.
  ///
  /// To explicitly set a nullable field to null, pass [clearDescription] or
  /// [clearIpAddress] as true.
  VlanConfig copyWith({
    int? id,
    int? vlanId,
    String? name,
    Object? description = _undefined,
    bool? enabled,
    Object? ipAddress = _undefined,
    Object? ipv6Address = _undefined,
  }) {
    return VlanConfig(
      id: id ?? this.id,
      vlanId: vlanId ?? this.vlanId,
      name: name ?? this.name,
      description: description == _undefined
          ? this.description
          : description as String?,
      enabled: enabled ?? this.enabled,
      ipAddress: ipAddress == _undefined ? this.ipAddress : ipAddress as IPv4?,
      ipv6Address: ipv6Address == _undefined
          ? this.ipv6Address
          : ipv6Address as IPv6?,
    );
  }

  VlanConfig merge(VlanConfig other) {
    return VlanConfig(
      id: other.id ?? id,
      vlanId: other.vlanId,
      name: other.name,
      description: other.description ?? description,
      enabled: other.enabled,
      ipAddress: other.ipAddress ?? ipAddress,
      ipv6Address: other.ipv6Address ?? ipv6Address,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VlanConfig &&
          id == other.id &&
          vlanId == other.vlanId &&
          name == other.name &&
          description == other.description &&
          enabled == other.enabled &&
          ipAddress?.toCIDR() == other.ipAddress?.toCIDR() &&
          ipv6Address?.toCIDR() == other.ipv6Address?.toCIDR();

  @override
  int get hashCode => Object.hash(
    id,
    vlanId,
    name,
    description,
    enabled,
    ipAddress?.toCIDR(),
    ipv6Address?.toCIDR(),
  );
}

/// DHCP Pool configuration stored in device config JSONB
class DhcpPoolConfig {
  final String name;
  int? interfaceIndex; // Index of the interface (port) this pool is for
  int? vlanId; // VLAN ID if this pool is for an SVI
  String
  network; // Network address (e.g., "192.168.1.0") - derived from interface or manual
  String
  subnetMask; // Subnet mask (e.g., "255.255.255.0") - derived from interface or manual
  String? defaultRouter; // Default gateway
  String? dnsServer; // Primary DNS server
  String? dnsServerSecondary; // Secondary DNS server
  String? domainName; // Domain name for clients
  int leaseTime; // Lease time in seconds (default 86400 = 1 day)
  String? excludeStart; // Start of excluded range
  String? excludeEnd; // End of excluded range
  bool enabled;

  DhcpPoolConfig({
    required this.name,
    this.interfaceIndex,
    this.vlanId,
    required this.network,
    required this.subnetMask,
    this.defaultRouter,
    this.dnsServer,
    this.dnsServerSecondary,
    this.domainName,
    this.leaseTime = 86400,
    this.excludeStart,
    this.excludeEnd,
    this.enabled = true,
  });

  factory DhcpPoolConfig.fromJson(Map<String, dynamic> json) {
    return DhcpPoolConfig(
      name: json['name'] ?? 'Pool',
      interfaceIndex: json['interface_index'],
      vlanId: json['vlan_id'],
      network: json['network'] ?? '',
      subnetMask: json['subnet_mask'] ?? '255.255.255.0',
      defaultRouter: json['default_router'],
      dnsServer: json['dns_server'],
      dnsServerSecondary: json['dns_server_secondary'],
      domainName: json['domain_name'],
      leaseTime: json['lease_time'] ?? 86400,
      excludeStart: json['exclude_start'],
      excludeEnd: json['exclude_end'],
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (interfaceIndex != null) 'interface_index': interfaceIndex,
      if (vlanId != null) 'vlan_id': vlanId,
      'network': network,
      'subnet_mask': subnetMask,
      if (defaultRouter != null) 'default_router': defaultRouter,
      if (dnsServer != null) 'dns_server': dnsServer,
      if (dnsServerSecondary != null)
        'dns_server_secondary': dnsServerSecondary,
      if (domainName != null) 'domain_name': domainName,
      'lease_time': leaseTime,
      if (excludeStart != null) 'exclude_start': excludeStart,
      if (excludeEnd != null) 'exclude_end': excludeEnd,
      'enabled': enabled,
    };
  }

  /// Calculate the number of usable addresses in this pool
  int get usableAddresses {
    try {
      final networkParts = network.split('.').map(int.parse).toList();
      final maskParts = subnetMask.split('.').map(int.parse).toList();

      int networkInt = 0;
      int maskInt = 0;
      for (int i = 0; i < 4; i++) {
        networkInt = (networkInt << 8) | networkParts[i];
        maskInt = (maskInt << 8) | maskParts[i];
      }

      final hostBits = 32 - _countBits(maskInt);
      final totalHosts = (1 << hostBits) - 2; // Subtract network and broadcast

      // Account for exclusions
      if (excludeStart != null && excludeEnd != null) {
        final startParts = excludeStart!.split('.').map(int.parse).toList();
        final endParts = excludeEnd!.split('.').map(int.parse).toList();

        int startInt = 0;
        int endInt = 0;
        for (int i = 0; i < 4; i++) {
          startInt = (startInt << 8) | startParts[i];
          endInt = (endInt << 8) | endParts[i];
        }

        final excluded = endInt - startInt + 1;
        return totalHosts - excluded;
      }

      return totalHosts;
    } catch (_) {
      return 0;
    }
  }

  static int _countBits(int mask) {
    // Use unsigned 32-bit mask to avoid infinite loop with signed right shift
    int m = mask & 0xFFFFFFFF;
    int count = 0;
    for (int i = 0; i < 32; i++) {
      count += m & 1;
      m = m >>> 1; // Unsigned right shift
    }
    return count;
  }

  DhcpPoolConfig copyWith({
    String? name,
    int? interfaceIndex,
    int? vlanId,
    String? network,
    String? subnetMask,
    String? defaultRouter,
    String? dnsServer,
    String? dnsServerSecondary,
    String? domainName,
    int? leaseTime,
    String? excludeStart,
    String? excludeEnd,
    bool? enabled,
  }) {
    return DhcpPoolConfig(
      name: name ?? this.name,
      interfaceIndex: interfaceIndex ?? this.interfaceIndex,
      vlanId: vlanId ?? this.vlanId,
      network: network ?? this.network,
      subnetMask: subnetMask ?? this.subnetMask,
      defaultRouter: defaultRouter ?? this.defaultRouter,
      dnsServer: dnsServer ?? this.dnsServer,
      dnsServerSecondary: dnsServerSecondary ?? this.dnsServerSecondary,
      domainName: domainName ?? this.domainName,
      leaseTime: leaseTime ?? this.leaseTime,
      excludeStart: excludeStart ?? this.excludeStart,
      excludeEnd: excludeEnd ?? this.excludeEnd,
      enabled: enabled ?? this.enabled,
    );
  }

  DhcpPoolConfig merge(DhcpPoolConfig? other) {
    if (other == null) return this;
    return DhcpPoolConfig(
      name: other.name.isNotEmpty ? other.name : name,
      interfaceIndex: other.interfaceIndex ?? interfaceIndex,
      vlanId: other.vlanId ?? vlanId,
      network: other.network.isNotEmpty ? other.network : network,
      subnetMask: other.subnetMask.isNotEmpty ? other.subnetMask : subnetMask,
      defaultRouter: other.defaultRouter ?? defaultRouter,
      dnsServer: other.dnsServer ?? dnsServer,
      dnsServerSecondary: other.dnsServerSecondary ?? dnsServerSecondary,
      domainName: other.domainName ?? domainName,
      leaseTime: other.leaseTime,
      excludeStart: other.excludeStart ?? excludeStart,
      excludeEnd: other.excludeEnd ?? excludeEnd,
      enabled: other.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DhcpPoolConfig &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          interfaceIndex == other.interfaceIndex &&
          vlanId == other.vlanId &&
          network == other.network &&
          subnetMask == other.subnetMask &&
          defaultRouter == other.defaultRouter &&
          dnsServer == other.dnsServer &&
          dnsServerSecondary == other.dnsServerSecondary &&
          domainName == other.domainName &&
          leaseTime == other.leaseTime &&
          excludeStart == other.excludeStart &&
          excludeEnd == other.excludeEnd &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    name,
    interfaceIndex,
    vlanId,
    network,
    subnetMask,
    defaultRouter,
    dnsServer,
    dnsServerSecondary,
    domainName,
    leaseTime,
    excludeStart,
    excludeEnd,
    enabled,
  );
}

/// EtherChannel/Port-Channel mode
enum ChannelGroupMode { on, active, passive, desirable, auto }

/// Channel group (EtherChannel/Port-Channel) configuration
class ChannelGroupConfig {
  final int groupNumber;
  String name;
  ChannelGroupMode mode;
  List<int> portIndices; // Indices of ports in this channel group

  // Port-channel trunk settings (member ports inherit these)
  int nativeVlan;
  String allowedVlans; // "all" or comma-separated list like "1,10,20-30"

  ChannelGroupConfig({
    required this.groupNumber,
    String? name,
    this.mode = ChannelGroupMode.on,
    List<int>? portIndices,
    this.nativeVlan = 1,
    this.allowedVlans = 'all',
  }) : name = name ?? 'Port-channel$groupNumber',
       portIndices = portIndices ?? [];

  factory ChannelGroupConfig.fromJson(Map<String, dynamic> json) {
    return ChannelGroupConfig(
      groupNumber: json['group_number'],
      name: json['name'],
      mode: ChannelGroupMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => ChannelGroupMode.on,
      ),
      portIndices:
          (json['port_indices'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      nativeVlan: json['native_vlan'] ?? 1,
      allowedVlans: json['allowed_vlans'] ?? 'all',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_number': groupNumber,
      'name': name,
      'mode': mode.name,
      'port_indices': portIndices,
      'native_vlan': nativeVlan,
      'allowed_vlans': allowedVlans,
    };
  }

  ChannelGroupConfig copyWith({
    int? groupNumber,
    String? name,
    ChannelGroupMode? mode,
    List<int>? portIndices,
    int? nativeVlan,
    String? allowedVlans,
  }) {
    return ChannelGroupConfig(
      groupNumber: groupNumber ?? this.groupNumber,
      name: name ?? this.name,
      mode: mode ?? this.mode,
      portIndices: portIndices ?? List<int>.from(this.portIndices),
      nativeVlan: nativeVlan ?? this.nativeVlan,
      allowedVlans: allowedVlans ?? this.allowedVlans,
    );
  }

  ChannelGroupConfig merge(ChannelGroupConfig? other) {
    if (other == null) return this;
    return ChannelGroupConfig(
      groupNumber: other.groupNumber,
      name: other.name.isNotEmpty ? other.name : name,
      mode: other.mode,
      portIndices: other.portIndices.isNotEmpty
          ? other.portIndices
          : portIndices,
      nativeVlan: other.nativeVlan,
      allowedVlans: other.allowedVlans.isNotEmpty
          ? other.allowedVlans
          : allowedVlans,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChannelGroupConfig) return false;
    if (portIndices.length != other.portIndices.length) return false;
    for (int i = 0; i < portIndices.length; i++) {
      if (portIndices[i] != other.portIndices[i]) return false;
    }
    return groupNumber == other.groupNumber &&
        name == other.name &&
        mode == other.mode &&
        nativeVlan == other.nativeVlan &&
        allowedVlans == other.allowedVlans;
  }

  @override
  int get hashCode => Object.hash(
    groupNumber,
    name,
    mode,
    Object.hashAll(portIndices),
    nativeVlan,
    allowedVlans,
  );
}

/// ACL type enumeration
enum AclType {
  /// Standard ACL (1-99, 1300-1999) - matches source IP only
  standard,

  /// Extended ACL (100-199, 2000-2699) - matches source/dest IP, protocol, ports
  extended,
}

/// ACL action enumeration
enum AclAction { permit, deny }

/// IP protocol types for extended ACLs
enum AclProtocol { ip, tcp, udp, icmp, gre, esp, ahp, eigrp, ospf, igmp }

/// Port operator for extended ACLs
enum AclPortOperator { eq, neq, gt, lt, range }

/// Access Control List configuration
class AclConfig {
  /// Unique identifier for the ACL
  /// - For numbered ACLs: the number (1-99, 100-199, 1300-1999, 2000-2699)
  /// - For named ACLs: null (uses name instead)
  final int? number;

  /// Name of the ACL (for named ACLs, or descriptive name for numbered)
  final String name;

  /// Type of ACL (standard or extended)
  final AclType type;

  /// Whether this is a named ACL (vs numbered)
  final bool isNamed;

  /// List of ACL entries (rules)
  List<AclEntry> entries;

  /// Whether this ACL is enabled
  bool enabled;

  AclConfig({
    this.number,
    required this.name,
    required this.type,
    this.isNamed = false,
    List<AclEntry>? entries,
    this.enabled = true,
  }) : entries = entries ?? [];

  /// Validate ACL number based on type
  static bool isValidNumber(int number, AclType type) {
    switch (type) {
      case AclType.standard:
        return (number >= 1 && number <= 99) ||
            (number >= 1300 && number <= 1999);
      case AclType.extended:
        return (number >= 100 && number <= 199) ||
            (number >= 2000 && number <= 2699);
    }
  }

  /// Get display name for the ACL
  String get displayName {
    if (isNamed) return name;
    return number != null
        ? '$number${name.isNotEmpty ? ' ($name)' : ''}'
        : name;
  }

  /// Get ACL identifier for IOS commands
  String get identifier => isNamed ? name : (number?.toString() ?? name);

  factory AclConfig.fromJson(Map<String, dynamic> json) {
    return AclConfig(
      number: json['number'],
      name: json['name'] ?? '',
      type: AclType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AclType.standard,
      ),
      isNamed: json['is_named'] ?? false,
      entries:
          (json['entries'] as List<dynamic>?)
              ?.map((e) => AclEntry.fromJson(e))
              .toList() ??
          [],
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (number != null) 'number': number,
      'name': name,
      'type': type.name,
      'is_named': isNamed,
      'entries': entries.map((e) => e.toJson()).toList(),
      'enabled': enabled,
    };
  }

  AclConfig copyWith({
    int? number,
    String? name,
    AclType? type,
    bool? isNamed,
    List<AclEntry>? entries,
    bool? enabled,
  }) {
    return AclConfig(
      number: number ?? this.number,
      name: name ?? this.name,
      type: type ?? this.type,
      isNamed: isNamed ?? this.isNamed,
      entries: entries ?? this.entries.map((e) => e.copyWith()).toList(),
      enabled: enabled ?? this.enabled,
    );
  }

  AclConfig merge(AclConfig? other) {
    if (other == null) return this;
    return AclConfig(
      number: other.number ?? number,
      name: other.name.isNotEmpty ? other.name : name,
      type: other.type,
      isNamed: other.isNamed,
      entries: other.entries.isNotEmpty ? other.entries : entries,
      enabled: other.enabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AclConfig) return false;
    if (entries.length != other.entries.length) return false;
    for (int i = 0; i < entries.length; i++) {
      if (entries[i] != other.entries[i]) return false;
    }
    return number == other.number &&
        name == other.name &&
        type == other.type &&
        isNamed == other.isNamed &&
        enabled == other.enabled;
  }

  @override
  int get hashCode => Object.hash(
    number,
    name,
    type,
    isNamed,
    Object.hashAll(entries),
    enabled,
  );
}

/// A single ACL entry (rule/line)
class AclEntry {
  /// Sequence number (priority) - lower numbers are matched first
  int sequenceNumber;

  /// Action to take (permit or deny)
  AclAction action;

  /// Protocol (for extended ACLs, ignored for standard)
  AclProtocol protocol;

  /// Source IP address (or 'any', 'host x.x.x.x')
  String sourceAddress;

  /// Source wildcard mask (e.g., '0.0.0.255')
  String? sourceWildcard;

  /// Source port operator (eq, neq, gt, lt, range) - for TCP/UDP
  AclPortOperator? sourcePortOperator;

  /// Source port(s) - single port or start of range
  int? sourcePort;

  /// Source port end (for range operator)
  int? sourcePortEnd;

  /// Destination IP address (for extended ACLs)
  String? destAddress;

  /// Destination wildcard mask
  String? destWildcard;

  /// Destination port operator - for TCP/UDP
  AclPortOperator? destPortOperator;

  /// Destination port(s)
  int? destPort;

  /// Destination port end (for range)
  int? destPortEnd;

  /// Log matches
  bool log;

  /// Remark/comment for this entry
  String? remark;

  /// Whether this entry is enabled
  bool enabled;

  AclEntry({
    required this.sequenceNumber,
    required this.action,
    this.protocol = AclProtocol.ip,
    required this.sourceAddress,
    this.sourceWildcard,
    this.sourcePortOperator,
    this.sourcePort,
    this.sourcePortEnd,
    this.destAddress,
    this.destWildcard,
    this.destPortOperator,
    this.destPort,
    this.destPortEnd,
    this.log = false,
    this.remark,
    this.enabled = true,
  });

  /// Check if source is 'any'
  bool get isSourceAny =>
      sourceAddress.toLowerCase() == 'any' ||
      (sourceAddress == '0.0.0.0' && sourceWildcard == '255.255.255.255');

  /// Check if destination is 'any'
  bool get isDestAny =>
      destAddress?.toLowerCase() == 'any' ||
      (destAddress == '0.0.0.0' && destWildcard == '255.255.255.255');

  /// Get a human-readable summary of this entry
  String get summary {
    if (remark != null && remark!.isNotEmpty) {
      return 'remark $remark';
    }

    final parts = <String>[sequenceNumber.toString(), action.name];

    // For extended ACLs, include protocol
    if (protocol != AclProtocol.ip) {
      parts.add(protocol.name);
    }

    // Source
    if (isSourceAny) {
      parts.add('any');
    } else if (sourceWildcard == '0.0.0.0') {
      parts.add('host $sourceAddress');
    } else {
      parts.add(sourceAddress);
      if (sourceWildcard != null) parts.add(sourceWildcard!);
    }

    // Source port for TCP/UDP
    if (sourcePortOperator != null && sourcePort != null) {
      parts.add(_formatPort(sourcePortOperator!, sourcePort!, sourcePortEnd));
    }

    // Destination (extended ACL)
    if (destAddress != null) {
      if (isDestAny) {
        parts.add('any');
      } else if (destWildcard == '0.0.0.0') {
        parts.add('host $destAddress');
      } else {
        parts.add(destAddress!);
        if (destWildcard != null) parts.add(destWildcard!);
      }

      // Destination port
      if (destPortOperator != null && destPort != null) {
        parts.add(_formatPort(destPortOperator!, destPort!, destPortEnd));
      }
    }

    if (log) parts.add('log');

    return parts.join(' ');
  }

  String _formatPort(AclPortOperator op, int port, int? portEnd) {
    switch (op) {
      case AclPortOperator.eq:
        return 'eq $port';
      case AclPortOperator.neq:
        return 'neq $port';
      case AclPortOperator.gt:
        return 'gt $port';
      case AclPortOperator.lt:
        return 'lt $port';
      case AclPortOperator.range:
        return 'range $port ${portEnd ?? port}';
    }
  }

  factory AclEntry.fromJson(Map<String, dynamic> json) {
    return AclEntry(
      sequenceNumber: json['sequence_number'] ?? 10,
      action: AclAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => AclAction.deny,
      ),
      protocol: AclProtocol.values.firstWhere(
        (e) => e.name == json['protocol'],
        orElse: () => AclProtocol.ip,
      ),
      sourceAddress: json['source_address'] ?? 'any',
      sourceWildcard: json['source_wildcard'],
      sourcePortOperator: json['source_port_operator'] != null
          ? AclPortOperator.values.firstWhere(
              (e) => e.name == json['source_port_operator'],
              orElse: () => AclPortOperator.eq,
            )
          : null,
      sourcePort: json['source_port'],
      sourcePortEnd: json['source_port_end'],
      destAddress: json['dest_address'],
      destWildcard: json['dest_wildcard'],
      destPortOperator: json['dest_port_operator'] != null
          ? AclPortOperator.values.firstWhere(
              (e) => e.name == json['dest_port_operator'],
              orElse: () => AclPortOperator.eq,
            )
          : null,
      destPort: json['dest_port'],
      destPortEnd: json['dest_port_end'],
      log: json['log'] ?? false,
      remark: json['remark'],
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sequence_number': sequenceNumber,
      'action': action.name,
      'protocol': protocol.name,
      'source_address': sourceAddress,
      if (sourceWildcard != null) 'source_wildcard': sourceWildcard,
      if (sourcePortOperator != null)
        'source_port_operator': sourcePortOperator!.name,
      if (sourcePort != null) 'source_port': sourcePort,
      if (sourcePortEnd != null) 'source_port_end': sourcePortEnd,
      if (destAddress != null) 'dest_address': destAddress,
      if (destWildcard != null) 'dest_wildcard': destWildcard,
      if (destPortOperator != null)
        'dest_port_operator': destPortOperator!.name,
      if (destPort != null) 'dest_port': destPort,
      if (destPortEnd != null) 'dest_port_end': destPortEnd,
      'log': log,
      if (remark != null) 'remark': remark,
      'enabled': enabled,
    };
  }

  /// Create a copy of this entry
  AclEntry copyWith({
    int? sequenceNumber,
    AclAction? action,
    AclProtocol? protocol,
    String? sourceAddress,
    String? sourceWildcard,
    AclPortOperator? sourcePortOperator,
    int? sourcePort,
    int? sourcePortEnd,
    String? destAddress,
    String? destWildcard,
    AclPortOperator? destPortOperator,
    int? destPort,
    int? destPortEnd,
    bool? log,
    String? remark,
    bool? enabled,
  }) {
    return AclEntry(
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      action: action ?? this.action,
      protocol: protocol ?? this.protocol,
      sourceAddress: sourceAddress ?? this.sourceAddress,
      sourceWildcard: sourceWildcard ?? this.sourceWildcard,
      sourcePortOperator: sourcePortOperator ?? this.sourcePortOperator,
      sourcePort: sourcePort ?? this.sourcePort,
      sourcePortEnd: sourcePortEnd ?? this.sourcePortEnd,
      destAddress: destAddress ?? this.destAddress,
      destWildcard: destWildcard ?? this.destWildcard,
      destPortOperator: destPortOperator ?? this.destPortOperator,
      destPort: destPort ?? this.destPort,
      destPortEnd: destPortEnd ?? this.destPortEnd,
      log: log ?? this.log,
      remark: remark ?? this.remark,
      enabled: enabled ?? this.enabled,
    );
  }

  AclEntry merge(AclEntry? other) {
    if (other == null) return this;
    return AclEntry(
      sequenceNumber: other.sequenceNumber,
      action: other.action,
      protocol: other.protocol,
      sourceAddress: other.sourceAddress.isNotEmpty
          ? other.sourceAddress
          : sourceAddress,
      sourceWildcard: other.sourceWildcard ?? sourceWildcard,
      sourcePortOperator: other.sourcePortOperator ?? sourcePortOperator,
      sourcePort: other.sourcePort ?? sourcePort,
      sourcePortEnd: other.sourcePortEnd ?? sourcePortEnd,
      destAddress: other.destAddress ?? destAddress,
      destWildcard: other.destWildcard ?? destWildcard,
      destPortOperator: other.destPortOperator ?? destPortOperator,
      destPort: other.destPort ?? destPort,
      destPortEnd: other.destPortEnd ?? destPortEnd,
      log: other.log,
      remark: other.remark ?? remark,
      enabled: other.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AclEntry &&
          runtimeType == other.runtimeType &&
          sequenceNumber == other.sequenceNumber &&
          action == other.action &&
          protocol == other.protocol &&
          sourceAddress == other.sourceAddress &&
          sourceWildcard == other.sourceWildcard &&
          sourcePortOperator == other.sourcePortOperator &&
          sourcePort == other.sourcePort &&
          sourcePortEnd == other.sourcePortEnd &&
          destAddress == other.destAddress &&
          destWildcard == other.destWildcard &&
          destPortOperator == other.destPortOperator &&
          destPort == other.destPort &&
          destPortEnd == other.destPortEnd &&
          log == other.log &&
          remark == other.remark &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    sequenceNumber,
    action,
    protocol,
    sourceAddress,
    sourceWildcard,
    sourcePortOperator,
    sourcePort,
    sourcePortEnd,
    destAddress,
    destWildcard,
    destPortOperator,
    destPort,
    destPortEnd,
    log,
    remark,
    enabled,
  );
}

/// Static route configuration stored in device config JSONB
class StaticRouteConfig {
  final String destinationNetwork; // e.g., "0.0.0.0/0" or "192.168.0.0/16"
  final String? nextHop; // Next hop IP address
  final String? exitInterface; // Exit interface name
  final int? adminDistance; // Administrative distance (1-255)
  final String? name; // Route name/tag
  final bool enabled;

  const StaticRouteConfig({
    required this.destinationNetwork,
    this.nextHop,
    this.exitInterface,
    this.adminDistance,
    this.name,
    this.enabled = true,
  });

  /// Human-readable summary of the route
  String get summary {
    final parts = <String>[destinationNetwork];
    if (nextHop != null) parts.add('via $nextHop');
    if (exitInterface != null) parts.add('out $exitInterface');
    if (adminDistance != null) parts.add('[$adminDistance]');
    return parts.join(' ');
  }

  factory StaticRouteConfig.fromJson(Map<String, dynamic> json) {
    return StaticRouteConfig(
      destinationNetwork: json['destination_network'] ?? '',
      nextHop: json['next_hop'],
      exitInterface: json['exit_interface'],
      adminDistance: json['admin_distance'],
      name: json['name'],
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'destination_network': destinationNetwork,
      if (nextHop != null) 'next_hop': nextHop,
      if (exitInterface != null) 'exit_interface': exitInterface,
      if (adminDistance != null) 'admin_distance': adminDistance,
      if (name != null) 'name': name,
      'enabled': enabled,
    };
  }

  StaticRouteConfig copyWith({
    String? destinationNetwork,
    String? nextHop,
    String? exitInterface,
    int? adminDistance,
    String? name,
    bool? enabled,
  }) {
    return StaticRouteConfig(
      destinationNetwork: destinationNetwork ?? this.destinationNetwork,
      nextHop: nextHop ?? this.nextHop,
      exitInterface: exitInterface ?? this.exitInterface,
      adminDistance: adminDistance ?? this.adminDistance,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
    );
  }

  StaticRouteConfig merge(StaticRouteConfig? other) {
    if (other == null) return this;
    return StaticRouteConfig(
      destinationNetwork: other.destinationNetwork.isNotEmpty
          ? other.destinationNetwork
          : destinationNetwork,
      nextHop: other.nextHop ?? nextHop,
      exitInterface: other.exitInterface ?? exitInterface,
      adminDistance: other.adminDistance ?? adminDistance,
      name: other.name ?? name,
      enabled: other.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaticRouteConfig &&
          runtimeType == other.runtimeType &&
          destinationNetwork == other.destinationNetwork &&
          nextHop == other.nextHop &&
          exitInterface == other.exitInterface &&
          adminDistance == other.adminDistance &&
          name == other.name &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(
    destinationNetwork,
    nextHop,
    exitInterface,
    adminDistance,
    name,
    enabled,
  );
}

/// NAT interface role designation
/// Used to configure which interfaces are on the inside (private) or outside (public) of NAT
enum NatInterfaceRole {
  /// No NAT role assigned to this interface
  none,

  /// Interface faces the private/internal network (ip nat inside)
  inside,

  /// Interface faces the public/external network (ip nat outside)
  outside,
}

/// NAT type enumeration
enum NatType {
  /// Static NAT - one-to-one mapping between inside local and inside global
  staticNat,

  /// Dynamic NAT - pool of addresses for many-to-many mapping
  dynamicNat,

  /// PAT (Port Address Translation) - many inside hosts to one outside address
  pat,

  /// Static PAT - port forwarding for a specific service
  staticPat,
}

/// NAT rule configuration stored in device config JSONB
class NatRule {
  /// Type of NAT rule
  final NatType type;

  /// Description for this rule
  final String description;

  /// Inside interface name (ip nat inside)
  final String? insideInterface;

  /// Outside interface name (ip nat outside)
  final String? outsideInterface;

  /// For Static NAT/PAT: Inside local address (private IP)
  final String? insideLocal;

  /// For Static NAT/PAT: Inside global address (public IP)
  final String? insideGlobal;

  /// For Dynamic NAT/PAT: Pool name
  final String? poolName;

  /// For Dynamic NAT/PAT: Pool start address (OUTSIDE/public IPs)
  final String? poolStart;

  /// For Dynamic NAT/PAT: Pool end address (OUTSIDE/public IPs)
  final String? poolEnd;

  /// For Dynamic NAT/PAT: Pool netmask
  final String? poolNetmask;

  /// For Dynamic NAT/PAT: Use interface overload (PAT with outside interface IP)
  final bool useInterfaceOverload;

  /// For Dynamic NAT/PAT: ACL number that defines inside hosts
  final int? aclNumber;

  /// For Dynamic NAT/PAT: Inline ACL entries (source networks in CIDR)
  /// These are the INSIDE/private networks allowed to use NAT
  /// Example: ['192.168.1.0/24', '10.0.0.0/8']
  final List<String> natSourceNetworks;

  /// For Static PAT: Protocol (tcp/udp)
  final String? protocol;

  /// For Static PAT: Local port
  final int? localPort;

  /// For Static PAT: Global port
  final int? globalPort;

  /// Whether this rule is enabled
  final bool enabled;

  const NatRule({
    required this.type,
    this.description = '',
    this.insideInterface,
    this.outsideInterface,
    this.insideLocal,
    this.insideGlobal,
    this.poolName,
    this.poolStart,
    this.poolEnd,
    this.poolNetmask,
    this.useInterfaceOverload = false,
    this.aclNumber,
    this.natSourceNetworks = const [],
    this.protocol,
    this.localPort,
    this.globalPort,
    this.enabled = true,
  });

  /// Get display name for the rule
  String get displayName {
    switch (type) {
      case NatType.staticNat:
        if (insideLocal != null && insideGlobal != null) {
          return '$insideLocal → $insideGlobal';
        }
        return 'Static NAT';
      case NatType.dynamicNat:
        return poolName ?? 'Dynamic NAT';
      case NatType.pat:
        return poolName != null ? '$poolName (PAT)' : 'PAT';
      case NatType.staticPat:
        if (insideLocal != null && localPort != null) {
          return '$insideLocal:$localPort → ${insideGlobal ?? ""}:${globalPort ?? ""}';
        }
        return 'Static PAT';
    }
  }

  /// Get a human-readable summary of this rule
  String get summary {
    final parts = <String>[];

    switch (type) {
      case NatType.staticNat:
        parts.add('ip nat inside source static');
        if (insideLocal != null) parts.add(insideLocal!);
        if (insideGlobal != null) parts.add(insideGlobal!);
        break;
      case NatType.dynamicNat:
        parts.add('ip nat inside source list');
        if (aclNumber != null) parts.add(aclNumber.toString());
        parts.add('pool');
        if (poolName != null) parts.add(poolName!);
        break;
      case NatType.pat:
        parts.add('ip nat inside source list');
        if (aclNumber != null) parts.add(aclNumber.toString());
        parts.add('pool');
        if (poolName != null) parts.add(poolName!);
        parts.add('overload');
        break;
      case NatType.staticPat:
        parts.add('ip nat inside source static');
        if (protocol != null) parts.add(protocol!);
        if (insideLocal != null) parts.add(insideLocal!);
        if (localPort != null) parts.add(localPort.toString());
        if (insideGlobal != null) parts.add(insideGlobal!);
        if (globalPort != null) parts.add(globalPort.toString());
        break;
    }

    return parts.join(' ');
  }

  factory NatRule.fromJson(Map<String, dynamic> json) {
    return NatRule(
      type: NatType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NatType.staticNat,
      ),
      description: json['description'] ?? '',
      insideInterface: json['inside_interface'],
      outsideInterface: json['outside_interface'],
      insideLocal: json['inside_local'],
      insideGlobal: json['inside_global'],
      poolName: json['pool_name'],
      poolStart: json['pool_start'],
      poolEnd: json['pool_end'],
      poolNetmask: json['pool_netmask'],
      useInterfaceOverload: json['use_interface_overload'] ?? false,
      aclNumber: json['acl_number'],
      natSourceNetworks:
          (json['nat_source_networks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      protocol: json['protocol'],
      localPort: json['local_port'],
      globalPort: json['global_port'],
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'description': description,
      if (insideInterface != null) 'inside_interface': insideInterface,
      if (outsideInterface != null) 'outside_interface': outsideInterface,
      if (insideLocal != null) 'inside_local': insideLocal,
      if (insideGlobal != null) 'inside_global': insideGlobal,
      if (poolName != null) 'pool_name': poolName,
      if (poolStart != null) 'pool_start': poolStart,
      if (poolEnd != null) 'pool_end': poolEnd,
      if (poolNetmask != null) 'pool_netmask': poolNetmask,
      'use_interface_overload': useInterfaceOverload,
      if (aclNumber != null) 'acl_number': aclNumber,
      if (natSourceNetworks.isNotEmpty)
        'nat_source_networks': natSourceNetworks,
      if (protocol != null) 'protocol': protocol,
      if (localPort != null) 'local_port': localPort,
      if (globalPort != null) 'global_port': globalPort,
      'enabled': enabled,
    };
  }

  NatRule copyWith({
    NatType? type,
    String? description,
    String? insideInterface,
    String? outsideInterface,
    String? insideLocal,
    String? insideGlobal,
    String? poolName,
    String? poolStart,
    String? poolEnd,
    String? poolNetmask,
    bool? useInterfaceOverload,
    int? aclNumber,
    List<String>? natSourceNetworks,
    String? protocol,
    int? localPort,
    int? globalPort,
    bool? enabled,
  }) {
    return NatRule(
      type: type ?? this.type,
      description: description ?? this.description,
      insideInterface: insideInterface ?? this.insideInterface,
      outsideInterface: outsideInterface ?? this.outsideInterface,
      insideLocal: insideLocal ?? this.insideLocal,
      insideGlobal: insideGlobal ?? this.insideGlobal,
      poolName: poolName ?? this.poolName,
      poolStart: poolStart ?? this.poolStart,
      poolEnd: poolEnd ?? this.poolEnd,
      poolNetmask: poolNetmask ?? this.poolNetmask,
      useInterfaceOverload: useInterfaceOverload ?? this.useInterfaceOverload,
      aclNumber: aclNumber ?? this.aclNumber,
      natSourceNetworks: natSourceNetworks ?? this.natSourceNetworks,
      protocol: protocol ?? this.protocol,
      localPort: localPort ?? this.localPort,
      globalPort: globalPort ?? this.globalPort,
      enabled: enabled ?? this.enabled,
    );
  }

  NatRule merge(NatRule? other) {
    if (other == null) return this;
    return NatRule(
      type: other.type,
      description: other.description.isNotEmpty
          ? other.description
          : description,
      insideInterface: other.insideInterface ?? insideInterface,
      outsideInterface: other.outsideInterface ?? outsideInterface,
      insideLocal: other.insideLocal ?? insideLocal,
      insideGlobal: other.insideGlobal ?? insideGlobal,
      poolName: other.poolName ?? poolName,
      poolStart: other.poolStart ?? poolStart,
      poolEnd: other.poolEnd ?? poolEnd,
      poolNetmask: other.poolNetmask ?? poolNetmask,
      useInterfaceOverload: other.useInterfaceOverload,
      aclNumber: other.aclNumber ?? aclNumber,
      natSourceNetworks: other.natSourceNetworks.isNotEmpty
          ? other.natSourceNetworks
          : natSourceNetworks,
      protocol: other.protocol ?? protocol,
      localPort: other.localPort ?? localPort,
      globalPort: other.globalPort ?? globalPort,
      enabled: other.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NatRule &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          description == other.description &&
          insideInterface == other.insideInterface &&
          outsideInterface == other.outsideInterface &&
          insideLocal == other.insideLocal &&
          insideGlobal == other.insideGlobal &&
          poolName == other.poolName &&
          poolStart == other.poolStart &&
          poolEnd == other.poolEnd &&
          poolNetmask == other.poolNetmask &&
          useInterfaceOverload == other.useInterfaceOverload &&
          aclNumber == other.aclNumber &&
          _listEquals(natSourceNetworks, other.natSourceNetworks) &&
          protocol == other.protocol &&
          localPort == other.localPort &&
          globalPort == other.globalPort &&
          enabled == other.enabled;

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    type,
    description,
    insideInterface,
    outsideInterface,
    insideLocal,
    insideGlobal,
    poolName,
    poolStart,
    poolEnd,
    poolNetmask,
    useInterfaceOverload,
    aclNumber,
    Object.hashAll(natSourceNetworks),
    protocol,
    localPort,
    globalPort,
    enabled,
  );
}

// ============================================================================
// TUNNEL CONFIGURATION
// ============================================================================

/// Tunnel type enumeration
enum TunnelType {
  /// GRE tunnel (Generic Routing Encapsulation)
  gre,

  /// IPsec tunnel (site-to-site VPN)
  ipsec,

  /// GRE over IPsec (encrypted GRE tunnel)
  greOverIpsec,

  /// PPPoE client (DSL/Fiber connections)
  pppoe,
}

/// IPsec authentication method
enum IpsecAuthMethod {
  /// Pre-shared key authentication
  preSharedKey,

  /// RSA signature (certificate-based)
  rsaSignature,
}

/// IPsec encryption algorithm
enum IpsecEncryption { des, des3, aes128, aes192, aes256 }

/// IPsec hash algorithm
enum IpsecHash { md5, sha1, sha256, sha384, sha512 }

/// IPsec DH group
enum IpsecDhGroup {
  group1,
  group2,
  group5,
  group14,
  group15,
  group16,
  group19,
  group20,
  group21,
}

/// Tunnel configuration stored in device config JSONB
class TunnelConfig {
  /// Tunnel type
  final TunnelType type;

  /// Tunnel interface number (e.g., 0 for Tunnel0)
  final int tunnelNumber;

  /// Description for this tunnel
  final String description;

  /// Tunnel source (interface name or IP address)
  final String? tunnelSource;

  /// Tunnel destination IP address
  final String? tunnelDestination;

  /// Selected destination device for interface-based tunnel endpoints
  final int? tunnelDestinationDeviceId;

  /// Selected destination interface key for interface-based tunnel endpoints
  final String? tunnelDestinationInterfaceKey;

  /// IP address for the tunnel interface (CIDR format)
  final String? tunnelIpAddress;

  // ---- GRE-specific settings ----

  /// Tunnel keepalive interval (seconds)
  final int? keepaliveInterval;

  /// Tunnel keepalive retries
  final int? keepaliveRetries;

  /// Tunnel MTU
  final int? mtu;

  // ---- IPsec-specific settings ----

  /// ISAKMP policy priority (1-10000)
  final int? isakmpPriority;

  /// IPsec authentication method
  final IpsecAuthMethod? authMethod;

  /// IPsec encryption algorithm
  final IpsecEncryption? encryption;

  /// IPsec hash algorithm
  final IpsecHash? hash;

  /// IPsec DH group
  final IpsecDhGroup? dhGroup;

  /// ISAKMP lifetime (seconds)
  final int? isakmpLifetime;

  /// Pre-shared key (for PSK authentication)
  final String? preSharedKey;

  /// Peer IP address or hostname
  final String? peerAddress;

  /// Transform set name
  final String? transformSetName;

  /// Crypto map name
  final String? cryptoMapName;

  /// Interesting traffic ACL (defines what traffic to encrypt)
  final int? cryptoAcl;

  /// IPsec SA lifetime (seconds)
  final int? ipsecLifetime;

  // ---- PPPoE-specific settings ----

  /// PPPoE dialer pool number
  final int? dialerPoolNumber;

  /// PPPoE username
  final String? pppUsername;

  /// PPPoE password
  final String? pppPassword;

  /// PPPoE service name (optional)
  final String? pppoeServiceName;

  /// CHAP hostname
  final String? chapHostname;

  /// Enable IP address negotiation
  final bool pppNegotiateIp;

  /// PPPoE source interface (physical interface)
  final String? pppoeSourceInterface;

  /// Whether this tunnel is enabled
  final bool enabled;

  const TunnelConfig({
    required this.type,
    required this.tunnelNumber,
    this.description = '',
    this.tunnelSource,
    this.tunnelDestination,
    this.tunnelDestinationDeviceId,
    this.tunnelDestinationInterfaceKey,
    this.tunnelIpAddress,
    this.keepaliveInterval,
    this.keepaliveRetries,
    this.mtu,
    this.isakmpPriority,
    this.authMethod,
    this.encryption,
    this.hash,
    this.dhGroup,
    this.isakmpLifetime,
    this.preSharedKey,
    this.peerAddress,
    this.transformSetName,
    this.cryptoMapName,
    this.cryptoAcl,
    this.ipsecLifetime,
    this.dialerPoolNumber,
    this.pppUsername,
    this.pppPassword,
    this.pppoeServiceName,
    this.chapHostname,
    this.pppNegotiateIp = true,
    this.pppoeSourceInterface,
    this.enabled = true,
  });

  /// Get display name for the tunnel
  String get displayName {
    switch (type) {
      case TunnelType.gre:
        return 'Tunnel$tunnelNumber (GRE)';
      case TunnelType.ipsec:
        return 'Tunnel$tunnelNumber (IPsec)';
      case TunnelType.greOverIpsec:
        return 'Tunnel$tunnelNumber (GRE/IPsec)';
      case TunnelType.pppoe:
        return 'Dialer$tunnelNumber (PPPoE)';
    }
  }

  /// Get a human-readable summary
  String get summary {
    switch (type) {
      case TunnelType.gre:
      case TunnelType.greOverIpsec:
        if (tunnelDestination != null) {
          return '→ $tunnelDestination';
        }
        return 'Not configured';
      case TunnelType.ipsec:
        if (peerAddress != null) {
          return '↔ $peerAddress';
        }
        return 'Not configured';
      case TunnelType.pppoe:
        if (pppUsername != null) {
          return '$pppUsername@${pppoeServiceName ?? "ISP"}';
        }
        return 'Not configured';
    }
  }

  factory TunnelConfig.fromJson(Map<String, dynamic> json) {
    return TunnelConfig(
      type: TunnelType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TunnelType.gre,
      ),
      tunnelNumber: json['tunnel_number'] ?? 0,
      description: json['description'] ?? '',
      tunnelSource: json['tunnel_source'],
      tunnelDestination: json['tunnel_destination'],
      tunnelDestinationDeviceId: json['tunnel_destination_device_id'],
      tunnelDestinationInterfaceKey: json['tunnel_destination_interface_key'],
      tunnelIpAddress: json['tunnel_ip_address'],
      keepaliveInterval: json['keepalive_interval'],
      keepaliveRetries: json['keepalive_retries'],
      mtu: json['mtu'],
      isakmpPriority: json['isakmp_priority'],
      authMethod: json['auth_method'] != null
          ? IpsecAuthMethod.values.firstWhere(
              (e) => e.name == json['auth_method'],
              orElse: () => IpsecAuthMethod.preSharedKey,
            )
          : null,
      encryption: json['encryption'] != null
          ? IpsecEncryption.values.firstWhere(
              (e) => e.name == json['encryption'],
              orElse: () => IpsecEncryption.aes256,
            )
          : null,
      hash: json['hash'] != null
          ? IpsecHash.values.firstWhere(
              (e) => e.name == json['hash'],
              orElse: () => IpsecHash.sha256,
            )
          : null,
      dhGroup: json['dh_group'] != null
          ? IpsecDhGroup.values.firstWhere(
              (e) => e.name == json['dh_group'],
              orElse: () => IpsecDhGroup.group14,
            )
          : null,
      isakmpLifetime: json['isakmp_lifetime'],
      preSharedKey: json['pre_shared_key'],
      peerAddress: json['peer_address'],
      transformSetName: json['transform_set_name'],
      cryptoMapName: json['crypto_map_name'],
      cryptoAcl: json['crypto_acl'],
      ipsecLifetime: json['ipsec_lifetime'],
      dialerPoolNumber: json['dialer_pool_number'],
      pppUsername: json['ppp_username'],
      pppPassword: json['ppp_password'],
      pppoeServiceName: json['pppoe_service_name'],
      chapHostname: json['chap_hostname'],
      pppNegotiateIp: json['ppp_negotiate_ip'] ?? true,
      pppoeSourceInterface: json['pppoe_source_interface'],
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'tunnel_number': tunnelNumber,
      'description': description,
      if (tunnelSource != null) 'tunnel_source': tunnelSource,
      if (tunnelDestination != null) 'tunnel_destination': tunnelDestination,
      if (tunnelDestinationDeviceId != null)
        'tunnel_destination_device_id': tunnelDestinationDeviceId,
      if (tunnelDestinationInterfaceKey != null)
        'tunnel_destination_interface_key': tunnelDestinationInterfaceKey,
      if (tunnelIpAddress != null) 'tunnel_ip_address': tunnelIpAddress,
      if (keepaliveInterval != null) 'keepalive_interval': keepaliveInterval,
      if (keepaliveRetries != null) 'keepalive_retries': keepaliveRetries,
      if (mtu != null) 'mtu': mtu,
      if (isakmpPriority != null) 'isakmp_priority': isakmpPriority,
      if (authMethod != null) 'auth_method': authMethod!.name,
      if (encryption != null) 'encryption': encryption!.name,
      if (hash != null) 'hash': hash!.name,
      if (dhGroup != null) 'dh_group': dhGroup!.name,
      if (isakmpLifetime != null) 'isakmp_lifetime': isakmpLifetime,
      if (preSharedKey != null) 'pre_shared_key': preSharedKey,
      if (peerAddress != null) 'peer_address': peerAddress,
      if (transformSetName != null) 'transform_set_name': transformSetName,
      if (cryptoMapName != null) 'crypto_map_name': cryptoMapName,
      if (cryptoAcl != null) 'crypto_acl': cryptoAcl,
      if (ipsecLifetime != null) 'ipsec_lifetime': ipsecLifetime,
      if (dialerPoolNumber != null) 'dialer_pool_number': dialerPoolNumber,
      if (pppUsername != null) 'ppp_username': pppUsername,
      if (pppPassword != null) 'ppp_password': pppPassword,
      if (pppoeServiceName != null) 'pppoe_service_name': pppoeServiceName,
      if (chapHostname != null) 'chap_hostname': chapHostname,
      'ppp_negotiate_ip': pppNegotiateIp,
      if (pppoeSourceInterface != null)
        'pppoe_source_interface': pppoeSourceInterface,
      'enabled': enabled,
    };
  }

  TunnelConfig copyWith({
    TunnelType? type,
    int? tunnelNumber,
    String? description,
    String? tunnelSource,
    String? tunnelDestination,
    int? tunnelDestinationDeviceId,
    String? tunnelDestinationInterfaceKey,
    String? tunnelIpAddress,
    int? keepaliveInterval,
    int? keepaliveRetries,
    int? mtu,
    int? isakmpPriority,
    IpsecAuthMethod? authMethod,
    IpsecEncryption? encryption,
    IpsecHash? hash,
    IpsecDhGroup? dhGroup,
    int? isakmpLifetime,
    String? preSharedKey,
    String? peerAddress,
    String? transformSetName,
    String? cryptoMapName,
    int? cryptoAcl,
    int? ipsecLifetime,
    int? dialerPoolNumber,
    String? pppUsername,
    String? pppPassword,
    String? pppoeServiceName,
    String? chapHostname,
    bool? pppNegotiateIp,
    String? pppoeSourceInterface,
    bool? enabled,
  }) {
    return TunnelConfig(
      type: type ?? this.type,
      tunnelNumber: tunnelNumber ?? this.tunnelNumber,
      description: description ?? this.description,
      tunnelSource: tunnelSource ?? this.tunnelSource,
      tunnelDestination: tunnelDestination ?? this.tunnelDestination,
      tunnelDestinationDeviceId:
          tunnelDestinationDeviceId ?? this.tunnelDestinationDeviceId,
      tunnelDestinationInterfaceKey:
          tunnelDestinationInterfaceKey ?? this.tunnelDestinationInterfaceKey,
      tunnelIpAddress: tunnelIpAddress ?? this.tunnelIpAddress,
      keepaliveInterval: keepaliveInterval ?? this.keepaliveInterval,
      keepaliveRetries: keepaliveRetries ?? this.keepaliveRetries,
      mtu: mtu ?? this.mtu,
      isakmpPriority: isakmpPriority ?? this.isakmpPriority,
      authMethod: authMethod ?? this.authMethod,
      encryption: encryption ?? this.encryption,
      hash: hash ?? this.hash,
      dhGroup: dhGroup ?? this.dhGroup,
      isakmpLifetime: isakmpLifetime ?? this.isakmpLifetime,
      preSharedKey: preSharedKey ?? this.preSharedKey,
      peerAddress: peerAddress ?? this.peerAddress,
      transformSetName: transformSetName ?? this.transformSetName,
      cryptoMapName: cryptoMapName ?? this.cryptoMapName,
      cryptoAcl: cryptoAcl ?? this.cryptoAcl,
      ipsecLifetime: ipsecLifetime ?? this.ipsecLifetime,
      dialerPoolNumber: dialerPoolNumber ?? this.dialerPoolNumber,
      pppUsername: pppUsername ?? this.pppUsername,
      pppPassword: pppPassword ?? this.pppPassword,
      pppoeServiceName: pppoeServiceName ?? this.pppoeServiceName,
      chapHostname: chapHostname ?? this.chapHostname,
      pppNegotiateIp: pppNegotiateIp ?? this.pppNegotiateIp,
      pppoeSourceInterface: pppoeSourceInterface ?? this.pppoeSourceInterface,
      enabled: enabled ?? this.enabled,
    );
  }

  TunnelConfig merge(TunnelConfig? other) {
    if (other == null) return this;
    return TunnelConfig(
      type: other.type,
      tunnelNumber: other.tunnelNumber,
      description: other.description.isNotEmpty
          ? other.description
          : description,
      tunnelSource: other.tunnelSource ?? tunnelSource,
      tunnelDestination: other.tunnelDestination ?? tunnelDestination,
      tunnelDestinationDeviceId:
          other.tunnelDestinationDeviceId ?? tunnelDestinationDeviceId,
      tunnelDestinationInterfaceKey:
          other.tunnelDestinationInterfaceKey ?? tunnelDestinationInterfaceKey,
      tunnelIpAddress: other.tunnelIpAddress ?? tunnelIpAddress,
      keepaliveInterval: other.keepaliveInterval ?? keepaliveInterval,
      keepaliveRetries: other.keepaliveRetries ?? keepaliveRetries,
      mtu: other.mtu ?? mtu,
      isakmpPriority: other.isakmpPriority ?? isakmpPriority,
      authMethod: other.authMethod ?? authMethod,
      encryption: other.encryption ?? encryption,
      hash: other.hash ?? hash,
      dhGroup: other.dhGroup ?? dhGroup,
      isakmpLifetime: other.isakmpLifetime ?? isakmpLifetime,
      preSharedKey: other.preSharedKey ?? preSharedKey,
      peerAddress: other.peerAddress ?? peerAddress,
      transformSetName: other.transformSetName ?? transformSetName,
      cryptoMapName: other.cryptoMapName ?? cryptoMapName,
      cryptoAcl: other.cryptoAcl ?? cryptoAcl,
      ipsecLifetime: other.ipsecLifetime ?? ipsecLifetime,
      dialerPoolNumber: other.dialerPoolNumber ?? dialerPoolNumber,
      pppUsername: other.pppUsername ?? pppUsername,
      pppPassword: other.pppPassword ?? pppPassword,
      pppoeServiceName: other.pppoeServiceName ?? pppoeServiceName,
      chapHostname: other.chapHostname ?? chapHostname,
      pppNegotiateIp: other.pppNegotiateIp,
      pppoeSourceInterface: other.pppoeSourceInterface ?? pppoeSourceInterface,
      enabled: other.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TunnelConfig &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          tunnelNumber == other.tunnelNumber &&
          description == other.description &&
          tunnelSource == other.tunnelSource &&
          tunnelDestination == other.tunnelDestination &&
          tunnelDestinationDeviceId == other.tunnelDestinationDeviceId &&
          tunnelDestinationInterfaceKey ==
              other.tunnelDestinationInterfaceKey &&
          tunnelIpAddress == other.tunnelIpAddress &&
          keepaliveInterval == other.keepaliveInterval &&
          keepaliveRetries == other.keepaliveRetries &&
          mtu == other.mtu &&
          isakmpPriority == other.isakmpPriority &&
          authMethod == other.authMethod &&
          encryption == other.encryption &&
          hash == other.hash &&
          dhGroup == other.dhGroup &&
          isakmpLifetime == other.isakmpLifetime &&
          preSharedKey == other.preSharedKey &&
          peerAddress == other.peerAddress &&
          transformSetName == other.transformSetName &&
          cryptoMapName == other.cryptoMapName &&
          cryptoAcl == other.cryptoAcl &&
          ipsecLifetime == other.ipsecLifetime &&
          dialerPoolNumber == other.dialerPoolNumber &&
          pppUsername == other.pppUsername &&
          pppPassword == other.pppPassword &&
          pppoeServiceName == other.pppoeServiceName &&
          chapHostname == other.chapHostname &&
          pppNegotiateIp == other.pppNegotiateIp &&
          pppoeSourceInterface == other.pppoeSourceInterface &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hashAll([
    type,
    tunnelNumber,
    description,
    tunnelSource,
    tunnelDestination,
    tunnelDestinationDeviceId,
    tunnelDestinationInterfaceKey,
    tunnelIpAddress,
    keepaliveInterval,
    keepaliveRetries,
    mtu,
    isakmpPriority,
    authMethod,
    encryption,
    hash,
    dhGroup,
    isakmpLifetime,
    preSharedKey,
    peerAddress,
    transformSetName,
    cryptoMapName,
    cryptoAcl,
    ipsecLifetime,
    dialerPoolNumber,
    pppUsername,
    pppPassword,
    pppoeServiceName,
    chapHostname,
    pppNegotiateIp,
    pppoeSourceInterface,
    enabled,
  ]);
}
