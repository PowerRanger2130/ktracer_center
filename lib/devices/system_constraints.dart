/// System Constraints - Defines locked/reserved resources for the lab management system.
///
/// This module provides backward compatibility by delegating to [LabConfig].
/// The actual data is now loaded from Supabase on startup.
///
/// This module defines:
/// 1. Reserved devices (e.g., master switch, internet gateway)
/// 2. Reserved ports (e.g., port 24 for management on all devices)
/// 3. Reserved VLANs (e.g., VLAN 80 for management)
/// 4. Permanent router-switch connections (2811 routers connect to switches via F0/1)
library;

import 'package:ktracer_center/devices/lab_config.dart';

// Re-export types from lab_config for backward compatibility
export 'package:ktracer_center/devices/lab_config.dart'
    show
        ReservedDevice,
        ReservedVlan,
        PortLock,
        PortRestrictions,
        PermanentConnection;

// Legacy type aliases for backward compatibility
typedef SystemReservedDevice = ReservedDevice;
typedef SystemReservedPort = PortLock;
typedef SystemReservedVlan = ReservedVlan;
typedef PermanentRouterSwitchConnection = PermanentConnection;

// ==================== HELPER FUNCTIONS ====================
// These delegate to LabConfig for backward compatibility

/// Check if a device is reserved (not assignable to projects).
bool isDeviceReserved(int realId) =>
    LabConfig.instance.isDeviceReserved(realId);

/// Get the reason why a device is reserved.
String? getDeviceReservationReason(int realId) =>
    LabConfig.instance.getDeviceReservationReason(realId);

/// Check if a port is reserved/locked.
///
/// [portName] - The interface name (e.g., "FastEthernet0/24", "Gi0/24")
/// [realId] - Optional real_id of the device (for device-specific reservations)
bool isPortReserved(String portName, {int? realId}) =>
    LabConfig.instance.isPortReserved(portName, realId: realId);

/// Get the reason why a port is reserved.
String? getPortReservationReason(String portName, {int? realId}) =>
    LabConfig.instance.getPortReservationReason(portName, realId: realId);

/// Check if a VLAN is reserved/locked.
bool isVlanReserved(int vlanId) => LabConfig.instance.isVlanReserved(vlanId);

/// Get the reason why a VLAN is reserved.
String? getVlanReservationReason(int vlanId) =>
    LabConfig.instance.getVlanReservationReason(vlanId);

/// Filter out reserved devices from a list of real_ids.
List<int> getAvailableRealIds(List<int> allRealIds) =>
    LabConfig.instance.getAvailableRealIds(allRealIds);

/// Special project ID used for system/permanent locks
int get systemProjectId => LabConfig.instance.systemProjectId;

/// Check if a lock is a system lock (cannot be released)
bool isSystemLock(int projectId) => LabConfig.instance.isSystemLock(projectId);

// ==================== PERMANENT CONNECTION HELPERS ====================

/// Get the permanent connection for a router by its real_id
PermanentConnection? getPermanentConnectionForRouter(int routerRealId) =>
    LabConfig.instance.getPermanentConnectionForRouter(routerRealId);

/// Get the permanent connection for a switch by its real_id
PermanentConnection? getPermanentConnectionForSwitch(int switchRealId) =>
    LabConfig.instance.getPermanentConnectionForSwitch(switchRealId);

/// Check if a subinterface is a system management subinterface (cannot be modified)
bool isSystemSubinterface(int realId, String subinterfaceName) =>
    LabConfig.instance.isSystemSubinterface(realId, subinterfaceName);

// ==================== ACCESSORS FOR COLLECTIONS ====================
// These provide access to the underlying collections for iteration

/// Set of real_ids that are reserved (quick lookup)
Set<int> get reservedRealIds => LabConfig.instance.reservedRealIds;

/// Set of reserved VLAN IDs (quick lookup)
Set<int> get reservedVlanIds => LabConfig.instance.reservedVlanIds;

/// Routers with switchport modules (don't need Fa0/1 mapping)
Set<int> get routersWithSwitchportModules =>
    LabConfig.instance.routersWithSwitchportModules;

/// Get all permanent router-switch connections
List<PermanentConnection> get permanentRouterSwitchConnections =>
    LabConfig.instance.permanentConnections;

/// Set of router real_ids that have permanent switch connections
Set<int> get routersWithPermanentSwitchConnection =>
    LabConfig.instance.permanentConnections.map((c) => c.routerRealId).toSet();

/// Set of switch real_ids that have permanent router connections
Set<int> get switchesWithPermanentRouterConnection =>
    LabConfig.instance.permanentConnections.map((c) => c.switchRealId).toSet();
