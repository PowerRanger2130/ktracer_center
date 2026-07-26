// This is a generated file - do not edit.
//
// Generated from device_manager.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'device_manager.pb.dart' as $0;

export 'device_manager.pb.dart';

@$pb.GrpcServiceName('device_manager.DeviceManagerService')
class DeviceManagerServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  DeviceManagerServiceClient(super.channel,
      {super.options, super.interceptors});

  /// Connection Management
  $grpc.ResponseFuture<$0.GetStatusResponse> getStatus(
    $0.GetStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getStatus, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetConnectionPoolResponse> getConnectionPool(
    $0.GetConnectionPoolRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getConnectionPool, request, options: options);
  }

  /// Device Locking
  $grpc.ResponseFuture<$0.LockDeviceResponse> lockDevice(
    $0.LockDeviceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$lockDevice, request, options: options);
  }

  $grpc.ResponseFuture<$0.UnlockDeviceResponse> unlockDevice(
    $0.UnlockDeviceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$unlockDevice, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetLocksResponse> getLocks(
    $0.GetLocksRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getLocks, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetAvailableDevicesResponse> getAvailableDevices(
    $0.GetAvailableDevicesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getAvailableDevices, request, options: options);
  }

  /// Direct Commands
  $grpc.ResponseFuture<$0.PingResponse> ping(
    $0.PingRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$ping, request, options: options);
  }

  $grpc.ResponseFuture<$0.TracerouteResponse> traceroute(
    $0.TracerouteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$traceroute, request, options: options);
  }

  $grpc.ResponseFuture<$0.ShowCommandResponse> showCommand(
    $0.ShowCommandRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$showCommand, request, options: options);
  }

  $grpc.ResponseFuture<$0.RawCommandResponse> rawCommand(
    $0.RawCommandRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$rawCommand, request, options: options);
  }

  /// Config Management
  $grpc.ResponseFuture<$0.ReapplyConfigResponse> reapplyConfig(
    $0.ReapplyConfigRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reapplyConfig, request, options: options);
  }

  /// Health Check
  $grpc.ResponseFuture<$0.Ping2Response> ping2(
    $0.Ping2Request request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$ping2, request, options: options);
  }

  // method descriptors

  static final _$getStatus =
      $grpc.ClientMethod<$0.GetStatusRequest, $0.GetStatusResponse>(
          '/device_manager.DeviceManagerService/GetStatus',
          ($0.GetStatusRequest value) => value.writeToBuffer(),
          $0.GetStatusResponse.fromBuffer);
  static final _$getConnectionPool = $grpc.ClientMethod<
          $0.GetConnectionPoolRequest, $0.GetConnectionPoolResponse>(
      '/device_manager.DeviceManagerService/GetConnectionPool',
      ($0.GetConnectionPoolRequest value) => value.writeToBuffer(),
      $0.GetConnectionPoolResponse.fromBuffer);
  static final _$lockDevice =
      $grpc.ClientMethod<$0.LockDeviceRequest, $0.LockDeviceResponse>(
          '/device_manager.DeviceManagerService/LockDevice',
          ($0.LockDeviceRequest value) => value.writeToBuffer(),
          $0.LockDeviceResponse.fromBuffer);
  static final _$unlockDevice =
      $grpc.ClientMethod<$0.UnlockDeviceRequest, $0.UnlockDeviceResponse>(
          '/device_manager.DeviceManagerService/UnlockDevice',
          ($0.UnlockDeviceRequest value) => value.writeToBuffer(),
          $0.UnlockDeviceResponse.fromBuffer);
  static final _$getLocks =
      $grpc.ClientMethod<$0.GetLocksRequest, $0.GetLocksResponse>(
          '/device_manager.DeviceManagerService/GetLocks',
          ($0.GetLocksRequest value) => value.writeToBuffer(),
          $0.GetLocksResponse.fromBuffer);
  static final _$getAvailableDevices = $grpc.ClientMethod<
          $0.GetAvailableDevicesRequest, $0.GetAvailableDevicesResponse>(
      '/device_manager.DeviceManagerService/GetAvailableDevices',
      ($0.GetAvailableDevicesRequest value) => value.writeToBuffer(),
      $0.GetAvailableDevicesResponse.fromBuffer);
  static final _$ping = $grpc.ClientMethod<$0.PingRequest, $0.PingResponse>(
      '/device_manager.DeviceManagerService/Ping',
      ($0.PingRequest value) => value.writeToBuffer(),
      $0.PingResponse.fromBuffer);
  static final _$traceroute =
      $grpc.ClientMethod<$0.TracerouteRequest, $0.TracerouteResponse>(
          '/device_manager.DeviceManagerService/Traceroute',
          ($0.TracerouteRequest value) => value.writeToBuffer(),
          $0.TracerouteResponse.fromBuffer);
  static final _$showCommand =
      $grpc.ClientMethod<$0.ShowCommandRequest, $0.ShowCommandResponse>(
          '/device_manager.DeviceManagerService/ShowCommand',
          ($0.ShowCommandRequest value) => value.writeToBuffer(),
          $0.ShowCommandResponse.fromBuffer);
  static final _$rawCommand =
      $grpc.ClientMethod<$0.RawCommandRequest, $0.RawCommandResponse>(
          '/device_manager.DeviceManagerService/RawCommand',
          ($0.RawCommandRequest value) => value.writeToBuffer(),
          $0.RawCommandResponse.fromBuffer);
  static final _$reapplyConfig =
      $grpc.ClientMethod<$0.ReapplyConfigRequest, $0.ReapplyConfigResponse>(
          '/device_manager.DeviceManagerService/ReapplyConfig',
          ($0.ReapplyConfigRequest value) => value.writeToBuffer(),
          $0.ReapplyConfigResponse.fromBuffer);
  static final _$ping2 = $grpc.ClientMethod<$0.Ping2Request, $0.Ping2Response>(
      '/device_manager.DeviceManagerService/Ping2',
      ($0.Ping2Request value) => value.writeToBuffer(),
      $0.Ping2Response.fromBuffer);
}

@$pb.GrpcServiceName('device_manager.DeviceManagerService')
abstract class DeviceManagerServiceBase extends $grpc.Service {
  $core.String get $name => 'device_manager.DeviceManagerService';

  DeviceManagerServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.GetStatusRequest, $0.GetStatusResponse>(
        'GetStatus',
        getStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetStatusRequest.fromBuffer(value),
        ($0.GetStatusResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetConnectionPoolRequest,
            $0.GetConnectionPoolResponse>(
        'GetConnectionPool',
        getConnectionPool_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetConnectionPoolRequest.fromBuffer(value),
        ($0.GetConnectionPoolResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LockDeviceRequest, $0.LockDeviceResponse>(
        'LockDevice',
        lockDevice_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LockDeviceRequest.fromBuffer(value),
        ($0.LockDeviceResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UnlockDeviceRequest, $0.UnlockDeviceResponse>(
            'UnlockDevice',
            unlockDevice_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UnlockDeviceRequest.fromBuffer(value),
            ($0.UnlockDeviceResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetLocksRequest, $0.GetLocksResponse>(
        'GetLocks',
        getLocks_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetLocksRequest.fromBuffer(value),
        ($0.GetLocksResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetAvailableDevicesRequest,
            $0.GetAvailableDevicesResponse>(
        'GetAvailableDevices',
        getAvailableDevices_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetAvailableDevicesRequest.fromBuffer(value),
        ($0.GetAvailableDevicesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PingRequest, $0.PingResponse>(
        'Ping',
        ping_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PingRequest.fromBuffer(value),
        ($0.PingResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TracerouteRequest, $0.TracerouteResponse>(
        'Traceroute',
        traceroute_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.TracerouteRequest.fromBuffer(value),
        ($0.TracerouteResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ShowCommandRequest, $0.ShowCommandResponse>(
            'ShowCommand',
            showCommand_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ShowCommandRequest.fromBuffer(value),
            ($0.ShowCommandResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RawCommandRequest, $0.RawCommandResponse>(
        'RawCommand',
        rawCommand_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RawCommandRequest.fromBuffer(value),
        ($0.RawCommandResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ReapplyConfigRequest, $0.ReapplyConfigResponse>(
            'ReapplyConfig',
            reapplyConfig_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ReapplyConfigRequest.fromBuffer(value),
            ($0.ReapplyConfigResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Ping2Request, $0.Ping2Response>(
        'Ping2',
        ping2_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Ping2Request.fromBuffer(value),
        ($0.Ping2Response value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetStatusResponse> getStatus_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetStatusRequest> $request) async {
    return getStatus($call, await $request);
  }

  $async.Future<$0.GetStatusResponse> getStatus(
      $grpc.ServiceCall call, $0.GetStatusRequest request);

  $async.Future<$0.GetConnectionPoolResponse> getConnectionPool_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetConnectionPoolRequest> $request) async {
    return getConnectionPool($call, await $request);
  }

  $async.Future<$0.GetConnectionPoolResponse> getConnectionPool(
      $grpc.ServiceCall call, $0.GetConnectionPoolRequest request);

  $async.Future<$0.LockDeviceResponse> lockDevice_Pre($grpc.ServiceCall $call,
      $async.Future<$0.LockDeviceRequest> $request) async {
    return lockDevice($call, await $request);
  }

  $async.Future<$0.LockDeviceResponse> lockDevice(
      $grpc.ServiceCall call, $0.LockDeviceRequest request);

  $async.Future<$0.UnlockDeviceResponse> unlockDevice_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UnlockDeviceRequest> $request) async {
    return unlockDevice($call, await $request);
  }

  $async.Future<$0.UnlockDeviceResponse> unlockDevice(
      $grpc.ServiceCall call, $0.UnlockDeviceRequest request);

  $async.Future<$0.GetLocksResponse> getLocks_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetLocksRequest> $request) async {
    return getLocks($call, await $request);
  }

  $async.Future<$0.GetLocksResponse> getLocks(
      $grpc.ServiceCall call, $0.GetLocksRequest request);

  $async.Future<$0.GetAvailableDevicesResponse> getAvailableDevices_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetAvailableDevicesRequest> $request) async {
    return getAvailableDevices($call, await $request);
  }

  $async.Future<$0.GetAvailableDevicesResponse> getAvailableDevices(
      $grpc.ServiceCall call, $0.GetAvailableDevicesRequest request);

  $async.Future<$0.PingResponse> ping_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PingRequest> $request) async {
    return ping($call, await $request);
  }

  $async.Future<$0.PingResponse> ping(
      $grpc.ServiceCall call, $0.PingRequest request);

  $async.Future<$0.TracerouteResponse> traceroute_Pre($grpc.ServiceCall $call,
      $async.Future<$0.TracerouteRequest> $request) async {
    return traceroute($call, await $request);
  }

  $async.Future<$0.TracerouteResponse> traceroute(
      $grpc.ServiceCall call, $0.TracerouteRequest request);

  $async.Future<$0.ShowCommandResponse> showCommand_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ShowCommandRequest> $request) async {
    return showCommand($call, await $request);
  }

  $async.Future<$0.ShowCommandResponse> showCommand(
      $grpc.ServiceCall call, $0.ShowCommandRequest request);

  $async.Future<$0.RawCommandResponse> rawCommand_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RawCommandRequest> $request) async {
    return rawCommand($call, await $request);
  }

  $async.Future<$0.RawCommandResponse> rawCommand(
      $grpc.ServiceCall call, $0.RawCommandRequest request);

  $async.Future<$0.ReapplyConfigResponse> reapplyConfig_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ReapplyConfigRequest> $request) async {
    return reapplyConfig($call, await $request);
  }

  $async.Future<$0.ReapplyConfigResponse> reapplyConfig(
      $grpc.ServiceCall call, $0.ReapplyConfigRequest request);

  $async.Future<$0.Ping2Response> ping2_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Ping2Request> $request) async {
    return ping2($call, await $request);
  }

  $async.Future<$0.Ping2Response> ping2(
      $grpc.ServiceCall call, $0.Ping2Request request);
}
