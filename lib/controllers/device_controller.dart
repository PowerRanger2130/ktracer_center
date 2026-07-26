// ignore_for_file: avoid_print

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Controller for device communication using Supabase Realtime Broadcast.
/// Uses the global broadcast channel to communicate with the Python backend.
/// 
/// Events sent:
/// - config_update: Request device configuration update
/// 
/// Events received:
/// - device_status: Device status updates (connecting, configuring, ready, error)
/// - device_response: Command execution responses
class DeviceController {
  final SupabaseClient supabase;
  final int projectId;
  RealtimeChannel? _channel;

  final _responseController = StreamController<DeviceResponse>.broadcast();
  Stream<DeviceResponse> get responses => _responseController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  DeviceController(this.supabase, this.projectId);

  void initialize() {
    // Use the global channel (same as Python backend)
    _channel = supabase.channel('global');

    // Listen for device responses from Python backend
    _channel!.onBroadcast(
      event: 'device_response',
      callback: (payload) {
        // Extract payload data (may be wrapped in 'payload' key)
        final data = payload['payload'] as Map<String, dynamic>? ?? payload;
        
        final response = DeviceResponse(
          deviceId: data['device_id'] as int?,
          realId: data['real_id'] as int?,
          status: data['status'] as String?,
          output: data['output'] as String?,
          error: data['error'] as String?,
        );
        _responseController.add(response);

        print('Received response from device ${response.realId}:');
        print('Status: ${response.status}');
        if (response.output != null) print('Output: ${response.output}');
        if (response.error != null) print('Error: ${response.error}');
      },
    );

    // Subscribe to the channel
    _channel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isConnected = true;
        print('DeviceController: Connected to global broadcast channel');
      } else if (status == RealtimeSubscribeStatus.closed) {
        _isConnected = false;
        print('DeviceController: Channel closed');
      } else if (error != null) {
        _isConnected = false;
        print('DeviceController: Channel error: $error');
      }
    });
  }

  /// Send a configuration update to a specific device
  /// This triggers the Python backend to apply the config to the active device
  Future<void> sendConfigUpdate(
    int deviceId, {
    Map<String, dynamic>? config,
    String? section,
  }) async {
    if (_channel == null || !_isConnected) {
      print('DeviceController: Not connected, cannot send config update');
      return;
    }

    print('Sending config update to device $deviceId');

    await _channel!.sendBroadcastMessage(
      event: 'config_update',
      payload: {
        'payload': {
          'device_id': deviceId,
          'project_id': projectId,
          'config': config ?? {},
          if (section != null) 'section': section,
          'timestamp': DateTime.now().toIso8601String(),
        },
      },
    );
  }

  /// Send a command to a specific device
  /// Note: Commands are typically sent via config updates or handled by LockService
  Future<void> sendCommand(int deviceId, int realId, String command) async {
    if (_channel == null || !_isConnected) {
      print('DeviceController: Not connected, cannot send command');
      return;
    }

    print('Sending command to device $realId: $command');

    await _channel!.sendBroadcastMessage(
      event: 'device_command',
      payload: {
        'payload': {
          'project_id': projectId,
          'device_id': deviceId,
          'real_id': realId,
          'command': command,
          'timestamp': DateTime.now().toIso8601String(),
        },
      },
    );
  }

  /// Broadcast a command to all devices in the project
  Future<void> broadcastCommand(String command, List<int> realIds) async {
    if (_channel == null || !_isConnected) {
      print('DeviceController: Not connected, cannot broadcast command');
      return;
    }

    print('Broadcasting command to ${realIds.length} devices: $command');

    await _channel!.sendBroadcastMessage(
      event: 'broadcast_command',
      payload: {
        'payload': {
          'project_id': projectId,
          'real_ids': realIds,
          'command': command,
          'timestamp': DateTime.now().toIso8601String(),
        },
      },
    );
  }

  void dispose() {
    if (_channel != null) {
      supabase.removeChannel(_channel!);
      _channel = null;
    }
    _isConnected = false;
    _responseController.close();
  }
}

class DeviceResponse {
  final int? deviceId;
  final int? realId;
  final String? status;
  final String? output;
  final String? error;

  DeviceResponse({
    this.deviceId,
    this.realId,
    this.status,
    this.output,
    this.error,
  });
}
