/// gRPC Client for Device Manager Service
///
/// Connects to the supabase_dart gRPC server for device management operations.
library;

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:fixnum/fixnum.dart';

import 'generated/device_manager.pbgrpc.dart';

/// Configuration for the Device Manager gRPC client
class DeviceManagerClientConfig {
  /// gRPC server host
  final String host;

  /// gRPC server port
  final int port;

  const DeviceManagerClientConfig({
    this.host = '172.28.136.205',
    this.port = 50052,
  });
}

/// gRPC Client for communicating with the Device Manager service
class DeviceManagerClient extends ChangeNotifier {
  final DeviceManagerClientConfig config;

  ClientChannel? _channel;
  DeviceManagerServiceClient? _client;

  bool _isConnected = false;
  String? _lastError;

  /// Whether the client is connected
  bool get isConnected => _isConnected;

  /// Last error message, if any
  String? get lastError => _lastError;

  DeviceManagerClient({DeviceManagerClientConfig? config})
    : config = config ?? const DeviceManagerClientConfig();

  /// Initialize the gRPC channel and client
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      _channel = ClientChannel(
        config.host,
        port: config.port,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );

      _client = DeviceManagerServiceClient(_channel!);

      // Test connection with ping
      await ping();

      _isConnected = true;
      _lastError = null;
      debugPrint(
        'DeviceManagerClient: Connected to ${config.host}:${config.port}',
      );
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      debugPrint('DeviceManagerClient: Failed to connect - $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.shutdown();
      _channel = null;
      _client = null;
    }
    _isConnected = false;
    notifyListeners();
  }

  /// Ensure client is connected
  void _ensureConnected() {
    if (_client == null) {
      throw StateError(
        'DeviceManagerClient not connected. Call connect() first.',
      );
    }
  }

  // =========================================================================
  // Health Check
  // =========================================================================

  /// Ping the server to check if it's running
  Future<Ping2Response> ping() async {
    _ensureConnected();
    return await _client!.ping2(Ping2Request());
  }

  // =========================================================================
  // Status Methods
  // =========================================================================

  /// Get the overall status of the device manager
  Future<GetStatusResponse> getStatus() async {
    _ensureConnected();
    return await _client!.getStatus(GetStatusRequest());
  }

  /// Get the connection pool status
  Future<GetConnectionPoolResponse> getConnectionPool() async {
    _ensureConnected();
    return await _client!.getConnectionPool(GetConnectionPoolRequest());
  }

  // =========================================================================
  // Device Locking
  // =========================================================================

  /// Lock a device for exclusive use
  Future<LockDeviceResponse> lockDevice({
    required int deviceId,
    required int projectId,
    required int presetId,
    int? preferredRealId,
    String? reason,
  }) async {
    _ensureConnected();

    final request = LockDeviceRequest()
      ..deviceId = Int64(deviceId)
      ..projectId = Int64(projectId)
      ..presetId = presetId;

    if (preferredRealId != null) {
      request.preferredRealId = preferredRealId;
    }
    if (reason != null) {
      request.reason = reason;
    }

    return await _client!.lockDevice(request);
  }

  /// Unlock a device
  Future<UnlockDeviceResponse> unlockDevice(int deviceId) async {
    _ensureConnected();
    return await _client!.unlockDevice(
      UnlockDeviceRequest()..deviceId = Int64(deviceId),
    );
  }

  /// Get all locks
  Future<GetLocksResponse> getLocks({bool ownedOnly = false}) async {
    _ensureConnected();
    return await _client!.getLocks(GetLocksRequest()..ownedOnly = ownedOnly);
  }

  /// Get available devices for a preset
  Future<GetAvailableDevicesResponse> getAvailableDevices(int presetId) async {
    _ensureConnected();
    return await _client!.getAvailableDevices(
      GetAvailableDevicesRequest()..presetId = presetId,
    );
  }

  // =========================================================================
  // Direct Commands
  // =========================================================================

  /// Ping a target from a device
  Future<PingResponse> pingFromDevice({
    int? deviceId,
    int? realId,
    required String target,
    int? count,
  }) async {
    _ensureConnected();

    final request = PingRequest()..target = target;

    if (deviceId != null) {
      request.deviceId = Int64(deviceId);
    } else if (realId != null) {
      request.realId = realId;
    } else {
      throw ArgumentError('Either deviceId or realId must be provided');
    }

    if (count != null) {
      request.count = count;
    }

    return await _client!.ping(request);
  }

  /// Run traceroute from a device
  Future<TracerouteResponse> traceroute({
    int? deviceId,
    int? realId,
    required String target,
  }) async {
    _ensureConnected();

    final request = TracerouteRequest()..target = target;

    if (deviceId != null) {
      request.deviceId = Int64(deviceId);
    } else if (realId != null) {
      request.realId = realId;
    } else {
      throw ArgumentError('Either deviceId or realId must be provided');
    }

    return await _client!.traceroute(request);
  }

  /// Execute a show command on a device
  Future<ShowCommandResponse> showCommand({
    int? deviceId,
    int? realId,
    required String command,
  }) async {
    _ensureConnected();

    final request = ShowCommandRequest()..command = command;

    if (deviceId != null) {
      request.deviceId = Int64(deviceId);
    } else if (realId != null) {
      request.realId = realId;
    } else {
      throw ArgumentError('Either deviceId or realId must be provided');
    }

    return await _client!.showCommand(request);
  }

  /// Execute a raw command on a device (by real ID only)
  Future<RawCommandResponse> rawCommand({
    required int realId,
    required String command,
  }) async {
    _ensureConnected();

    return await _client!.rawCommand(
      RawCommandRequest()
        ..realId = realId
        ..command = command,
    );
  }

  // =========================================================================
  // Config Management
  // =========================================================================

  /// Reapply configuration to a device
  Future<ReapplyConfigResponse> reapplyConfig(int deviceId) async {
    _ensureConnected();
    return await _client!.reapplyConfig(
      ReapplyConfigRequest()..deviceId = Int64(deviceId),
    );
  }
}
