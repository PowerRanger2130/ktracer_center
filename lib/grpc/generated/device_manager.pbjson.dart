// This is a generated file - do not edit.
//
// Generated from device_manager.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use getStatusRequestDescriptor instead')
const GetStatusRequest$json = {
  '1': 'GetStatusRequest',
};

/// Descriptor for `GetStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStatusRequestDescriptor =
    $convert.base64Decode('ChBHZXRTdGF0dXNSZXF1ZXN0');

@$core.Deprecated('Use getStatusResponseDescriptor instead')
const GetStatusResponse$json = {
  '1': 'GetStatusResponse',
  '2': [
    {'1': 'is_running', '3': 1, '4': 1, '5': 8, '10': 'isRunning'},
    {
      '1': 'healthy_connections',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'healthyConnections'
    },
    {
      '1': 'total_connections',
      '3': 3,
      '4': 1,
      '5': 5,
      '10': 'totalConnections'
    },
    {'1': 'locked_devices', '3': 4, '4': 1, '5': 5, '10': 'lockedDevices'},
    {'1': 'owned_locks', '3': 5, '4': 1, '5': 5, '10': 'ownedLocks'},
    {'1': 'healthy_real_ids', '3': 6, '4': 3, '5': 5, '10': 'healthyRealIds'},
    {'1': 'locked_real_ids', '3': 7, '4': 3, '5': 5, '10': 'lockedRealIds'},
  ],
};

/// Descriptor for `GetStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getStatusResponseDescriptor = $convert.base64Decode(
    'ChFHZXRTdGF0dXNSZXNwb25zZRIdCgppc19ydW5uaW5nGAEgASgIUglpc1J1bm5pbmcSLwoTaG'
    'VhbHRoeV9jb25uZWN0aW9ucxgCIAEoBVISaGVhbHRoeUNvbm5lY3Rpb25zEisKEXRvdGFsX2Nv'
    'bm5lY3Rpb25zGAMgASgFUhB0b3RhbENvbm5lY3Rpb25zEiUKDmxvY2tlZF9kZXZpY2VzGAQgAS'
    'gFUg1sb2NrZWREZXZpY2VzEh8KC293bmVkX2xvY2tzGAUgASgFUgpvd25lZExvY2tzEigKEGhl'
    'YWx0aHlfcmVhbF9pZHMYBiADKAVSDmhlYWx0aHlSZWFsSWRzEiYKD2xvY2tlZF9yZWFsX2lkcx'
    'gHIAMoBVINbG9ja2VkUmVhbElkcw==');

@$core.Deprecated('Use getConnectionPoolRequestDescriptor instead')
const GetConnectionPoolRequest$json = {
  '1': 'GetConnectionPoolRequest',
};

/// Descriptor for `GetConnectionPoolRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getConnectionPoolRequestDescriptor =
    $convert.base64Decode('ChhHZXRDb25uZWN0aW9uUG9vbFJlcXVlc3Q=');

@$core.Deprecated('Use getConnectionPoolResponseDescriptor instead')
const GetConnectionPoolResponse$json = {
  '1': 'GetConnectionPoolResponse',
  '2': [
    {'1': 'is_running', '3': 1, '4': 1, '5': 8, '10': 'isRunning'},
    {
      '1': 'total_connections',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'totalConnections'
    },
    {'1': 'healthy_count', '3': 3, '4': 1, '5': 5, '10': 'healthyCount'},
    {'1': 'healthy', '3': 4, '4': 3, '5': 5, '10': 'healthy'},
    {'1': 'unhealthy', '3': 5, '4': 3, '5': 5, '10': 'unhealthy'},
    {'1': 'disconnected', '3': 6, '4': 3, '5': 5, '10': 'disconnected'},
    {'1': 'missing', '3': 7, '4': 3, '5': 5, '10': 'missing'},
  ],
};

/// Descriptor for `GetConnectionPoolResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getConnectionPoolResponseDescriptor = $convert.base64Decode(
    'ChlHZXRDb25uZWN0aW9uUG9vbFJlc3BvbnNlEh0KCmlzX3J1bm5pbmcYASABKAhSCWlzUnVubm'
    'luZxIrChF0b3RhbF9jb25uZWN0aW9ucxgCIAEoBVIQdG90YWxDb25uZWN0aW9ucxIjCg1oZWFs'
    'dGh5X2NvdW50GAMgASgFUgxoZWFsdGh5Q291bnQSGAoHaGVhbHRoeRgEIAMoBVIHaGVhbHRoeR'
    'IcCgl1bmhlYWx0aHkYBSADKAVSCXVuaGVhbHRoeRIiCgxkaXNjb25uZWN0ZWQYBiADKAVSDGRp'
    'c2Nvbm5lY3RlZBIYCgdtaXNzaW5nGAcgAygFUgdtaXNzaW5n');

@$core.Deprecated('Use lockDeviceRequestDescriptor instead')
const LockDeviceRequest$json = {
  '1': 'LockDeviceRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 3, '10': 'deviceId'},
    {'1': 'project_id', '3': 2, '4': 1, '5': 3, '10': 'projectId'},
    {'1': 'preset_id', '3': 3, '4': 1, '5': 5, '10': 'presetId'},
    {
      '1': 'preferred_real_id',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'preferredRealId',
      '17': true
    },
    {'1': 'reason', '3': 5, '4': 1, '5': 9, '9': 1, '10': 'reason', '17': true},
  ],
  '8': [
    {'1': '_preferred_real_id'},
    {'1': '_reason'},
  ],
};

/// Descriptor for `LockDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lockDeviceRequestDescriptor = $convert.base64Decode(
    'ChFMb2NrRGV2aWNlUmVxdWVzdBIbCglkZXZpY2VfaWQYASABKANSCGRldmljZUlkEh0KCnByb2'
    'plY3RfaWQYAiABKANSCXByb2plY3RJZBIbCglwcmVzZXRfaWQYAyABKAVSCHByZXNldElkEi8K'
    'EXByZWZlcnJlZF9yZWFsX2lkGAQgASgFSABSD3ByZWZlcnJlZFJlYWxJZIgBARIbCgZyZWFzb2'
    '4YBSABKAlIAVIGcmVhc29uiAEBQhQKEl9wcmVmZXJyZWRfcmVhbF9pZEIJCgdfcmVhc29u');

@$core.Deprecated('Use lockDeviceResponseDescriptor instead')
const LockDeviceResponse$json = {
  '1': 'LockDeviceResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {
      '1': 'assigned_real_id',
      '3': 2,
      '4': 1,
      '5': 5,
      '9': 0,
      '10': 'assignedRealId',
      '17': true
    },
    {
      '1': 'lock_id',
      '3': 3,
      '4': 1,
      '5': 3,
      '9': 1,
      '10': 'lockId',
      '17': true
    },
    {'1': 'error', '3': 4, '4': 1, '5': 9, '9': 2, '10': 'error', '17': true},
  ],
  '8': [
    {'1': '_assigned_real_id'},
    {'1': '_lock_id'},
    {'1': '_error'},
  ],
};

/// Descriptor for `LockDeviceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List lockDeviceResponseDescriptor = $convert.base64Decode(
    'ChJMb2NrRGV2aWNlUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxItChBhc3NpZ2'
    '5lZF9yZWFsX2lkGAIgASgFSABSDmFzc2lnbmVkUmVhbElkiAEBEhwKB2xvY2tfaWQYAyABKANI'
    'AVIGbG9ja0lkiAEBEhkKBWVycm9yGAQgASgJSAJSBWVycm9yiAEBQhMKEV9hc3NpZ25lZF9yZW'
    'FsX2lkQgoKCF9sb2NrX2lkQggKBl9lcnJvcg==');

@$core.Deprecated('Use unlockDeviceRequestDescriptor instead')
const UnlockDeviceRequest$json = {
  '1': 'UnlockDeviceRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 3, '10': 'deviceId'},
  ],
};

/// Descriptor for `UnlockDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unlockDeviceRequestDescriptor =
    $convert.base64Decode(
        'ChNVbmxvY2tEZXZpY2VSZXF1ZXN0EhsKCWRldmljZV9pZBgBIAEoA1IIZGV2aWNlSWQ=');

@$core.Deprecated('Use unlockDeviceResponseDescriptor instead')
const UnlockDeviceResponse$json = {
  '1': 'UnlockDeviceResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'error', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'error', '17': true},
  ],
  '8': [
    {'1': '_error'},
  ],
};

/// Descriptor for `UnlockDeviceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unlockDeviceResponseDescriptor = $convert.base64Decode(
    'ChRVbmxvY2tEZXZpY2VSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhkKBWVycm'
    '9yGAIgASgJSABSBWVycm9yiAEBQggKBl9lcnJvcg==');

@$core.Deprecated('Use getLocksRequestDescriptor instead')
const GetLocksRequest$json = {
  '1': 'GetLocksRequest',
  '2': [
    {'1': 'owned_only', '3': 1, '4': 1, '5': 8, '10': 'ownedOnly'},
  ],
};

/// Descriptor for `GetLocksRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getLocksRequestDescriptor = $convert.base64Decode(
    'Cg9HZXRMb2Nrc1JlcXVlc3QSHQoKb3duZWRfb25seRgBIAEoCFIJb3duZWRPbmx5');

@$core.Deprecated('Use deviceLockInfoDescriptor instead')
const DeviceLockInfo$json = {
  '1': 'DeviceLockInfo',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'device_id', '3': 2, '4': 1, '5': 3, '10': 'deviceId'},
    {'1': 'project_id', '3': 3, '4': 1, '5': 3, '10': 'projectId'},
    {'1': 'real_id', '3': 4, '4': 1, '5': 5, '10': 'realId'},
    {'1': 'client_id', '3': 5, '4': 1, '5': 5, '10': 'clientId'},
    {'1': 'locked_at', '3': 6, '4': 1, '5': 9, '10': 'lockedAt'},
    {'1': 'reason', '3': 7, '4': 1, '5': 9, '9': 0, '10': 'reason', '17': true},
  ],
  '8': [
    {'1': '_reason'},
  ],
};

/// Descriptor for `DeviceLockInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceLockInfoDescriptor = $convert.base64Decode(
    'Cg5EZXZpY2VMb2NrSW5mbxIOCgJpZBgBIAEoA1ICaWQSGwoJZGV2aWNlX2lkGAIgASgDUghkZX'
    'ZpY2VJZBIdCgpwcm9qZWN0X2lkGAMgASgDUglwcm9qZWN0SWQSFwoHcmVhbF9pZBgEIAEoBVIG'
    'cmVhbElkEhsKCWNsaWVudF9pZBgFIAEoBVIIY2xpZW50SWQSGwoJbG9ja2VkX2F0GAYgASgJUg'
    'hsb2NrZWRBdBIbCgZyZWFzb24YByABKAlIAFIGcmVhc29uiAEBQgkKB19yZWFzb24=');

@$core.Deprecated('Use getLocksResponseDescriptor instead')
const GetLocksResponse$json = {
  '1': 'GetLocksResponse',
  '2': [
    {
      '1': 'locks',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.device_manager.DeviceLockInfo',
      '10': 'locks'
    },
    {'1': 'locked_real_ids', '3': 2, '4': 3, '5': 5, '10': 'lockedRealIds'},
  ],
};

/// Descriptor for `GetLocksResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getLocksResponseDescriptor = $convert.base64Decode(
    'ChBHZXRMb2Nrc1Jlc3BvbnNlEjQKBWxvY2tzGAEgAygLMh4uZGV2aWNlX21hbmFnZXIuRGV2aW'
    'NlTG9ja0luZm9SBWxvY2tzEiYKD2xvY2tlZF9yZWFsX2lkcxgCIAMoBVINbG9ja2VkUmVhbElk'
    'cw==');

@$core.Deprecated('Use getAvailableDevicesRequestDescriptor instead')
const GetAvailableDevicesRequest$json = {
  '1': 'GetAvailableDevicesRequest',
  '2': [
    {'1': 'preset_id', '3': 1, '4': 1, '5': 5, '10': 'presetId'},
  ],
};

/// Descriptor for `GetAvailableDevicesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAvailableDevicesRequestDescriptor =
    $convert.base64Decode(
        'ChpHZXRBdmFpbGFibGVEZXZpY2VzUmVxdWVzdBIbCglwcmVzZXRfaWQYASABKAVSCHByZXNldE'
        'lk');

@$core.Deprecated('Use getAvailableDevicesResponseDescriptor instead')
const GetAvailableDevicesResponse$json = {
  '1': 'GetAvailableDevicesResponse',
  '2': [
    {
      '1': 'available_real_ids',
      '3': 1,
      '4': 3,
      '5': 5,
      '10': 'availableRealIds'
    },
    {'1': 'total_count', '3': 2, '4': 1, '5': 5, '10': 'totalCount'},
  ],
};

/// Descriptor for `GetAvailableDevicesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAvailableDevicesResponseDescriptor =
    $convert.base64Decode(
        'ChtHZXRBdmFpbGFibGVEZXZpY2VzUmVzcG9uc2USLAoSYXZhaWxhYmxlX3JlYWxfaWRzGAEgAy'
        'gFUhBhdmFpbGFibGVSZWFsSWRzEh8KC3RvdGFsX2NvdW50GAIgASgFUgp0b3RhbENvdW50');

@$core.Deprecated('Use pingRequestDescriptor instead')
const PingRequest$json = {
  '1': 'PingRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 3, '9': 0, '10': 'deviceId'},
    {'1': 'real_id', '3': 2, '4': 1, '5': 5, '9': 0, '10': 'realId'},
    {'1': 'target', '3': 3, '4': 1, '5': 9, '10': 'target'},
    {'1': 'count', '3': 4, '4': 1, '5': 5, '9': 1, '10': 'count', '17': true},
  ],
  '8': [
    {'1': 'target_device'},
    {'1': '_count'},
  ],
};

/// Descriptor for `PingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingRequestDescriptor = $convert.base64Decode(
    'CgtQaW5nUmVxdWVzdBIdCglkZXZpY2VfaWQYASABKANIAFIIZGV2aWNlSWQSGQoHcmVhbF9pZB'
    'gCIAEoBUgAUgZyZWFsSWQSFgoGdGFyZ2V0GAMgASgJUgZ0YXJnZXQSGQoFY291bnQYBCABKAVI'
    'AVIFY291bnSIAQFCDwoNdGFyZ2V0X2RldmljZUIICgZfY291bnQ=');

@$core.Deprecated('Use pingResponseDescriptor instead')
const PingResponse$json = {
  '1': 'PingResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'real_id', '3': 2, '4': 1, '5': 5, '10': 'realId'},
    {'1': 'output', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'output', '17': true},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'error', '17': true},
    {'1': 'packets_sent', '3': 5, '4': 1, '5': 5, '10': 'packetsSent'},
    {'1': 'packets_received', '3': 6, '4': 1, '5': 5, '10': 'packetsReceived'},
    {'1': 'packets_lost', '3': 7, '4': 1, '5': 5, '10': 'packetsLost'},
    {'1': 'success_rate', '3': 8, '4': 1, '5': 1, '10': 'successRate'},
    {
      '1': 'min_rtt',
      '3': 9,
      '4': 1,
      '5': 5,
      '9': 2,
      '10': 'minRtt',
      '17': true
    },
    {
      '1': 'avg_rtt',
      '3': 10,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'avgRtt',
      '17': true
    },
    {
      '1': 'max_rtt',
      '3': 11,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'maxRtt',
      '17': true
    },
    {'1': 'duration_ms', '3': 12, '4': 1, '5': 3, '10': 'durationMs'},
  ],
  '8': [
    {'1': '_output'},
    {'1': '_error'},
    {'1': '_min_rtt'},
    {'1': '_avg_rtt'},
    {'1': '_max_rtt'},
  ],
};

/// Descriptor for `PingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResponseDescriptor = $convert.base64Decode(
    'CgxQaW5nUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIXCgdyZWFsX2lkGAIgAS'
    'gFUgZyZWFsSWQSGwoGb3V0cHV0GAMgASgJSABSBm91dHB1dIgBARIZCgVlcnJvchgEIAEoCUgB'
    'UgVlcnJvcogBARIhCgxwYWNrZXRzX3NlbnQYBSABKAVSC3BhY2tldHNTZW50EikKEHBhY2tldH'
    'NfcmVjZWl2ZWQYBiABKAVSD3BhY2tldHNSZWNlaXZlZBIhCgxwYWNrZXRzX2xvc3QYByABKAVS'
    'C3BhY2tldHNMb3N0EiEKDHN1Y2Nlc3NfcmF0ZRgIIAEoAVILc3VjY2Vzc1JhdGUSHAoHbWluX3'
    'J0dBgJIAEoBUgCUgZtaW5SdHSIAQESHAoHYXZnX3J0dBgKIAEoBUgDUgZhdmdSdHSIAQESHAoH'
    'bWF4X3J0dBgLIAEoBUgEUgZtYXhSdHSIAQESHwoLZHVyYXRpb25fbXMYDCABKANSCmR1cmF0aW'
    '9uTXNCCQoHX291dHB1dEIICgZfZXJyb3JCCgoIX21pbl9ydHRCCgoIX2F2Z19ydHRCCgoIX21h'
    'eF9ydHQ=');

@$core.Deprecated('Use tracerouteRequestDescriptor instead')
const TracerouteRequest$json = {
  '1': 'TracerouteRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 3, '9': 0, '10': 'deviceId'},
    {'1': 'real_id', '3': 2, '4': 1, '5': 5, '9': 0, '10': 'realId'},
    {'1': 'target', '3': 3, '4': 1, '5': 9, '10': 'target'},
  ],
  '8': [
    {'1': 'target_device'},
  ],
};

/// Descriptor for `TracerouteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tracerouteRequestDescriptor = $convert.base64Decode(
    'ChFUcmFjZXJvdXRlUmVxdWVzdBIdCglkZXZpY2VfaWQYASABKANIAFIIZGV2aWNlSWQSGQoHcm'
    'VhbF9pZBgCIAEoBUgAUgZyZWFsSWQSFgoGdGFyZ2V0GAMgASgJUgZ0YXJnZXRCDwoNdGFyZ2V0'
    'X2RldmljZQ==');

@$core.Deprecated('Use tracerouteHopDescriptor instead')
const TracerouteHop$json = {
  '1': 'TracerouteHop',
  '2': [
    {'1': 'hop_number', '3': 1, '4': 1, '5': 5, '10': 'hopNumber'},
    {
      '1': 'address',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'address',
      '17': true
    },
    {
      '1': 'hostname',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'hostname',
      '17': true
    },
    {'1': 'rtt_ms', '3': 4, '4': 3, '5': 5, '10': 'rttMs'},
    {'1': 'is_timeout', '3': 5, '4': 1, '5': 8, '10': 'isTimeout'},
  ],
  '8': [
    {'1': '_address'},
    {'1': '_hostname'},
  ],
};

/// Descriptor for `TracerouteHop`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tracerouteHopDescriptor = $convert.base64Decode(
    'Cg1UcmFjZXJvdXRlSG9wEh0KCmhvcF9udW1iZXIYASABKAVSCWhvcE51bWJlchIdCgdhZGRyZX'
    'NzGAIgASgJSABSB2FkZHJlc3OIAQESHwoIaG9zdG5hbWUYAyABKAlIAVIIaG9zdG5hbWWIAQES'
    'FQoGcnR0X21zGAQgAygFUgVydHRNcxIdCgppc190aW1lb3V0GAUgASgIUglpc1RpbWVvdXRCCg'
    'oIX2FkZHJlc3NCCwoJX2hvc3RuYW1l');

@$core.Deprecated('Use tracerouteResponseDescriptor instead')
const TracerouteResponse$json = {
  '1': 'TracerouteResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'real_id', '3': 2, '4': 1, '5': 5, '10': 'realId'},
    {'1': 'output', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'output', '17': true},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'error', '17': true},
    {
      '1': 'hops',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.device_manager.TracerouteHop',
      '10': 'hops'
    },
    {
      '1': 'reached_destination',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'reachedDestination'
    },
    {'1': 'duration_ms', '3': 7, '4': 1, '5': 3, '10': 'durationMs'},
  ],
  '8': [
    {'1': '_output'},
    {'1': '_error'},
  ],
};

/// Descriptor for `TracerouteResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tracerouteResponseDescriptor = $convert.base64Decode(
    'ChJUcmFjZXJvdXRlUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIXCgdyZWFsX2'
    'lkGAIgASgFUgZyZWFsSWQSGwoGb3V0cHV0GAMgASgJSABSBm91dHB1dIgBARIZCgVlcnJvchgE'
    'IAEoCUgBUgVlcnJvcogBARIxCgRob3BzGAUgAygLMh0uZGV2aWNlX21hbmFnZXIuVHJhY2Vyb3'
    'V0ZUhvcFIEaG9wcxIvChNyZWFjaGVkX2Rlc3RpbmF0aW9uGAYgASgIUhJyZWFjaGVkRGVzdGlu'
    'YXRpb24SHwoLZHVyYXRpb25fbXMYByABKANSCmR1cmF0aW9uTXNCCQoHX291dHB1dEIICgZfZX'
    'Jyb3I=');

@$core.Deprecated('Use showCommandRequestDescriptor instead')
const ShowCommandRequest$json = {
  '1': 'ShowCommandRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 3, '9': 0, '10': 'deviceId'},
    {'1': 'real_id', '3': 2, '4': 1, '5': 5, '9': 0, '10': 'realId'},
    {'1': 'command', '3': 3, '4': 1, '5': 9, '10': 'command'},
  ],
  '8': [
    {'1': 'target_device'},
  ],
};

/// Descriptor for `ShowCommandRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List showCommandRequestDescriptor = $convert.base64Decode(
    'ChJTaG93Q29tbWFuZFJlcXVlc3QSHQoJZGV2aWNlX2lkGAEgASgDSABSCGRldmljZUlkEhkKB3'
    'JlYWxfaWQYAiABKAVIAFIGcmVhbElkEhgKB2NvbW1hbmQYAyABKAlSB2NvbW1hbmRCDwoNdGFy'
    'Z2V0X2RldmljZQ==');

@$core.Deprecated('Use showCommandResponseDescriptor instead')
const ShowCommandResponse$json = {
  '1': 'ShowCommandResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'real_id', '3': 2, '4': 1, '5': 5, '10': 'realId'},
    {'1': 'output', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'output', '17': true},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'error', '17': true},
    {'1': 'duration_ms', '3': 5, '4': 1, '5': 3, '10': 'durationMs'},
  ],
  '8': [
    {'1': '_output'},
    {'1': '_error'},
  ],
};

/// Descriptor for `ShowCommandResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List showCommandResponseDescriptor = $convert.base64Decode(
    'ChNTaG93Q29tbWFuZFJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSFwoHcmVhbF'
    '9pZBgCIAEoBVIGcmVhbElkEhsKBm91dHB1dBgDIAEoCUgAUgZvdXRwdXSIAQESGQoFZXJyb3IY'
    'BCABKAlIAVIFZXJyb3KIAQESHwoLZHVyYXRpb25fbXMYBSABKANSCmR1cmF0aW9uTXNCCQoHX2'
    '91dHB1dEIICgZfZXJyb3I=');

@$core.Deprecated('Use rawCommandRequestDescriptor instead')
const RawCommandRequest$json = {
  '1': 'RawCommandRequest',
  '2': [
    {'1': 'real_id', '3': 1, '4': 1, '5': 5, '10': 'realId'},
    {'1': 'command', '3': 2, '4': 1, '5': 9, '10': 'command'},
  ],
};

/// Descriptor for `RawCommandRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rawCommandRequestDescriptor = $convert.base64Decode(
    'ChFSYXdDb21tYW5kUmVxdWVzdBIXCgdyZWFsX2lkGAEgASgFUgZyZWFsSWQSGAoHY29tbWFuZB'
    'gCIAEoCVIHY29tbWFuZA==');

@$core.Deprecated('Use rawCommandResponseDescriptor instead')
const RawCommandResponse$json = {
  '1': 'RawCommandResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'real_id', '3': 2, '4': 1, '5': 5, '10': 'realId'},
    {'1': 'output', '3': 3, '4': 1, '5': 9, '9': 0, '10': 'output', '17': true},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '9': 1, '10': 'error', '17': true},
    {'1': 'duration_ms', '3': 5, '4': 1, '5': 3, '10': 'durationMs'},
  ],
  '8': [
    {'1': '_output'},
    {'1': '_error'},
  ],
};

/// Descriptor for `RawCommandResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rawCommandResponseDescriptor = $convert.base64Decode(
    'ChJSYXdDb21tYW5kUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIXCgdyZWFsX2'
    'lkGAIgASgFUgZyZWFsSWQSGwoGb3V0cHV0GAMgASgJSABSBm91dHB1dIgBARIZCgVlcnJvchgE'
    'IAEoCUgBUgVlcnJvcogBARIfCgtkdXJhdGlvbl9tcxgFIAEoA1IKZHVyYXRpb25Nc0IJCgdfb3'
    'V0cHV0QggKBl9lcnJvcg==');

@$core.Deprecated('Use reapplyConfigRequestDescriptor instead')
const ReapplyConfigRequest$json = {
  '1': 'ReapplyConfigRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 3, '10': 'deviceId'},
  ],
};

/// Descriptor for `ReapplyConfigRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reapplyConfigRequestDescriptor =
    $convert.base64Decode(
        'ChRSZWFwcGx5Q29uZmlnUmVxdWVzdBIbCglkZXZpY2VfaWQYASABKANSCGRldmljZUlk');

@$core.Deprecated('Use reapplyConfigResponseDescriptor instead')
const ReapplyConfigResponse$json = {
  '1': 'ReapplyConfigResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'real_id', '3': 2, '4': 1, '5': 5, '10': 'realId'},
    {'1': 'commands_sent', '3': 3, '4': 1, '5': 5, '10': 'commandsSent'},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '9': 0, '10': 'error', '17': true},
    {'1': 'duration_ms', '3': 5, '4': 1, '5': 3, '10': 'durationMs'},
  ],
  '8': [
    {'1': '_error'},
  ],
};

/// Descriptor for `ReapplyConfigResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reapplyConfigResponseDescriptor = $convert.base64Decode(
    'ChVSZWFwcGx5Q29uZmlnUmVzcG9uc2USGAoHc3VjY2VzcxgBIAEoCFIHc3VjY2VzcxIXCgdyZW'
    'FsX2lkGAIgASgFUgZyZWFsSWQSIwoNY29tbWFuZHNfc2VudBgDIAEoBVIMY29tbWFuZHNTZW50'
    'EhkKBWVycm9yGAQgASgJSABSBWVycm9yiAEBEh8KC2R1cmF0aW9uX21zGAUgASgDUgpkdXJhdG'
    'lvbk1zQggKBl9lcnJvcg==');

@$core.Deprecated('Use ping2RequestDescriptor instead')
const Ping2Request$json = {
  '1': 'Ping2Request',
};

/// Descriptor for `Ping2Request`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ping2RequestDescriptor =
    $convert.base64Decode('CgxQaW5nMlJlcXVlc3Q=');

@$core.Deprecated('Use ping2ResponseDescriptor instead')
const Ping2Response$json = {
  '1': 'Ping2Response',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 9, '10': 'status'},
    {'1': 'is_running', '3': 2, '4': 1, '5': 8, '10': 'isRunning'},
    {
      '1': 'healthy_connections',
      '3': 3,
      '4': 1,
      '5': 5,
      '10': 'healthyConnections'
    },
    {'1': 'locked_devices', '3': 4, '4': 1, '5': 5, '10': 'lockedDevices'},
  ],
};

/// Descriptor for `Ping2Response`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ping2ResponseDescriptor = $convert.base64Decode(
    'Cg1QaW5nMlJlc3BvbnNlEhYKBnN0YXR1cxgBIAEoCVIGc3RhdHVzEh0KCmlzX3J1bm5pbmcYAi'
    'ABKAhSCWlzUnVubmluZxIvChNoZWFsdGh5X2Nvbm5lY3Rpb25zGAMgASgFUhJoZWFsdGh5Q29u'
    'bmVjdGlvbnMSJQoObG9ja2VkX2RldmljZXMYBCABKAVSDWxvY2tlZERldmljZXM=');
