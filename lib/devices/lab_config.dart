/// Lab Configuration - Loads centralized lab configuration from Supabase.
///
/// This module loads configuration from the Supabase `inventory` table which contains:
/// 1. Inventory - Physical devices in the lab
/// 2. Constraints - Reserved devices, ports, VLANs
/// 3. Port restrictions - Full and partial locks
/// 4. Permanent connections - Router-switch management links
///
/// The data is loaded once on startup from the `data` JSONB column of the `inventory` table.
/// Both Python (ktracer_client) and Dart (ktracer_center) use the same Supabase data.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// A physical device in the lab.
class LabDevice {
  final int realId;
  final int presetId;
  final String defaultHostname;

  const LabDevice({
    required this.realId,
    required this.presetId,
    required this.defaultHostname,
  });

  factory LabDevice.fromJson(Map<String, dynamic> json) {
    return LabDevice(
      realId: json['realId'] as int,
      presetId: json['presetId'] as int,
      defaultHostname: json['defaultHostname'] as String,
    );
  }
}

/// A device that is reserved and cannot be assigned to projects.
class ReservedDevice {
  final int realId;
  final String reason;
  final bool permanentLock;

  const ReservedDevice({
    required this.realId,
    required this.reason,
    this.permanentLock = true,
  });

  factory ReservedDevice.fromJson(Map<String, dynamic> json) {
    return ReservedDevice(
      realId: json['realId'] as int,
      reason: json['reason'] as String,
      permanentLock: json['permanentLock'] as bool? ?? true,
    );
  }
}

/// A VLAN that is locked from user modification.
class ReservedVlan {
  final int vlanId;
  final String name;
  final String reason;

  const ReservedVlan({
    required this.vlanId,
    required this.name,
    required this.reason,
  });

  factory ReservedVlan.fromJson(Map<String, dynamic> json) {
    return ReservedVlan(
      vlanId: json['vlanId'] as int,
      name: json['name'] as String,
      reason: json['reason'] as String,
    );
  }
}

/// Specific restrictions for a partially locked port.
class PortRestrictions {
  final bool cannotJoinPortChannel;
  final bool mustBeTrunk;
  final List<int>? mustAllowVlans; // List of VLANs that must be allowed
  final bool cannotShutdown;
  final bool canAddSubinterfaces;
  final bool cannotModify;
  final bool cannotDelete;

  const PortRestrictions({
    this.cannotJoinPortChannel = false,
    this.mustBeTrunk = false,
    this.mustAllowVlans,
    this.cannotShutdown = false,
    this.canAddSubinterfaces = false,
    this.cannotModify = false,
    this.cannotDelete = false,
  });

  factory PortRestrictions.fromJson(Map<String, dynamic> json) {
    // Support both mustAllowVlans (list) and legacy mustAllowVlan (single int)
    List<int>? mustAllowVlans;
    if (json['mustAllowVlans'] != null) {
      mustAllowVlans = (json['mustAllowVlans'] as List).cast<int>();
    } else if (json['mustAllowVlan'] != null) {
      mustAllowVlans = [json['mustAllowVlan'] as int];
    }
    return PortRestrictions(
      cannotJoinPortChannel: json['cannotJoinPortChannel'] as bool? ?? false,
      mustBeTrunk: json['mustBeTrunk'] as bool? ?? false,
      mustAllowVlans: mustAllowVlans,
      cannotShutdown: json['cannotShutdown'] as bool? ?? false,
      canAddSubinterfaces: json['canAddSubinterfaces'] as bool? ?? false,
      cannotModify: json['cannotModify'] as bool? ?? false,
      cannotDelete: json['cannotDelete'] as bool? ?? false,
    );
  }
}

/// A port that is locked (fully or partially).
class PortLock {
  final String pattern;
  final String reason;
  final bool appliesToAllDevices;
  final List<int>? specificRealIds;
  final PortRestrictions? restrictions;
  final bool isFullyLocked;

  const PortLock({
    required this.pattern,
    required this.reason,
    this.appliesToAllDevices = true,
    this.specificRealIds,
    this.restrictions,
    this.isFullyLocked = true,
  });

  factory PortLock.fromJson(
    Map<String, dynamic> json, {
    bool isFullyLocked = true,
  }) {
    PortRestrictions? restrictions;
    if (json['restrictions'] != null) {
      restrictions = PortRestrictions.fromJson(
        json['restrictions'] as Map<String, dynamic>,
      );
    }

    return PortLock(
      pattern: json['pattern'] as String,
      reason: json['reason'] as String,
      appliesToAllDevices: json['appliesToAllDevices'] as bool? ?? true,
      specificRealIds: (json['specificRealIds'] as List?)?.cast<int>(),
      restrictions: restrictions,
      isFullyLocked: isFullyLocked,
    );
  }
}

/// A permanent router-switch connection for management.
class PermanentConnection {
  final int routerRealId;
  final int switchRealId;
  final String routerPort;
  final String routerSubinterface;
  final String switchPort;
  final int vlanId;
  final String reason;

  const PermanentConnection({
    required this.routerRealId,
    required this.switchRealId,
    required this.routerPort,
    required this.routerSubinterface,
    required this.switchPort,
    required this.vlanId,
    required this.reason,
  });

  factory PermanentConnection.fromJson(Map<String, dynamic> json) {
    return PermanentConnection(
      routerRealId: json['routerRealId'] as int,
      switchRealId: json['switchRealId'] as int,
      routerPort: json['routerPort'] as String,
      routerSubinterface: json['routerSubinterface'] as String,
      switchPort: json['switchPort'] as String,
      vlanId: json['vlanId'] as int,
      reason: json['reason'] as String,
    );
  }
}

/// Centralized lab configuration loaded from Supabase.
/// Singleton pattern - call `await LabConfig.initialize()` once on startup,
/// then access via `LabConfig.instance`.
class LabConfig {
  static LabConfig? _instance;
  static bool _initialized = false;

  // Raw data
  Map<String, dynamic> _raw = {};

  // Inventory
  List<LabDevice> _devices = [];
  Map<int, int> _routerToSwitchMap = {};
  Map<int, int> _switchToRouterMap = {};
  Set<int> _routersWithSwitchportModules = {};

  // Constraints
  List<ReservedDevice> _reservedDevices = [];
  Set<int> _reservedRealIds = {};
  List<ReservedVlan> _reservedVlans = [];
  Set<int> _reservedVlanIds = {};
  List<PortLock> _fullyLockedPorts = [];
  List<PortLock> _partiallyLockedPorts = [];
  List<PermanentConnection> _permanentConnections = [];
  int _managementVlan = 80;
  int _systemProjectId = 0;

  LabConfig._();

  /// Get the singleton instance. Must call `initialize()` first.
  static LabConfig get instance {
    if (_instance == null || !_initialized) {
      throw StateError(
        'LabConfig not initialized. Call LabConfig.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Check if LabConfig has been initialized
  static bool get isInitialized => _initialized;

  /// Initialize the singleton by loading from Supabase. Call once on startup.
  static Future<void> initialize() async {
    _instance = LabConfig._();
    await _instance!._loadFromSupabase();
    _initialized = true;
  }

  /// Force reload the configuration from Supabase.
  static Future<void> reload() async {
    await initialize();
  }

  Future<void> _loadFromSupabase() async {
    final client = Supabase.instance.client;
    final response = await client
        .from('inventory')
        .select('data')
        .limit(1)
        .single();

    _raw = response['data'] as Map<String, dynamic>? ?? {};

    _loadInventory();
    _loadConstraints();
  }

  void _loadInventory() {
    final inventory = _raw['inventory'] as Map<String, dynamic>? ?? {};

    // Load devices
    final devicesJson = inventory['devices'] as List? ?? [];
    _devices = devicesJson
        .map((d) => LabDevice.fromJson(d as Map<String, dynamic>))
        .toList();

    // Load router-switch mappings (skip comment keys like "_comment")
    final rsMap = inventory['routerToSwitchMap'] as Map<String, dynamic>? ?? {};
    _routerToSwitchMap = {};
    _switchToRouterMap = {};
    for (final entry in rsMap.entries) {
      if (entry.key.startsWith('_')) continue; // Skip comment/metadata keys
      final routerId = int.parse(entry.key);
      final switchId = entry.value as int;
      _routerToSwitchMap[routerId] = switchId;
      _switchToRouterMap[switchId] = routerId;
    }

    // Load routers with switchport modules
    final swpModules = inventory['routersWithSwitchportModules'] as List? ?? [];
    _routersWithSwitchportModules = swpModules.cast<int>().toSet();
  }

  void _loadConstraints() {
    final constraints = _raw['constraints'] as Map<String, dynamic>? ?? {};

    _systemProjectId = constraints['systemProjectId'] as int? ?? 0;

    // Load reserved devices
    final reservedDevicesJson = constraints['reservedDevices'] as List? ?? [];
    _reservedDevices = reservedDevicesJson
        .map((d) => ReservedDevice.fromJson(d as Map<String, dynamic>))
        .toList();
    _reservedRealIds = _reservedDevices.map((d) => d.realId).toSet();

    // Load reserved VLANs
    final reservedVlansJson = constraints['reservedVlans'] as List? ?? [];
    _reservedVlans = reservedVlansJson
        .map((v) => ReservedVlan.fromJson(v as Map<String, dynamic>))
        .toList();
    _reservedVlanIds = _reservedVlans.map((v) => v.vlanId).toSet();

    // Load port restrictions
    final portRestrictions =
        constraints['portRestrictions'] as Map<String, dynamic>? ?? {};

    final fullyLockedJson = portRestrictions['fullyLocked'] as List? ?? [];
    _fullyLockedPorts = fullyLockedJson
        .map(
          (p) =>
              PortLock.fromJson(p as Map<String, dynamic>, isFullyLocked: true),
        )
        .toList();

    final partiallyLockedJson =
        portRestrictions['partiallyLocked'] as List? ?? [];
    _partiallyLockedPorts = partiallyLockedJson
        .map(
          (p) => PortLock.fromJson(
            p as Map<String, dynamic>,
            isFullyLocked: false,
          ),
        )
        .toList();

    // Load permanent connections
    final permConns =
        constraints['permanentConnections'] as Map<String, dynamic>? ?? {};
    final connectionsJson = permConns['connections'] as List? ?? [];
    _permanentConnections = connectionsJson
        .map((c) => PermanentConnection.fromJson(c as Map<String, dynamic>))
        .toList();

    // Load validation settings
    final validation = _raw['validation'] as Map<String, dynamic>? ?? {};
    _managementVlan = validation['managementVlan'] as int? ?? 80;
  }

  // ==================== INVENTORY ACCESSORS ====================

  List<LabDevice> get devices => _devices;
  Map<int, int> get routerToSwitchMap => _routerToSwitchMap;
  Map<int, int> get switchToRouterMap => _switchToRouterMap;
  Set<int> get routersWithSwitchportModules => _routersWithSwitchportModules;

  LabDevice? getDeviceByRealId(int realId) {
    return _devices.where((d) => d.realId == realId).firstOrNull;
  }

  List<LabDevice> getDevicesByPresetId(int presetId) {
    return _devices.where((d) => d.presetId == presetId).toList();
  }

  List<int> getRealIdsForPreset(int presetId) {
    return _devices
        .where((d) => d.presetId == presetId)
        .map((d) => d.realId)
        .toList();
  }

  int countByPresetId(int presetId) {
    return _devices.where((d) => d.presetId == presetId).length;
  }

  // ==================== CONSTRAINT ACCESSORS ====================

  Set<int> get reservedRealIds => _reservedRealIds;
  Set<int> get reservedVlanIds => _reservedVlanIds;
  int get managementVlan => _managementVlan;
  int get systemProjectId => _systemProjectId;
  List<PermanentConnection> get permanentConnections => _permanentConnections;

  bool isDeviceReserved(int realId) => _reservedRealIds.contains(realId);

  String? getDeviceReservationReason(int realId) {
    for (final device in _reservedDevices) {
      if (device.realId == realId) {
        return device.reason;
      }
    }
    return null;
  }

  bool isVlanReserved(int vlanId) => _reservedVlanIds.contains(vlanId);

  String? getVlanReservationReason(int vlanId) {
    for (final vlan in _reservedVlans) {
      if (vlan.vlanId == vlanId) {
        return vlan.reason;
      }
    }
    return null;
  }

  List<LabDevice> getAssignableDevices() {
    return _devices.where((d) => !isDeviceReserved(d.realId)).toList();
  }

  List<LabDevice> getAssignableByPresetId(int presetId) {
    return _devices
        .where((d) => d.presetId == presetId && !isDeviceReserved(d.realId))
        .toList();
  }

  int countAssignableByPresetId(int presetId) {
    return _devices
        .where((d) => d.presetId == presetId && !isDeviceReserved(d.realId))
        .length;
  }

  // ==================== PORT RESTRICTION METHODS ====================

  String _normalizePortName(String portName) {
    return portName.toLowerCase().replaceAll(' ', '').replaceAll('/', '');
  }

  bool _portMatchesPattern(String portName, String pattern) {
    final portLower = portName.toLowerCase();
    final patternLower = pattern.toLowerCase();

    if (patternLower.startsWith('/')) {
      // Pattern like "/24" - matches any interface ending with this
      return portLower.endsWith(patternLower);
    } else {
      // Contains match
      return portLower.contains(patternLower);
    }
  }

  PortLock? _checkPortLock(String portName, int? realId, List<PortLock> locks) {
    for (final lock in locks) {
      if (!_portMatchesPattern(portName, lock.pattern)) {
        continue;
      }

      if (lock.appliesToAllDevices) {
        return lock;
      } else if (realId != null && lock.specificRealIds != null) {
        if (lock.specificRealIds!.contains(realId)) {
          return lock;
        }
      }
    }
    return null;
  }

  bool isPortFullyLocked(String portName, {int? realId}) {
    return _checkPortLock(portName, realId, _fullyLockedPorts) != null;
  }

  String? getPortFullLockReason(String portName, {int? realId}) {
    final lock = _checkPortLock(portName, realId, _fullyLockedPorts);
    return lock?.reason;
  }

  PortRestrictions? getPortRestrictions(String portName, {int? realId}) {
    final lock = _checkPortLock(portName, realId, _partiallyLockedPorts);
    return lock?.restrictions;
  }

  String? getPortPartialLockReason(String portName, {int? realId}) {
    final lock = _checkPortLock(portName, realId, _partiallyLockedPorts);
    return lock?.reason;
  }

  bool isPortReserved(String portName, {int? realId}) {
    return isPortFullyLocked(portName, realId: realId) ||
        _checkPortLock(portName, realId, _partiallyLockedPorts) != null;
  }

  String? getPortReservationReason(String portName, {int? realId}) {
    final reason = getPortFullLockReason(portName, realId: realId);
    if (reason != null) return reason;
    return getPortPartialLockReason(portName, realId: realId);
  }

  bool canPortJoinChannel(String portName, {int? realId}) {
    if (isPortFullyLocked(portName, realId: realId)) return false;
    final restrictions = getPortRestrictions(portName, realId: realId);
    if (restrictions != null && restrictions.cannotJoinPortChannel)
      return false;
    return true;
  }

  bool canPortShutdown(String portName, {int? realId}) {
    if (isPortFullyLocked(portName, realId: realId)) return false;
    final restrictions = getPortRestrictions(portName, realId: realId);
    if (restrictions != null && restrictions.cannotShutdown) return false;
    return true;
  }

  List<int> getRequiredTrunkVlans(String portName, {int? realId}) {
    final restrictions = getPortRestrictions(portName, realId: realId);
    if (restrictions != null && restrictions.mustAllowVlans != null) {
      return restrictions.mustAllowVlans!;
    }
    return [];
  }

  // ==================== PERMANENT CONNECTION METHODS ====================

  PermanentConnection? getPermanentConnectionForRouter(int routerRealId) {
    for (final conn in _permanentConnections) {
      if (conn.routerRealId == routerRealId) {
        return conn;
      }
    }
    return null;
  }

  PermanentConnection? getPermanentConnectionForSwitch(int switchRealId) {
    for (final conn in _permanentConnections) {
      if (conn.switchRealId == switchRealId) {
        return conn;
      }
    }
    return null;
  }

  bool isSystemSubinterface(int realId, String subinterfaceName) {
    for (final conn in _permanentConnections) {
      if (conn.routerRealId == realId) {
        if (_normalizePortName(subinterfaceName) ==
            _normalizePortName(conn.routerSubinterface)) {
          return true;
        }
      }
    }
    return false;
  }

  bool isSystemLock(int projectId) => projectId == _systemProjectId;

  List<int> getAvailableRealIds(List<int> allRealIds) {
    return allRealIds.where((rid) => !_reservedRealIds.contains(rid)).toList();
  }
}
