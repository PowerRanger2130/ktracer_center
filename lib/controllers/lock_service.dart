// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:ktracer_center/devices/system_constraints.dart';
import 'package:ktracer_center/grpc/grpc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generate a simple unique numeric ID (timestamp + random)
int _generateId() {
  final random = Random();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomPart = random.nextInt(999999);
  // Return as pure numeric string for bigint compatibility
  return int.parse('$timestamp${randomPart.toString().padLeft(6, '0')}');
}

/// Lock status for a device
enum DeviceLockStatus { unlocked, lockedByMe, lockedByOther, pending }

/// Represents a project-level device lock
/// System locks have null project_id, device_id, user_id - they just reserve a real_id
class DeviceLock {
  final int? deviceId; // Nullable for system locks
  final int? projectId; // Nullable for system locks
  final int? clientId; // Optional - tracks who requested the lock
  final String? userId; // Nullable for system locks
  final DateTime lockedAt;
  final int? realId; // Assigned physical device ID

  DeviceLock({
    this.deviceId,
    this.projectId,
    this.clientId,
    this.userId,
    required this.lockedAt,
    this.realId,
  });

  /// Returns true if this is a system lock (reserves a real_id without a project)
  bool get isSystemLock => projectId == null || projectId == 0;

  factory DeviceLock.fromJson(Map<String, dynamic> json) {
    print('DeviceLock.fromJson: $json');
    return DeviceLock(
      deviceId: _parseNullableInt(json['device_id']),
      projectId: _parseNullableInt(json['project_id']),
      clientId: _parseNullableInt(json['client_id']),
      userId: json['user_id']?.toString(),
      lockedAt: DateTime.parse(json['locked_at']),
      realId: _parseNullableInt(json['real_id']),
    );
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    final str = value.toString();
    if (str.isEmpty || str == 'null') return null;
    return int.tryParse(str);
  }
}

/// Service to manage device locks via gRPC and Supabase
///
/// Locks are PROJECT-based, not client-based. Once a lock is acquired for a device
/// in a project, it persists until explicitly released - it does NOT release when
/// individual clients disconnect.
///
/// Lock requests go through gRPC to the Dart Device Manager service.
/// Lock state is synced via Supabase realtime subscriptions.
class LockService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final int _projectId;
  final DeviceManagerClient? _grpcClient;

  /// Unique identifier for this client instance
  late final int _clientId;

  RealtimeChannel? _channel;

  /// Stream subscription for device_locks table
  StreamSubscription<List<Map<String, dynamic>>>? _locksSubscription;

  /// Current locks for devices in this project
  final Map<int, DeviceLock> _deviceLocks = {};

  /// ALL locks across all projects (for checking global availability)
  final Map<int, DeviceLock> _allLocks = {};

  /// Pending lock requests (request_id -> completer)
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};

  /// Device status tracking (device_id -> status)
  /// Status values: 'connecting', 'configuring', 'ready', 'error'
  final Map<int, String> _deviceStatus = {};

  /// Device status messages (device_id -> message)
  final Map<int, String> _deviceStatusMessages = {};

  /// Whether the service is connected
  bool _isConnected = false;

  /// Returns true if connected via gRPC or Supabase broadcast
  bool get isConnected => (_grpcClient?.isConnected ?? false) || _isConnected;

  /// Whether gRPC is the active connection method
  bool get isGrpcConnected => _grpcClient?.isConnected ?? false;

  /// Whether we're currently reconnecting
  bool _isReconnecting = false;

  /// Whether we're intentionally cleaning up (ignore close events)
  bool _isCleaningUp = false;

  /// Whether the service has been disposed
  bool _isDisposed = false;

  /// Reconnection attempts counter
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  /// Get all current device locks for this project
  Map<int, DeviceLock> get deviceLocks => Map.unmodifiable(_deviceLocks);

  /// Get all locks across all projects
  Map<int, DeviceLock> get allLocks => Map.unmodifiable(_allLocks);

  /// Get device status map
  Map<int, String> get deviceStatus => Map.unmodifiable(_deviceStatus);

  LockService(
    this._supabase,
    this._projectId, {
    DeviceManagerClient? grpcClient,
  }) : _grpcClient = grpcClient {
    _clientId = _generateId();
  }

  /// Get the current user ID
  String? get _userId => _supabase.auth.currentUser?.id;

  /// Initialize the lock service - connect to presence and subscribe to responses
  Future<void> initialize() async {
    if (_isConnected || _isDisposed) return;

    debugPrint(
      'LockService: Initializing for project $_projectId with client $_clientId',
    );

    // Load existing locks
    await _loadExistingLocks();

    // Set up GLOBAL channel for lock broadcasts
    // Must match Python's channel name: 'locks:global'
    const channelName = 'global';
    _channel = _supabase.channel(channelName);

    _channel!.onPresenceSync((payload) {
      debugPrint('LockService: Presence sync');
    });

    _channel!.onPresenceJoin((payload) {
      debugPrint('LockService: Presence join: $payload');
    });

    _channel!.onPresenceLeave((payload) {
      debugPrint('LockService: Presence leave: $payload');
    });

    // Listen for lock responses via broadcast (on same channel)
    _channel!.onBroadcast(
      event: 'lock_response',
      callback: (payload) {
        debugPrint('LockService: Received lock_response broadcast: $payload');
        _handleLockResponse(payload);
      },
    );

    // Listen for device status updates via broadcast
    _channel!.onBroadcast(
      event: 'device_status',
      callback: (payload) {
        debugPrint('LockService: Received device_status broadcast: $payload');
        _handleDeviceStatus(payload);
      },
    );

    _channel!.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Track this client's presence
        await _channel!.track({
          'client_id': _clientId,
          'type': 'flutter',
          'user_id': _userId ?? 'unknown',
          'project_id': _projectId,
        });
        debugPrint('LockService: Presence tracked on $channelName');
      } else if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint('LockService: Presence channel error: $error');
        if (!_isCleaningUp) _handleChannelError();
      } else if (status == RealtimeSubscribeStatus.closed) {
        debugPrint('LockService: Presence channel closed');
        // Only handle if not intentional cleanup
        if (!_isCleaningUp && !_isReconnecting) _handleChannelError();
      }
    });

    // Subscribe to device_locks table using .stream() for real-time updates
    _locksSubscription = _supabase
        .from('device_locks')
        .stream(primaryKey: ['id'])
        //.eq('project_id', _projectId)
        .listen(
          (data) {
            debugPrint(
              'LockService: Locks stream update: ${data.length} locks',
            );
            _handleLocksStreamUpdate(data);
          },
          onError: (error) {
            debugPrint('LockService: Locks stream error: $error');
            if (!_isCleaningUp && !_isReconnecting) _handleChannelError();
          },
        );
    debugPrint('LockService: Subscribed to device_locks stream');

    _isConnected = true;
    _reconnectAttempts = 0; // Reset only after full successful init
    notifyListeners();
    debugPrint(
      'LockService: Initialized with presence, messages, and locks channels',
    );
  }

  /// Handle channel errors by attempting to reconnect
  void _handleChannelError() {
    if (_isDisposed || _isReconnecting || _isCleaningUp) return;

    _isConnected = false;
    notifyListeners();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('LockService: Max reconnection attempts reached');
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;

    final delay = _reconnectDelay * _reconnectAttempts;
    debugPrint(
      'LockService: Scheduling reconnection in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    Future.delayed(delay, () async {
      await _reconnect();
    });
  }

  /// Reconnect all channels
  Future<void> _reconnect() async {
    if (!_isReconnecting) return; // Safety check

    debugPrint('LockService: Reconnecting...');

    // Clean up existing subscriptions
    await _cleanup();

    // Re-initialize
    try {
      await initialize();
      _isReconnecting = false;
      debugPrint('LockService: Reconnection successful');
    } catch (e) {
      debugPrint('LockService: Reconnection failed: $e');
      _isReconnecting = false;
      _handleChannelError();
    }
  }

  /// Clean up existing subscriptions without disposing
  Future<void> _cleanup() async {
    _isCleaningUp = true;

    _locksSubscription?.cancel();
    _locksSubscription = null;

    try {
      await _channel?.unsubscribe();
    } catch (e) {
      debugPrint('LockService: Error unsubscribing presence: $e');
    }
    _channel = null;

    _isConnected = false;
    _isCleaningUp = false;
  }

  /// Handle device_locks stream updates
  /// This receives ALL locks from the database (across all projects)
  void _handleLocksStreamUpdate(List<Map<String, dynamic>> data) {
    if (_isDisposed) return;
    _deviceLocks.clear();
    _allLocks.clear();

    for (final lockData in data) {
      try {
        final lock = DeviceLock.fromJson(lockData);
        // Skip system locks (no deviceId) for the device-based maps
        if (lock.deviceId == null) continue;
        // Add to all locks map
        _allLocks[lock.deviceId!] = lock;
        // Add to project-specific map if it belongs to this project
        if (lock.projectId == _projectId) {
          _deviceLocks[lock.deviceId!] = lock;
        }
      } catch (e) {
        debugPrint('LockService: Error parsing lock record: $e');
      }
    }
    debugPrint(
      'LockService: Updated locks - this project: ${_deviceLocks.length}, all: ${_allLocks.length}',
    );
    notifyListeners();
  }

  /// Load existing locks from database (ALL locks, not just this project)
  Future<void> _loadExistingLocks() async {
    if (_isDisposed) return;
    try {
      // Load ALL locks to track global availability
      final allResponse = await _supabase.from('device_locks').select();

      print('LockService: Loading all locks: ${allResponse.length} total');

      _deviceLocks.clear();
      _allLocks.clear();

      for (final lockData in allResponse) {
        final lock = DeviceLock.fromJson(lockData);
        // Skip system locks (no deviceId) for the device-based maps
        if (lock.deviceId == null) continue;
        _allLocks[lock.deviceId!] = lock;
        if (lock.projectId == _projectId) {
          _deviceLocks[lock.deviceId!] = lock;
        }
      }
      debugPrint(
        'LockService: Loaded ${_deviceLocks.length} project locks, ${_allLocks.length} total locks',
      );
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('LockService: Could not load existing locks: $e');
    }
  }

  /// Handle a lock response from the Python service (via messages table)
  void _handleLockResponse(Map<String, dynamic> message) {
    // Broadcast payload comes directly, not wrapped in 'payload' key
    final payload = message['payload'] as Map<String, dynamic>? ?? message;

    final requestId = payload['request_id'] as int?;
    final deviceId = payload['device_id'] as int?;
    final success = payload['success'] as bool? ?? false;
    final action =
        payload['action'] as String?; // 'release' for unlock responses

    debugPrint(
      'LockService: Lock response - request=$requestId, device=$deviceId, success=$success, action=$action',
    );

    // If lock was granted, immediately set status to 'connecting'
    // This ensures UI shows spinner before device_status broadcasts arrive
    if (success && deviceId != null && action != 'release') {
      _deviceStatus[deviceId] = 'connecting';
      _deviceStatusMessages[deviceId] = 'Connecting to device...';
      debugPrint('LockService: Pre-set device $deviceId status to connecting');
    }

    // If lock was released, clear the device status
    if (success && deviceId != null && action == 'release') {
      _deviceStatus.remove(deviceId);
      _deviceStatusMessages.remove(deviceId);
      debugPrint('LockService: Cleared device $deviceId status on release');
    }

    // Complete the pending request if exists
    if (requestId != null && _pendingRequests.containsKey(requestId)) {
      _pendingRequests[requestId]!.complete(payload);
      _pendingRequests.remove(requestId);
    }

    // Note: Lock state updates are handled via realtime subscription to device_locks table
    // No need to manually update _deviceLocks here
  }

  /// Handle device status updates from Python service
  void _handleDeviceStatus(Map<String, dynamic> message) {
    // Broadcast payload comes directly, not wrapped in 'payload' key
    final payload = message['payload'] as Map<String, dynamic>? ?? message;

    final deviceId = payload['device_id'] as int?;
    final status = payload['status'] as String?;
    final statusMessage = payload['message'] as String?;

    if (deviceId == null || status == null) {
      debugPrint('LockService: Invalid device status message: $payload');
      return;
    }

    final previousStatus = _deviceStatus[deviceId];
    debugPrint(
      'LockService: Device $deviceId status changed: $previousStatus -> $status ($statusMessage)',
    );

    _deviceStatus[deviceId] = status;
    if (statusMessage != null) {
      _deviceStatusMessages[deviceId] = statusMessage;
    }

    // Force immediate notify for UI update
    notifyListeners();
  }

  /// Get status for a specific device
  /// Returns: 'connecting', 'configuring', 'ready', 'error', or null if no status
  String? getDeviceStatus(int deviceId) => _deviceStatus[deviceId];

  /// Get status message for a specific device
  String? getDeviceStatusMessage(int deviceId) =>
      _deviceStatusMessages[deviceId];

  /// Check if a device is currently being configured (connecting or configuring)
  bool isDeviceConfiguring(int deviceId) {
    final status = _deviceStatus[deviceId];
    return status == 'connecting' || status == 'configuring';
  }

  /// Check if a device is ready
  bool isDeviceReady(int deviceId) => _deviceStatus[deviceId] == 'ready';

  /// Check if a device has an error
  bool isDeviceError(int deviceId) => _deviceStatus[deviceId] == 'error';

  /// Request a lock for a device
  ///
  /// Returns true if lock was granted, false otherwise
  Future<bool> requestLock(int deviceId) async {
    // Prefer gRPC if available
    if (_grpcClient != null && _grpcClient.isConnected) {
      return _requestLockViaGrpc(deviceId);
    }

    // Fallback to broadcast (legacy)
    return _requestLockViaBroadcast(deviceId);
  }

  /// Request lock via gRPC (preferred method)
  Future<bool> _requestLockViaGrpc(int deviceId) async {
    debugPrint('LockService: Requesting lock via gRPC for device $deviceId');

    try {
      // Set connecting status before the request
      _deviceStatus[deviceId] = 'connecting';
      _deviceStatusMessages[deviceId] = 'Requesting lock...';
      notifyListeners();

      // Get the preset ID from the device (we need to look it up)
      // For now, we'll use 0 as a placeholder - the server should handle this
      final response = await _grpcClient!.lockDevice(
        deviceId: deviceId,
        projectId: _projectId,
        presetId: 0, // Server will look up the preset from device
        reason: 'Flutter client lock request',
      );

      if (response.success) {
        debugPrint(
          'LockService: gRPC lock granted for device $deviceId, realId=${response.assignedRealId}',
        );

        // Create a local lock record (will be synced via realtime shortly)
        final lock = DeviceLock(
          deviceId: deviceId,
          projectId: _projectId,
          clientId: _clientId,
          userId: _userId,
          lockedAt: DateTime.now(),
          realId: response.assignedRealId,
        );
        _deviceLocks[deviceId] = lock;
        _allLocks[deviceId] = lock;

        // Set status to ready - the gRPC server manages device connections,
        // so if lock is granted, the device is available
        _deviceStatus[deviceId] = 'ready';
        _deviceStatusMessages[deviceId] = 'Device ready';
        notifyListeners();
        return true;
      } else {
        debugPrint(
          'LockService: gRPC lock denied for device $deviceId: ${response.error}',
        );
        // Clear the status on failure
        _deviceStatus.remove(deviceId);
        _deviceStatusMessages.remove(deviceId);
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('LockService: gRPC lock request failed: $e');
      // Clear the status on error
      _deviceStatus.remove(deviceId);
      _deviceStatusMessages.remove(deviceId);
      notifyListeners();
      return false;
    }
  }

  /// Request lock via Supabase broadcast (fallback method)
  Future<bool> _requestLockViaBroadcast(int deviceId) async {
    if (!_isConnected || _channel == null) {
      debugPrint('LockService: Not connected, cannot request lock');
      return false;
    }

    final requestId = _generateId();
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    debugPrint(
      'LockService: Requesting lock via broadcast for device $deviceId',
    );

    // Send lock request via broadcast
    try {
      await _channel!.sendBroadcastMessage(
        event: 'lock_request',
        payload: {
          'payload': {
            'device_id': deviceId,
            'project_id': _projectId,
            'client_id': _clientId,
            'user_id': _userId,
            'request_id': requestId,
          },
        },
      );
      debugPrint(
        'LockService: Sent lock_request broadcast for device $deviceId',
      );
    } catch (e) {
      debugPrint('LockService: Failed to send lock request: $e');
      _pendingRequests.remove(requestId);
      return false;
    }

    // Wait for response with timeout
    try {
      final response = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => {'success': false, 'error': 'timeout'},
      );

      final success = response['success'] as bool? ?? false;
      if (success) {
        debugPrint('LockService: Lock granted for device $deviceId');
        // Lock state will be updated via realtime subscription to device_locks
      } else {
        debugPrint(
          'LockService: Lock denied for device $deviceId: ${response['error']}',
        );
      }
      return success;
    } catch (e) {
      debugPrint('LockService: Error waiting for lock response: $e');
      _pendingRequests.remove(requestId);
      return false;
    }
  }

  /// Release a lock for a device
  Future<bool> releaseLock(int deviceId) async {
    // Prefer gRPC if available
    if (_grpcClient != null && _grpcClient.isConnected) {
      return _releaseLockViaGrpc(deviceId);
    }

    // Fallback to broadcast (legacy)
    return _releaseLockViaBroadcast(deviceId);
  }

  /// Release lock via gRPC (preferred method)
  Future<bool> _releaseLockViaGrpc(int deviceId) async {
    debugPrint('LockService: Releasing lock via gRPC for device $deviceId');

    try {
      final response = await _grpcClient!.unlockDevice(deviceId);

      if (response.success) {
        debugPrint('LockService: gRPC lock released for device $deviceId');
        // Remove lock from local state
        _deviceLocks.remove(deviceId);
        _allLocks.remove(deviceId);
        // Clear device status
        _deviceStatus.remove(deviceId);
        _deviceStatusMessages.remove(deviceId);
        notifyListeners();
        return true;
      } else {
        debugPrint(
          'LockService: gRPC unlock failed for device $deviceId: ${response.error}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('LockService: gRPC unlock request failed: $e');
      return false;
    }
  }

  /// Release lock via Supabase broadcast (fallback method)
  Future<bool> _releaseLockViaBroadcast(int deviceId) async {
    if (!_isConnected) {
      debugPrint('LockService: Not connected, cannot release lock');
      return false;
    }

    final requestId = _generateId();
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;

    debugPrint('LockService: Releasing lock for device $deviceId');

    // Send release request via broadcast
    try {
      await _channel!.sendBroadcastMessage(
        event: 'lock_release',
        payload: {
          'payload': {
            'device_id': deviceId,
            'project_id': _projectId,
            'client_id': _clientId,
            'user_id': _userId,
            'request_id': requestId,
          },
        },
      );
      debugPrint(
        'LockService: Sent lock_release broadcast for device $deviceId',
      );
    } catch (e) {
      debugPrint('LockService: Failed to send release request: $e');
      _pendingRequests.remove(requestId);
      return false;
    }

    // Wait for response with timeout
    try {
      final response = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => {'success': false, 'error': 'timeout'},
      );

      final success = response['success'] as bool? ?? false;
      if (success) {
        debugPrint('LockService: Lock released for device $deviceId');
        // Lock state will be updated via realtime subscription to device_locks
      }
      return success;
    } catch (e) {
      debugPrint('LockService: Error waiting for release response: $e');
      _pendingRequests.remove(requestId);
      return false;
    }
  }

  /// Get the lock status for a device
  /// Since locks are project-based, if a lock exists for this project, we consider it "ours"
  DeviceLockStatus getLockStatus(int deviceId) {
    final lock = _deviceLocks[deviceId];
    if (lock == null) return DeviceLockStatus.unlocked;
    // Lock exists in this project = project has the lock
    return DeviceLockStatus.lockedByMe;
  }

  /// Check if this project holds the lock for a device
  /// Since locks are project-based, any lock in _deviceLocks belongs to this project
  bool hasLock(int deviceId) {
    return _deviceLocks.containsKey(deviceId);
  }

  /// Check if a device is locked by anyone in this project
  bool isLocked(int deviceId) {
    return _deviceLocks.containsKey(deviceId);
  }

  /// Get the lock holder info for a device (in this project)
  DeviceLock? getLock(int deviceId) {
    return _deviceLocks[deviceId];
  }

  /// Get all locked real_ids across ALL projects for a given preset
  /// This is used to determine if there are any physical devices of a type still available
  /// Also includes system-reserved devices that cannot be assigned
  Set<int> getLockedRealIdsForPreset(int presetId, List<int> labRealIds) {
    final lockedRealIds = <int>{};

    // Add system-reserved devices first (they are never available)
    for (final realId in labRealIds) {
      if (isDeviceReserved(realId)) {
        lockedRealIds.add(realId);
      }
    }

    // Then add project-locked devices
    for (final lock in _allLocks.values) {
      if (lock.realId != null && labRealIds.contains(lock.realId)) {
        lockedRealIds.add(lock.realId!);
      }
    }
    return lockedRealIds;
  }

  /// Get locks from OTHER projects (not this one) that have locked real_ids for a preset
  List<DeviceLock> getOtherProjectLocksForPreset(
    int presetId,
    List<int> labRealIds,
  ) {
    return _allLocks.values
        .where(
          (lock) =>
              lock.projectId != _projectId &&
              lock.realId != null &&
              labRealIds.contains(lock.realId),
        )
        .toList();
  }

  /// Get how many physical devices of a preset are available (not locked by any project or system)
  /// This counts devices not locked by ANY project (including this one)
  /// Also excludes system-reserved devices from the total count
  int getAvailableCountForPreset(int presetId, List<int> labRealIds) {
    final allLocked = getAllLockedRealIds(labRealIds);
    final systemLocked = getSystemLockedRealIds(labRealIds);
    // Total available = total devices - system reserved - locked by any project
    // Note: allLocked includes project locks, systemLocked is separate
    return labRealIds.length - systemLocked.length - allLocked.length;
  }

  /// Get all real_ids that are locked by ANY project (not system locks)
  Set<int> getAllLockedRealIds(List<int> labRealIds) {
    final lockedRealIds = <int>{};

    for (final lock in _allLocks.values) {
      if (!lock.isSystemLock &&
          lock.realId != null &&
          labRealIds.contains(lock.realId)) {
        lockedRealIds.add(lock.realId!);
      }
    }
    return lockedRealIds;
  }

  /// Get all real_ids that are system-locked (projectId is null)
  Set<int> getSystemLockedRealIds(List<int> labRealIds) {
    final systemLockedRealIds = <int>{};

    // System locks have null projectId
    for (final lock in _allLocks.values) {
      if (lock.isSystemLock &&
          lock.realId != null &&
          labRealIds.contains(lock.realId)) {
        systemLockedRealIds.add(lock.realId!);
      }
    }

    // Also add statically reserved devices
    for (final realId in labRealIds) {
      if (isDeviceReserved(realId)) {
        systemLockedRealIds.add(realId);
      }
    }

    return systemLockedRealIds;
  }

  /// Get all real_ids locked by OTHER projects (not this one, not system locks) for a given preset
  /// This is used to show how many physical devices are available to lock
  Set<int> getLockedRealIdsByOtherProjects(int presetId, List<int> labRealIds) {
    final lockedRealIds = <int>{};

    // Only add devices locked by OTHER projects (not system locks, not our project)
    for (final lock in _allLocks.values) {
      if (!lock.isSystemLock &&
          lock.projectId != _projectId &&
          lock.realId != null &&
          labRealIds.contains(lock.realId)) {
        lockedRealIds.add(lock.realId!);
      }
    }
    return lockedRealIds;
  }

  /// Get count of devices locked by THIS project for a preset
  int getMyLockedCountForPreset(int presetId, List<int> labRealIds) {
    int count = 0;
    for (final lock in _deviceLocks.values) {
      if (lock.realId != null && labRealIds.contains(lock.realId)) {
        count++;
      }
    }
    return count;
  }

  /// Refresh locks from database
  Future<void> refreshLocks() async {
    await _loadExistingLocks();
  }

  /// Dispose resources
  @override
  void dispose() {
    debugPrint('LockService: Disposing');
    _isDisposed = true;
    _isCleaningUp = true;
    _locksSubscription?.cancel();
    _locksSubscription = null;
    _channel?.unsubscribe();
    _channel = null;
    _pendingRequests.clear();
    super.dispose();
  }
}
