// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ktracer_center/controllers/lock_service.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/devices/device_preset.dart';
import 'package:ktracer_center/devices/lab_config.dart';
import 'package:ktracer_center/devices/lab_inventory.dart';
import 'package:ktracer_center/grpc/grpc.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/project.dart';
import 'package:ktracer_center/controllers/device_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ConnectionStatus { connecting, connected, disconnected, error }

class AppState extends ChangeNotifier {
  KtUser? _currentUser;
  List<Project> _projects = [];
  Project? _selectedProject;
  List<NetDevice> _devices = [];
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _projectSubscription;
  StreamSubscription? _projectsListSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _projectChangesChannel;
  DeviceController? _deviceController;
  LockService? _lockService;
  DeviceManagerClient? _grpcClient;
  int _navigationIndex = 0;
  int? _pendingNavigateDeviceId;
  bool _pendingNavigateToHome = false;

  /// Connection status tracking
  ConnectionStatus _grpcStatus = ConnectionStatus.connecting;
  ConnectionStatus _supabaseStatus = ConnectionStatus.connecting;
  String? _grpcError;
  String? _supabaseError;
  Timer? _grpcReconnectTimer;
  Timer? _supabaseReconnectTimer;
  bool _mockGrpcConnected = false;

  /// Track device IDs that are pending deletion to filter from stream updates
  final Set<int> _pendingDeleteIds = {};

  KtUser? get currentUser => _currentUser;
  List<Project> get projects => _projects;
  Project? get selectedProject => _selectedProject;
  List<NetDevice> get devices => _devices;
  DeviceController? get deviceController => _deviceController;
  LockService? get lockService => _lockService;
  DeviceManagerClient? get grpcClient => _grpcClient;
  int get navigationIndex => _navigationIndex;
  int? get pendingNavigateDeviceId => _pendingNavigateDeviceId;
  bool get pendingNavigateToHome => _pendingNavigateToHome;

  /// Called by the UI after it has acted on the pending navigation request.
  void consumeNavigation() {
    _pendingNavigateDeviceId = null;
    _pendingNavigateToHome = false;
  }

  /// Connection status getters
  ConnectionStatus get grpcStatus =>
      _mockGrpcConnected ? ConnectionStatus.connected : _grpcStatus;
  ConnectionStatus get supabaseStatus => _supabaseStatus;
  String? get grpcError => _mockGrpcConnected ? null : _grpcError;
  String? get supabaseError => _supabaseError;

  bool get mockGrpcConnected => _mockGrpcConnected;

  void setMockGrpcConnected(bool value) {
    _mockGrpcConnected = value;
    if (value) {
      // Cancel pending reconnect timer — no need while mocked
      _grpcReconnectTimer?.cancel();
      _grpcReconnectTimer = null;
    } else if (_grpcStatus != ConnectionStatus.connected) {
      // Resume real connection attempts
      _scheduleGrpcReconnect();
    }
    notifyListeners();
  }

  /// Whether the gRPC client is connected
  bool get isGrpcConnected =>
      _mockGrpcConnected || _grpcStatus == ConnectionStatus.connected;

  /// Whether Supabase is connected
  bool get isSupabaseConnected => _supabaseStatus == ConnectionStatus.connected;

  /// Whether the app is usable (Supabase must be connected)
  bool get isAppUsable => _supabaseStatus == ConnectionStatus.connected;

  void setNavigationIndex(int index) {
    _navigationIndex = index;
    notifyListeners();
  }

  /// Get sorted devices list (same order as displayed in navigation)
  List<NetDevice> get sortedDevices {
    final devicesByGroup = this.devicesByGroup;
    final result = <NetDevice>[];

    // Sort devices within each group by sortOrder, then hostname
    List<NetDevice> sortDevices(List<NetDevice> devices) {
      return devices.toList()..sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) return orderCompare;
        return a.hostname.compareTo(b.hostname);
      });
    }

    // First ungrouped devices
    result.addAll(sortDevices(devicesByGroup[null] ?? []));

    // Then grouped devices
    final sortedGroups =
        devicesByGroup.keys.where((g) => g != null).cast<String>().toList()
          ..sort();

    for (final groupName in sortedGroups) {
      result.addAll(sortDevices(devicesByGroup[groupName]!));
    }

    return result;
  }

  /// Get the position (1-based) of a device within its group
  int getDevicePositionInGroup(int deviceId) {
    final device = _devices.firstWhere((d) => d.id == deviceId);
    final group = device.deviceGroup;
    final groupDevices = _devices.where((d) => d.deviceGroup == group).toList()
      ..sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) return orderCompare;
        return a.hostname.compareTo(b.hostname);
      });
    return groupDevices.indexWhere((d) => d.id == deviceId) + 1;
  }

  /// Get total count of devices in a group
  int getDeviceCountInGroup(String? group) {
    return _devices.where((d) => d.deviceGroup == group).length;
  }

  /// Navigate to a specific device by its ID
  void navigateToDevice(int deviceId) {
    final navIndex = _getNavigationIndexForDevice(deviceId);
    if (navIndex >= 0) {
      _navigationIndex = navIndex;
    }
    _pendingNavigateDeviceId = deviceId;
    notifyListeners();
  }

  /// Calculate navigation index for a device
  /// Navigation structure: Project(0), Topology(1), Network Services(2), Devices expander(3),
  /// then device items starting at index 4, with separators and headers for groups
  int _getNavigationIndexForDevice(int deviceId) {
    final sorted = sortedDevices;
    final devicesByGroup = this.devicesByGroup;
    int navIndex = 4; // Start after Devices expander

    // Count items before this device
    final sortedGroups =
        devicesByGroup.keys.where((g) => g != null).cast<String>().toList()
          ..sort();

    // Check ungrouped devices first
    for (final d in sorted.where((d) => d.deviceGroup == null)) {
      if (d.id == deviceId) return navIndex;
      navIndex++;
    }

    // Check grouped devices
    for (final groupName in sortedGroups) {
      navIndex += 2; // separator + header
      for (final d in sorted.where((d) => d.deviceGroup == groupName)) {
        if (d.id == deviceId) return navIndex;
        navIndex++;
      }
    }

    return -1; // Not found
  }

  /// Count how many devices of a specific preset are in the current project
  int getDeviceCountByPreset(int presetId) {
    return _devices.where((d) => d.presetId == presetId).length;
  }

  /// Get remaining available slots for a preset (based on lab inventory)
  int getAvailableSlots(int presetId) {
    final maxCount = LabInventory.countByPresetId(presetId);
    final usedCount = getDeviceCountByPreset(presetId);
    return maxCount - usedCount;
  }

  /// Check if a preset has available slots
  bool isPresetAvailable(int presetId) {
    return getAvailableSlots(presetId) > 0;
  }

  /// Get all unique device groups in the current project
  List<String> get deviceGroups {
    final groups = _devices
        .map((d) => d.deviceGroup)
        .where((g) => g != null && g.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    groups.sort();
    return groups;
  }

  /// Get devices grouped by their device group
  /// Returns a map where key is group name (null for ungrouped) and value is list of devices
  Map<String?, List<NetDevice>> get devicesByGroup {
    final grouped = <String?, List<NetDevice>>{};
    for (final device in _devices) {
      final group = device.deviceGroup;
      grouped.putIfAbsent(group, () => []).add(device);
    }
    return grouped;
  }

  /// Update device group
  Future<void> updateDeviceGroup(int deviceId, String? groupName) async {
    await Database.updateDeviceConfig(deviceId, {
      'device_group': groupName?.isEmpty == true ? null : groupName,
    });
  }

  /// Rename a device group
  Future<void> renameDeviceGroup(String oldName, String newName) async {
    final devicesToUpdate = _devices.where((d) => d.deviceGroup == oldName);
    for (final device in devicesToUpdate) {
      await updateDeviceGroup(device.id, newName);
    }
  }

  /// Update device sort order
  Future<void> updateDeviceSortOrder(int deviceId, int sortOrder) async {
    await Database.updateDeviceConfig(deviceId, {'sort_order': sortOrder});
  }

  /// Move device up in sort order within its group
  Future<void> moveDeviceUp(int deviceId) async {
    final device = _devices.firstWhere((d) => d.id == deviceId);
    final group = device.deviceGroup;
    final groupDevices = _devices.where((d) => d.deviceGroup == group).toList()
      ..sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) return orderCompare;
        return a.hostname.compareTo(b.hostname);
      });

    final index = groupDevices.indexWhere((d) => d.id == deviceId);
    if (index <= 0) return; // Already at top

    // Check if this device is currently selected
    final wasSelected =
        _getNavigationIndexForDevice(deviceId) == _navigationIndex;

    // Swap sort orders with the device above
    final aboveDevice = groupDevices[index - 1];
    final currentOrder = device.sortOrder;
    final aboveOrder = aboveDevice.sortOrder;

    // If they have the same order, assign new orders
    if (currentOrder == aboveOrder) {
      await updateDeviceSortOrder(device.id, aboveOrder - 1);
    } else {
      await updateDeviceSortOrder(device.id, aboveOrder);
      await updateDeviceSortOrder(aboveDevice.id, currentOrder);
    }

    // If this device was selected, update navigation to follow it
    if (wasSelected) {
      // Navigation index decreases by 1 when moving up
      _navigationIndex = _navigationIndex - 1;
      notifyListeners();
    }
  }

  /// Move device down in sort order within its group
  Future<void> moveDeviceDown(int deviceId) async {
    final device = _devices.firstWhere((d) => d.id == deviceId);
    final group = device.deviceGroup;
    final groupDevices = _devices.where((d) => d.deviceGroup == group).toList()
      ..sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) return orderCompare;
        return a.hostname.compareTo(b.hostname);
      });

    final index = groupDevices.indexWhere((d) => d.id == deviceId);
    if (index < 0 || index >= groupDevices.length - 1)
      return; // Already at bottom

    // Check if this device is currently selected
    final wasSelected =
        _getNavigationIndexForDevice(deviceId) == _navigationIndex;

    // Swap sort orders with the device below
    final belowDevice = groupDevices[index + 1];
    final currentOrder = device.sortOrder;
    final belowOrder = belowDevice.sortOrder;

    // If they have the same order, assign new orders
    if (currentOrder == belowOrder) {
      await updateDeviceSortOrder(device.id, belowOrder + 1);
    } else {
      await updateDeviceSortOrder(device.id, belowOrder);
      await updateDeviceSortOrder(belowDevice.id, currentOrder);
    }

    // If this device was selected, update navigation to follow it
    if (wasSelected) {
      // Navigation index increases by 1 when moving down
      _navigationIndex = _navigationIndex + 1;
      notifyListeners();
    }
  }

  /// Get all available presets (those with remaining slots)
  List<DevicePreset> get availablePresets {
    return DevicePresets.all.where((p) => isPresetAvailable(p.id)).toList();
  }

  /// Get available presets grouped by category
  Map<String, List<DevicePreset>> get availablePresetsByCategory {
    final result = <String, List<DevicePreset>>{};
    for (final entry in DevicePresets.byCategory.entries) {
      final availableInCategory = entry.value
          .where((p) => isPresetAvailable(p.id))
          .toList();
      if (availableInCategory.isNotEmpty) {
        result[entry.key] = availableInCategory;
      }
    }
    return result;
  }

  void setUser(KtUser? user) {
    _currentUser = user;
    notifyListeners();
  }

  void setProjects(List<Project> projects) {
    _projects = projects;
    notifyListeners();
  }

  /// Called when LockService notifies of changes
  void _onLockServiceChanged() {
    debugPrint('AppState: LockService changed, notifying listeners');
    notifyListeners();
  }

  Future<void> selectProject(Project? project) async {
    _selectedProject = project;
    _pendingDeleteIds.clear(); // Clear pending deletes when switching projects
    notifyListeners();

    await _devicesSubscription?.cancel();
    _devicesSubscription = null;

    await _projectSubscription?.cancel();
    _projectSubscription = null;

    _deviceController?.dispose();
    _deviceController = null;

    _lockService?.removeListener(_onLockServiceChanged);
    _lockService?.dispose();
    _lockService = null;

    if (project != null) {
      _deviceController = DeviceController(
        Supabase.instance.client,
        project.id,
      );
      _deviceController!.initialize();

      // Initialize lock service for this project with gRPC client
      _lockService = LockService(
        Supabase.instance.client,
        project.id,
        grpcClient: _grpcClient,
      );
      await _lockService!.initialize();
      _lockService!.addListener(_onLockServiceChanged);

      _devicesSubscription = Database.getDevicesStream(project.id).listen((
        devices,
      ) {
        // Filter out devices that are pending deletion
        _devices = devices
            .where((d) => !_pendingDeleteIds.contains(d.id))
            .toList();
        // Remove confirmed deleted IDs (those no longer in stream)
        final currentIds = devices.map((d) => d.id).toSet();
        _pendingDeleteIds.removeWhere((id) => !currentIds.contains(id));
        notifyListeners();
      });

      // Subscribe to project properties changes (OSPF, EIGRP, etc.)
      _projectSubscription = Supabase.instance.client
          .from('projects_v2')
          .stream(primaryKey: ['id'])
          .eq('id', project.id)
          .listen((data) {
            if (data.isNotEmpty) {
              final row = data.first;
              final newProperties = row['properties'] as Map<String, dynamic>?;
              if (newProperties != null) {
                _selectedProject = Project.fromJson(row);
                notifyListeners();
              }
            }
          });
    } else {
      _devices = [];
      notifyListeners();
    }
  }

  /// Generate the next available hostname for a device category
  /// Switches get S1, S2, S3... Routers get R1, R2, R3...
  String _generateHostname(int presetId) {
    final preset = DevicePresets.getById(presetId);

    final prefix = switch (preset.category) {
      NetDeviceCategory.Switch => 'S',
      NetDeviceCategory.Router => 'R',
      NetDeviceCategory.AccessPoint => 'AP',
      NetDeviceCategory.Firewall => 'FW',
      NetDeviceCategory.Server => 'SRV',
      NetDeviceCategory.PC => 'PC',
    };

    // Find the highest number used for this prefix
    final existingNumbers = _devices
        .where((d) {
          final h = d.hostname;
          return h.startsWith(prefix) &&
              int.tryParse(h.substring(prefix.length)) != null;
        })
        .map((d) => int.parse(d.hostname.substring(prefix.length)))
        .toList();

    final nextNumber = existingNumbers.isEmpty
        ? 1
        : (existingNumbers.reduce((a, b) => a > b ? a : b) + 1);
    return '$prefix$nextNumber';
  }

  /// Add a new device to the current project
  /// Optionally pass [hostname] and [realId] to link to a specific lab device
  /// Automatically attempts to acquire a lock for the new device
  Future<NetDevice?> addDevice(
    int presetId, {
    String? hostname,
    int? realId,
  }) async {
    print("Adding device with preset ID: $presetId");
    if (_selectedProject == null) return null;

    final deviceHostname = hostname ?? _generateHostname(presetId);
    final config = <String, dynamic>{'hostname': deviceHostname};

    final device = await Database.saveDevice(
      NetDevice(
        id: -1,
        projectId: _selectedProject!.id,
        presetId: presetId,
        realId: realId,
        config: config,
      ),
    );

    // Try to acquire a lock for the new device
    if (_lockService != null) {
      final lockAcquired = await _lockService!.requestLock(device.id);
      print("Lock acquired for device ${device.id}: $lockAcquired");
    }

    return device;
  }

  /// Request a lock for a device (for retry after failed auto-lock)
  Future<bool> requestDeviceLock(int deviceId) async {
    if (_lockService == null) return false;
    return await _lockService!.requestLock(deviceId);
  }

  /// Release a lock for a device
  Future<bool> releaseDeviceLock(int deviceId) async {
    if (_lockService == null) return false;
    return await _lockService!.releaseLock(deviceId);
  }

  /// Delete a device from the current project
  /// Set [navigate] to false to stay on the current page (e.g., when deleting from topology view)
  Future<void> deleteDevice(int deviceId, {bool navigate = true}) async {
    // Add to pending deletes to filter from stream updates
    _pendingDeleteIds.add(deviceId);

    // Release lock before deleting
    if (_lockService != null && _lockService!.hasLock(deviceId)) {
      await _lockService!.releaseLock(deviceId);
    }

    // Remove from local state immediately for responsive UI
    _devices = _devices.where((d) => d.id != deviceId).toList();

    // Navigate back to project page after deletion (unless explicitly disabled)
    if (navigate) {
      _navigationIndex = 0;
      _pendingNavigateToHome = true;
    }
    notifyListeners();

    // Delete from database - stream will confirm and we'll clean up _pendingDeleteIds
    await Database.deleteDevice(deviceId);
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _projectSubscription?.cancel();
    _projectsListSubscription?.cancel();
    _authSubscription?.cancel();
    if (_projectChangesChannel != null) {
      Supabase.instance.client.removeChannel(_projectChangesChannel!);
      _projectChangesChannel = null;
    }
    _deviceController?.dispose();
    _lockService?.dispose();
    _grpcClient?.disconnect();
    _grpcReconnectTimer?.cancel();
    _supabaseReconnectTimer?.cancel();
    super.dispose();
  }

  /// Subscribe to the teams table for real-time project list updates
  /// This handles: user being invited to a project, removed from a project, etc.
  void _subscribeToProjectsList() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _projectsListSubscription?.cancel();
    _projectsListSubscription = Supabase.instance.client
        .from('teams')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((teamsData) async {
          // Reload projects when team membership changes
          await _reloadProjects();
        });

    // Also subscribe to projects_v2 changes for name/property updates
    // This uses a channel to listen for all changes on projects the user has access to
    _subscribeToProjectChanges();
  }

  /// Subscribe to project changes (name, properties, etc.)
  void _subscribeToProjectChanges() {
    if (_projectChangesChannel != null) {
      Supabase.instance.client.removeChannel(_projectChangesChannel!);
      _projectChangesChannel = null;
    }

    _projectChangesChannel = Supabase.instance.client.channel(
      'projects-changes',
    );

    _projectChangesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'projects_v2',
          callback: (payload) {
            final updatedProject = Project.fromJson(payload.newRecord);

            // Update in the projects list
            final index = _projects.indexWhere(
              (p) => p.id == updatedProject.id,
            );
            if (index >= 0) {
              _projects[index] = updatedProject;

              // Also update selectedProject if it's the same project
              if (_selectedProject?.id == updatedProject.id) {
                _selectedProject = updatedProject;
              }

              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'projects_v2',
          callback: (payload) {
            final deletedId = payload.oldRecord['id'] as int?;
            if (deletedId != null) {
              _projects.removeWhere((p) => p.id == deletedId);

              // If the deleted project was selected, select another one
              if (_selectedProject?.id == deletedId) {
                selectProject(_projects.isNotEmpty ? _projects.first : null);
              }

              notifyListeners();
            }
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            debugPrint(
              'projects-changes channel error (status=$status): $error',
            );
          }
        });
  }

  /// Reload projects from the database
  Future<void> _reloadProjects() async {
    try {
      final newProjects = await Database.loadProjects();

      // Check if selected project still exists
      final selectedStillExists =
          _selectedProject != null &&
          newProjects.any((p) => p.id == _selectedProject!.id);

      _projects = newProjects;

      if (!selectedStillExists) {
        // Selected project was removed, select another one
        await selectProject(_projects.isNotEmpty ? _projects.first : null);
      }

      notifyListeners();
    } catch (e) {
      print("Error reloading projects: $e");
    }
  }

  /// Handle auth state changes (login/logout)
  Future<void> _onAuthStateChange(AuthState data) async {
    final newUser = await Database.getCurrentUser();
    final previousUserId = _currentUser?.id;
    _currentUser = newUser;

    print("Auth state changed: ${data.event}");
    print("User: ${newUser?.name}");

    if (newUser == null) {
      // User logged out - clear all state
      await _clearAllState();
      notifyListeners();
      return;
    }

    // If user changed (different user logged in) or user just logged in
    if (previousUserId != newUser.id ||
        data.event == AuthChangeEvent.signedIn) {
      await _initializeForUser();
    }

    notifyListeners();
  }

  /// Clear all state when user logs out
  Future<void> _clearAllState() async {
    await _devicesSubscription?.cancel();
    _devicesSubscription = null;

    await _projectSubscription?.cancel();
    _projectSubscription = null;

    await _projectsListSubscription?.cancel();
    _projectsListSubscription = null;

    if (_projectChangesChannel != null) {
      await Supabase.instance.client.removeChannel(_projectChangesChannel!);
      _projectChangesChannel = null;
    }

    _deviceController?.dispose();
    _deviceController = null;

    _lockService?.removeListener(_onLockServiceChanged);
    _lockService?.dispose();
    _lockService = null;

    await _grpcClient?.disconnect();
    _grpcClient = null;

    _projects = [];
    _selectedProject = null;
    _devices = [];
    _pendingDeleteIds.clear();
    _navigationIndex = 0;
  }

  /// Initialize state for the current user
  Future<void> _initializeForUser() async {
    _projects = await Database.loadProjects();

    // Subscribe to projects list changes
    _subscribeToProjectsList();

    if (_projects.isNotEmpty) {
      await selectProject(_projects.first);
    } else {
      await selectProject(null);
    }
  }

  Future<void> init() async {
    // Initialize Supabase connection check and lab config (don't notify during init)
    await _initializeSupabase(notify: false);

    // Initialize gRPC client (non-blocking, don't notify during init)
    _initializeGrpc(notify: false);

    // Set up auth state listener
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      _onAuthStateChange,
    );

    // Only proceed with user initialization if Supabase is connected
    if (_supabaseStatus == ConnectionStatus.connected) {
      _currentUser = await Database.getCurrentUser();
      if (_currentUser == null) {
        print("No current user found during init.");
        // Don't notify here - FutureBuilder will rebuild when init() completes
        return;
      }

      await _initializeForUser();
    }
    // Don't notify here - FutureBuilder will rebuild when init() completes
  }

  /// Initialize Supabase connection
  /// [notify] controls whether to call notifyListeners (set to false during initial init)
  Future<void> _initializeSupabase({bool notify = true}) async {
    _supabaseStatus = ConnectionStatus.connecting;
    _supabaseError = null;
    if (notify) notifyListeners();

    try {
      // Initialize lab configuration from Supabase (must be done before using inventory/constraints)
      await LabConfig.initialize();

      _supabaseStatus = ConnectionStatus.connected;
      _supabaseError = null;
      print('Supabase connected successfully');
    } catch (e) {
      _supabaseStatus = ConnectionStatus.error;
      _supabaseError = e.toString();
      print('Failed to connect to Supabase: $e');
      _scheduleSupabaseReconnect();
    }
    if (notify) notifyListeners();
  }

  /// Initialize gRPC connection (non-blocking)
  /// [notify] controls whether to call notifyListeners (set to false during initial init)
  void _initializeGrpc({bool notify = true}) {
    _grpcStatus = ConnectionStatus.connecting;
    _grpcError = null;
    if (notify) notifyListeners();

    _grpcClient = DeviceManagerClient();
    _grpcClient!
        .connect()
        .then((_) {
          _grpcStatus = ConnectionStatus.connected;
          _grpcError = null;
          print('gRPC client connected to Device Manager');
          notifyListeners();
        })
        .catchError((e) {
          _grpcStatus = ConnectionStatus.error;
          _grpcError = e.toString();
          print('Failed to connect to Device Manager gRPC server: $e');
          _scheduleGrpcReconnect();
          notifyListeners();
        });
  }

  /// Schedule a gRPC reconnection attempt
  void _scheduleGrpcReconnect() {
    if (_mockGrpcConnected) return;
    _grpcReconnectTimer?.cancel();
    _grpcReconnectTimer = Timer(const Duration(seconds: 10), () {
      if (!_mockGrpcConnected && _grpcStatus != ConnectionStatus.connected) {
        print('Attempting gRPC reconnection...');
        _initializeGrpc();
      }
    });
  }

  /// Schedule a Supabase reconnection attempt
  void _scheduleSupabaseReconnect() {
    _supabaseReconnectTimer?.cancel();
    _supabaseReconnectTimer = Timer(const Duration(seconds: 10), () {
      if (_supabaseStatus != ConnectionStatus.connected) {
        print('Attempting Supabase reconnection...');
        _retrySupabaseConnection();
      }
    });
  }

  /// Retry Supabase connection
  Future<void> _retrySupabaseConnection() async {
    await _initializeSupabase();
    if (_supabaseStatus == ConnectionStatus.connected && _currentUser == null) {
      _currentUser = await Database.getCurrentUser();
      if (_currentUser != null) {
        await _initializeForUser();
      }
    }
    notifyListeners();
  }

  /// Manually retry gRPC connection
  void retryGrpcConnection() {
    _grpcReconnectTimer?.cancel();
    _initializeGrpc();
  }

  /// Manually retry Supabase connection
  Future<void> retrySupabaseConnection() async {
    _supabaseReconnectTimer?.cancel();
    await _retrySupabaseConnection();
  }
}
