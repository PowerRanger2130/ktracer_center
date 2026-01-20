// This is a generated file - do not edit.
//
// Generated from device_manager.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class GetStatusRequest extends $pb.GeneratedMessage {
  factory GetStatusRequest() => create();

  GetStatusRequest._();

  factory GetStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatusRequest copyWith(void Function(GetStatusRequest) updates) =>
      super.copyWith((message) => updates(message as GetStatusRequest))
          as GetStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStatusRequest create() => GetStatusRequest._();
  @$core.override
  GetStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStatusRequest>(create);
  static GetStatusRequest? _defaultInstance;
}

class GetStatusResponse extends $pb.GeneratedMessage {
  factory GetStatusResponse({
    $core.bool? isRunning,
    $core.int? healthyConnections,
    $core.int? totalConnections,
    $core.int? lockedDevices,
    $core.int? ownedLocks,
    $core.Iterable<$core.int>? healthyRealIds,
    $core.Iterable<$core.int>? lockedRealIds,
  }) {
    final result = create();
    if (isRunning != null) result.isRunning = isRunning;
    if (healthyConnections != null)
      result.healthyConnections = healthyConnections;
    if (totalConnections != null) result.totalConnections = totalConnections;
    if (lockedDevices != null) result.lockedDevices = lockedDevices;
    if (ownedLocks != null) result.ownedLocks = ownedLocks;
    if (healthyRealIds != null) result.healthyRealIds.addAll(healthyRealIds);
    if (lockedRealIds != null) result.lockedRealIds.addAll(lockedRealIds);
    return result;
  }

  GetStatusResponse._();

  factory GetStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'isRunning')
    ..aI(2, _omitFieldNames ? '' : 'healthyConnections')
    ..aI(3, _omitFieldNames ? '' : 'totalConnections')
    ..aI(4, _omitFieldNames ? '' : 'lockedDevices')
    ..aI(5, _omitFieldNames ? '' : 'ownedLocks')
    ..p<$core.int>(
        6, _omitFieldNames ? '' : 'healthyRealIds', $pb.PbFieldType.K3)
    ..p<$core.int>(
        7, _omitFieldNames ? '' : 'lockedRealIds', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetStatusResponse copyWith(void Function(GetStatusResponse) updates) =>
      super.copyWith((message) => updates(message as GetStatusResponse))
          as GetStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetStatusResponse create() => GetStatusResponse._();
  @$core.override
  GetStatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetStatusResponse>(create);
  static GetStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isRunning => $_getBF(0);
  @$pb.TagNumber(1)
  set isRunning($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsRunning() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsRunning() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get healthyConnections => $_getIZ(1);
  @$pb.TagNumber(2)
  set healthyConnections($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHealthyConnections() => $_has(1);
  @$pb.TagNumber(2)
  void clearHealthyConnections() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get totalConnections => $_getIZ(2);
  @$pb.TagNumber(3)
  set totalConnections($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalConnections() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalConnections() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get lockedDevices => $_getIZ(3);
  @$pb.TagNumber(4)
  set lockedDevices($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLockedDevices() => $_has(3);
  @$pb.TagNumber(4)
  void clearLockedDevices() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get ownedLocks => $_getIZ(4);
  @$pb.TagNumber(5)
  set ownedLocks($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOwnedLocks() => $_has(4);
  @$pb.TagNumber(5)
  void clearOwnedLocks() => $_clearField(5);

  @$pb.TagNumber(6)
  $pb.PbList<$core.int> get healthyRealIds => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<$core.int> get lockedRealIds => $_getList(6);
}

class GetConnectionPoolRequest extends $pb.GeneratedMessage {
  factory GetConnectionPoolRequest() => create();

  GetConnectionPoolRequest._();

  factory GetConnectionPoolRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetConnectionPoolRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetConnectionPoolRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetConnectionPoolRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetConnectionPoolRequest copyWith(
          void Function(GetConnectionPoolRequest) updates) =>
      super.copyWith((message) => updates(message as GetConnectionPoolRequest))
          as GetConnectionPoolRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetConnectionPoolRequest create() => GetConnectionPoolRequest._();
  @$core.override
  GetConnectionPoolRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetConnectionPoolRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetConnectionPoolRequest>(create);
  static GetConnectionPoolRequest? _defaultInstance;
}

class GetConnectionPoolResponse extends $pb.GeneratedMessage {
  factory GetConnectionPoolResponse({
    $core.bool? isRunning,
    $core.int? totalConnections,
    $core.int? healthyCount,
    $core.Iterable<$core.int>? healthy,
    $core.Iterable<$core.int>? unhealthy,
    $core.Iterable<$core.int>? disconnected,
    $core.Iterable<$core.int>? missing,
  }) {
    final result = create();
    if (isRunning != null) result.isRunning = isRunning;
    if (totalConnections != null) result.totalConnections = totalConnections;
    if (healthyCount != null) result.healthyCount = healthyCount;
    if (healthy != null) result.healthy.addAll(healthy);
    if (unhealthy != null) result.unhealthy.addAll(unhealthy);
    if (disconnected != null) result.disconnected.addAll(disconnected);
    if (missing != null) result.missing.addAll(missing);
    return result;
  }

  GetConnectionPoolResponse._();

  factory GetConnectionPoolResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetConnectionPoolResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetConnectionPoolResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'isRunning')
    ..aI(2, _omitFieldNames ? '' : 'totalConnections')
    ..aI(3, _omitFieldNames ? '' : 'healthyCount')
    ..p<$core.int>(4, _omitFieldNames ? '' : 'healthy', $pb.PbFieldType.K3)
    ..p<$core.int>(5, _omitFieldNames ? '' : 'unhealthy', $pb.PbFieldType.K3)
    ..p<$core.int>(6, _omitFieldNames ? '' : 'disconnected', $pb.PbFieldType.K3)
    ..p<$core.int>(7, _omitFieldNames ? '' : 'missing', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetConnectionPoolResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetConnectionPoolResponse copyWith(
          void Function(GetConnectionPoolResponse) updates) =>
      super.copyWith((message) => updates(message as GetConnectionPoolResponse))
          as GetConnectionPoolResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetConnectionPoolResponse create() => GetConnectionPoolResponse._();
  @$core.override
  GetConnectionPoolResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetConnectionPoolResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetConnectionPoolResponse>(create);
  static GetConnectionPoolResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isRunning => $_getBF(0);
  @$pb.TagNumber(1)
  set isRunning($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsRunning() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsRunning() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get totalConnections => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalConnections($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalConnections() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalConnections() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get healthyCount => $_getIZ(2);
  @$pb.TagNumber(3)
  set healthyCount($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHealthyCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearHealthyCount() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.int> get healthy => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$core.int> get unhealthy => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<$core.int> get disconnected => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<$core.int> get missing => $_getList(6);
}

class LockDeviceRequest extends $pb.GeneratedMessage {
  factory LockDeviceRequest({
    $fixnum.Int64? deviceId,
    $fixnum.Int64? projectId,
    $core.int? presetId,
    $core.int? preferredRealId,
    $core.String? reason,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (projectId != null) result.projectId = projectId;
    if (presetId != null) result.presetId = presetId;
    if (preferredRealId != null) result.preferredRealId = preferredRealId;
    if (reason != null) result.reason = reason;
    return result;
  }

  LockDeviceRequest._();

  factory LockDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LockDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LockDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'deviceId')
    ..aInt64(2, _omitFieldNames ? '' : 'projectId')
    ..aI(3, _omitFieldNames ? '' : 'presetId')
    ..aI(4, _omitFieldNames ? '' : 'preferredRealId')
    ..aOS(5, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LockDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LockDeviceRequest copyWith(void Function(LockDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as LockDeviceRequest))
          as LockDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LockDeviceRequest create() => LockDeviceRequest._();
  @$core.override
  LockDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LockDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LockDeviceRequest>(create);
  static LockDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get deviceId => $_getI64(0);
  @$pb.TagNumber(1)
  set deviceId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get projectId => $_getI64(1);
  @$pb.TagNumber(2)
  set projectId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProjectId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProjectId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get presetId => $_getIZ(2);
  @$pb.TagNumber(3)
  set presetId($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPresetId() => $_has(2);
  @$pb.TagNumber(3)
  void clearPresetId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get preferredRealId => $_getIZ(3);
  @$pb.TagNumber(4)
  set preferredRealId($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPreferredRealId() => $_has(3);
  @$pb.TagNumber(4)
  void clearPreferredRealId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get reason => $_getSZ(4);
  @$pb.TagNumber(5)
  set reason($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReason() => $_has(4);
  @$pb.TagNumber(5)
  void clearReason() => $_clearField(5);
}

class LockDeviceResponse extends $pb.GeneratedMessage {
  factory LockDeviceResponse({
    $core.bool? success,
    $core.int? assignedRealId,
    $fixnum.Int64? lockId,
    $core.String? error,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (assignedRealId != null) result.assignedRealId = assignedRealId;
    if (lockId != null) result.lockId = lockId;
    if (error != null) result.error = error;
    return result;
  }

  LockDeviceResponse._();

  factory LockDeviceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LockDeviceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LockDeviceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aI(2, _omitFieldNames ? '' : 'assignedRealId')
    ..aInt64(3, _omitFieldNames ? '' : 'lockId')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LockDeviceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LockDeviceResponse copyWith(void Function(LockDeviceResponse) updates) =>
      super.copyWith((message) => updates(message as LockDeviceResponse))
          as LockDeviceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LockDeviceResponse create() => LockDeviceResponse._();
  @$core.override
  LockDeviceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LockDeviceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LockDeviceResponse>(create);
  static LockDeviceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get assignedRealId => $_getIZ(1);
  @$pb.TagNumber(2)
  set assignedRealId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAssignedRealId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAssignedRealId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get lockId => $_getI64(2);
  @$pb.TagNumber(3)
  set lockId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLockId() => $_has(2);
  @$pb.TagNumber(3)
  void clearLockId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);
}

class UnlockDeviceRequest extends $pb.GeneratedMessage {
  factory UnlockDeviceRequest({
    $fixnum.Int64? deviceId,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    return result;
  }

  UnlockDeviceRequest._();

  factory UnlockDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnlockDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnlockDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'deviceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlockDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlockDeviceRequest copyWith(void Function(UnlockDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as UnlockDeviceRequest))
          as UnlockDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnlockDeviceRequest create() => UnlockDeviceRequest._();
  @$core.override
  UnlockDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnlockDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnlockDeviceRequest>(create);
  static UnlockDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get deviceId => $_getI64(0);
  @$pb.TagNumber(1)
  set deviceId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);
}

class UnlockDeviceResponse extends $pb.GeneratedMessage {
  factory UnlockDeviceResponse({
    $core.bool? success,
    $core.String? error,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (error != null) result.error = error;
    return result;
  }

  UnlockDeviceResponse._();

  factory UnlockDeviceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnlockDeviceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnlockDeviceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlockDeviceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnlockDeviceResponse copyWith(void Function(UnlockDeviceResponse) updates) =>
      super.copyWith((message) => updates(message as UnlockDeviceResponse))
          as UnlockDeviceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnlockDeviceResponse create() => UnlockDeviceResponse._();
  @$core.override
  UnlockDeviceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnlockDeviceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnlockDeviceResponse>(create);
  static UnlockDeviceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

class GetLocksRequest extends $pb.GeneratedMessage {
  factory GetLocksRequest({
    $core.bool? ownedOnly,
  }) {
    final result = create();
    if (ownedOnly != null) result.ownedOnly = ownedOnly;
    return result;
  }

  GetLocksRequest._();

  factory GetLocksRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetLocksRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetLocksRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ownedOnly')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetLocksRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetLocksRequest copyWith(void Function(GetLocksRequest) updates) =>
      super.copyWith((message) => updates(message as GetLocksRequest))
          as GetLocksRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetLocksRequest create() => GetLocksRequest._();
  @$core.override
  GetLocksRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetLocksRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetLocksRequest>(create);
  static GetLocksRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ownedOnly => $_getBF(0);
  @$pb.TagNumber(1)
  set ownedOnly($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOwnedOnly() => $_has(0);
  @$pb.TagNumber(1)
  void clearOwnedOnly() => $_clearField(1);
}

class DeviceLockInfo extends $pb.GeneratedMessage {
  factory DeviceLockInfo({
    $fixnum.Int64? id,
    $fixnum.Int64? deviceId,
    $fixnum.Int64? projectId,
    $core.int? realId,
    $core.int? clientId,
    $core.String? lockedAt,
    $core.String? reason,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (deviceId != null) result.deviceId = deviceId;
    if (projectId != null) result.projectId = projectId;
    if (realId != null) result.realId = realId;
    if (clientId != null) result.clientId = clientId;
    if (lockedAt != null) result.lockedAt = lockedAt;
    if (reason != null) result.reason = reason;
    return result;
  }

  DeviceLockInfo._();

  factory DeviceLockInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceLockInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceLockInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'deviceId')
    ..aInt64(3, _omitFieldNames ? '' : 'projectId')
    ..aI(4, _omitFieldNames ? '' : 'realId')
    ..aI(5, _omitFieldNames ? '' : 'clientId')
    ..aOS(6, _omitFieldNames ? '' : 'lockedAt')
    ..aOS(7, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceLockInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceLockInfo copyWith(void Function(DeviceLockInfo) updates) =>
      super.copyWith((message) => updates(message as DeviceLockInfo))
          as DeviceLockInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceLockInfo create() => DeviceLockInfo._();
  @$core.override
  DeviceLockInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceLockInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceLockInfo>(create);
  static DeviceLockInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get deviceId => $_getI64(1);
  @$pb.TagNumber(2)
  set deviceId($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get projectId => $_getI64(2);
  @$pb.TagNumber(3)
  set projectId($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProjectId() => $_has(2);
  @$pb.TagNumber(3)
  void clearProjectId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get realId => $_getIZ(3);
  @$pb.TagNumber(4)
  set realId($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRealId() => $_has(3);
  @$pb.TagNumber(4)
  void clearRealId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get clientId => $_getIZ(4);
  @$pb.TagNumber(5)
  set clientId($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasClientId() => $_has(4);
  @$pb.TagNumber(5)
  void clearClientId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get lockedAt => $_getSZ(5);
  @$pb.TagNumber(6)
  set lockedAt($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLockedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearLockedAt() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get reason => $_getSZ(6);
  @$pb.TagNumber(7)
  set reason($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasReason() => $_has(6);
  @$pb.TagNumber(7)
  void clearReason() => $_clearField(7);
}

class GetLocksResponse extends $pb.GeneratedMessage {
  factory GetLocksResponse({
    $core.Iterable<DeviceLockInfo>? locks,
    $core.Iterable<$core.int>? lockedRealIds,
  }) {
    final result = create();
    if (locks != null) result.locks.addAll(locks);
    if (lockedRealIds != null) result.lockedRealIds.addAll(lockedRealIds);
    return result;
  }

  GetLocksResponse._();

  factory GetLocksResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetLocksResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetLocksResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..pPM<DeviceLockInfo>(1, _omitFieldNames ? '' : 'locks',
        subBuilder: DeviceLockInfo.create)
    ..p<$core.int>(
        2, _omitFieldNames ? '' : 'lockedRealIds', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetLocksResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetLocksResponse copyWith(void Function(GetLocksResponse) updates) =>
      super.copyWith((message) => updates(message as GetLocksResponse))
          as GetLocksResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetLocksResponse create() => GetLocksResponse._();
  @$core.override
  GetLocksResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetLocksResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetLocksResponse>(create);
  static GetLocksResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DeviceLockInfo> get locks => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<$core.int> get lockedRealIds => $_getList(1);
}

class GetAvailableDevicesRequest extends $pb.GeneratedMessage {
  factory GetAvailableDevicesRequest({
    $core.int? presetId,
  }) {
    final result = create();
    if (presetId != null) result.presetId = presetId;
    return result;
  }

  GetAvailableDevicesRequest._();

  factory GetAvailableDevicesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAvailableDevicesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAvailableDevicesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'presetId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAvailableDevicesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAvailableDevicesRequest copyWith(
          void Function(GetAvailableDevicesRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetAvailableDevicesRequest))
          as GetAvailableDevicesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAvailableDevicesRequest create() => GetAvailableDevicesRequest._();
  @$core.override
  GetAvailableDevicesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAvailableDevicesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAvailableDevicesRequest>(create);
  static GetAvailableDevicesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get presetId => $_getIZ(0);
  @$pb.TagNumber(1)
  set presetId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPresetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPresetId() => $_clearField(1);
}

class GetAvailableDevicesResponse extends $pb.GeneratedMessage {
  factory GetAvailableDevicesResponse({
    $core.Iterable<$core.int>? availableRealIds,
    $core.int? totalCount,
  }) {
    final result = create();
    if (availableRealIds != null)
      result.availableRealIds.addAll(availableRealIds);
    if (totalCount != null) result.totalCount = totalCount;
    return result;
  }

  GetAvailableDevicesResponse._();

  factory GetAvailableDevicesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAvailableDevicesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAvailableDevicesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..p<$core.int>(
        1, _omitFieldNames ? '' : 'availableRealIds', $pb.PbFieldType.K3)
    ..aI(2, _omitFieldNames ? '' : 'totalCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAvailableDevicesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAvailableDevicesResponse copyWith(
          void Function(GetAvailableDevicesResponse) updates) =>
      super.copyWith(
              (message) => updates(message as GetAvailableDevicesResponse))
          as GetAvailableDevicesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAvailableDevicesResponse create() =>
      GetAvailableDevicesResponse._();
  @$core.override
  GetAvailableDevicesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAvailableDevicesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAvailableDevicesResponse>(create);
  static GetAvailableDevicesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.int> get availableRealIds => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get totalCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalCount() => $_clearField(2);
}

enum PingRequest_TargetDevice { deviceId, realId, notSet }

class PingRequest extends $pb.GeneratedMessage {
  factory PingRequest({
    $fixnum.Int64? deviceId,
    $core.int? realId,
    $core.String? target,
    $core.int? count,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (realId != null) result.realId = realId;
    if (target != null) result.target = target;
    if (count != null) result.count = count;
    return result;
  }

  PingRequest._();

  factory PingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, PingRequest_TargetDevice>
      _PingRequest_TargetDeviceByTag = {
    1: PingRequest_TargetDevice.deviceId,
    2: PingRequest_TargetDevice.realId,
    0: PingRequest_TargetDevice.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aInt64(1, _omitFieldNames ? '' : 'deviceId')
    ..aI(2, _omitFieldNames ? '' : 'realId')
    ..aOS(3, _omitFieldNames ? '' : 'target')
    ..aI(4, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingRequest copyWith(void Function(PingRequest) updates) =>
      super.copyWith((message) => updates(message as PingRequest))
          as PingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PingRequest create() => PingRequest._();
  @$core.override
  PingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PingRequest>(create);
  static PingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  PingRequest_TargetDevice whichTargetDevice() =>
      _PingRequest_TargetDeviceByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearTargetDevice() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get deviceId => $_getI64(0);
  @$pb.TagNumber(1)
  set deviceId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get realId => $_getIZ(1);
  @$pb.TagNumber(2)
  set realId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRealId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRealId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get target => $_getSZ(2);
  @$pb.TagNumber(3)
  set target($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTarget() => $_has(2);
  @$pb.TagNumber(3)
  void clearTarget() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get count => $_getIZ(3);
  @$pb.TagNumber(4)
  set count($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearCount() => $_clearField(4);
}

class PingResponse extends $pb.GeneratedMessage {
  factory PingResponse({
    $core.bool? success,
    $core.int? realId,
    $core.String? output,
    $core.String? error,
    $core.int? packetsSent,
    $core.int? packetsReceived,
    $core.int? packetsLost,
    $core.double? successRate,
    $core.int? minRtt,
    $core.int? avgRtt,
    $core.int? maxRtt,
    $fixnum.Int64? durationMs,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (realId != null) result.realId = realId;
    if (output != null) result.output = output;
    if (error != null) result.error = error;
    if (packetsSent != null) result.packetsSent = packetsSent;
    if (packetsReceived != null) result.packetsReceived = packetsReceived;
    if (packetsLost != null) result.packetsLost = packetsLost;
    if (successRate != null) result.successRate = successRate;
    if (minRtt != null) result.minRtt = minRtt;
    if (avgRtt != null) result.avgRtt = avgRtt;
    if (maxRtt != null) result.maxRtt = maxRtt;
    if (durationMs != null) result.durationMs = durationMs;
    return result;
  }

  PingResponse._();

  factory PingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aI(2, _omitFieldNames ? '' : 'realId')
    ..aOS(3, _omitFieldNames ? '' : 'output')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..aI(5, _omitFieldNames ? '' : 'packetsSent')
    ..aI(6, _omitFieldNames ? '' : 'packetsReceived')
    ..aI(7, _omitFieldNames ? '' : 'packetsLost')
    ..aD(8, _omitFieldNames ? '' : 'successRate')
    ..aI(9, _omitFieldNames ? '' : 'minRtt')
    ..aI(10, _omitFieldNames ? '' : 'avgRtt')
    ..aI(11, _omitFieldNames ? '' : 'maxRtt')
    ..aInt64(12, _omitFieldNames ? '' : 'durationMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingResponse copyWith(void Function(PingResponse) updates) =>
      super.copyWith((message) => updates(message as PingResponse))
          as PingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PingResponse create() => PingResponse._();
  @$core.override
  PingResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PingResponse>(create);
  static PingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get realId => $_getIZ(1);
  @$pb.TagNumber(2)
  set realId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRealId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRealId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get output => $_getSZ(2);
  @$pb.TagNumber(3)
  set output($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOutput() => $_has(2);
  @$pb.TagNumber(3)
  void clearOutput() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get packetsSent => $_getIZ(4);
  @$pb.TagNumber(5)
  set packetsSent($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPacketsSent() => $_has(4);
  @$pb.TagNumber(5)
  void clearPacketsSent() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get packetsReceived => $_getIZ(5);
  @$pb.TagNumber(6)
  set packetsReceived($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPacketsReceived() => $_has(5);
  @$pb.TagNumber(6)
  void clearPacketsReceived() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get packetsLost => $_getIZ(6);
  @$pb.TagNumber(7)
  set packetsLost($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPacketsLost() => $_has(6);
  @$pb.TagNumber(7)
  void clearPacketsLost() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get successRate => $_getN(7);
  @$pb.TagNumber(8)
  set successRate($core.double value) => $_setDouble(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSuccessRate() => $_has(7);
  @$pb.TagNumber(8)
  void clearSuccessRate() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get minRtt => $_getIZ(8);
  @$pb.TagNumber(9)
  set minRtt($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMinRtt() => $_has(8);
  @$pb.TagNumber(9)
  void clearMinRtt() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get avgRtt => $_getIZ(9);
  @$pb.TagNumber(10)
  set avgRtt($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAvgRtt() => $_has(9);
  @$pb.TagNumber(10)
  void clearAvgRtt() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get maxRtt => $_getIZ(10);
  @$pb.TagNumber(11)
  set maxRtt($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasMaxRtt() => $_has(10);
  @$pb.TagNumber(11)
  void clearMaxRtt() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get durationMs => $_getI64(11);
  @$pb.TagNumber(12)
  set durationMs($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasDurationMs() => $_has(11);
  @$pb.TagNumber(12)
  void clearDurationMs() => $_clearField(12);
}

enum TracerouteRequest_TargetDevice { deviceId, realId, notSet }

class TracerouteRequest extends $pb.GeneratedMessage {
  factory TracerouteRequest({
    $fixnum.Int64? deviceId,
    $core.int? realId,
    $core.String? target,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (realId != null) result.realId = realId;
    if (target != null) result.target = target;
    return result;
  }

  TracerouteRequest._();

  factory TracerouteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TracerouteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, TracerouteRequest_TargetDevice>
      _TracerouteRequest_TargetDeviceByTag = {
    1: TracerouteRequest_TargetDevice.deviceId,
    2: TracerouteRequest_TargetDevice.realId,
    0: TracerouteRequest_TargetDevice.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TracerouteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aInt64(1, _omitFieldNames ? '' : 'deviceId')
    ..aI(2, _omitFieldNames ? '' : 'realId')
    ..aOS(3, _omitFieldNames ? '' : 'target')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TracerouteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TracerouteRequest copyWith(void Function(TracerouteRequest) updates) =>
      super.copyWith((message) => updates(message as TracerouteRequest))
          as TracerouteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TracerouteRequest create() => TracerouteRequest._();
  @$core.override
  TracerouteRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TracerouteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TracerouteRequest>(create);
  static TracerouteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  TracerouteRequest_TargetDevice whichTargetDevice() =>
      _TracerouteRequest_TargetDeviceByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearTargetDevice() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get deviceId => $_getI64(0);
  @$pb.TagNumber(1)
  set deviceId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get realId => $_getIZ(1);
  @$pb.TagNumber(2)
  set realId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRealId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRealId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get target => $_getSZ(2);
  @$pb.TagNumber(3)
  set target($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTarget() => $_has(2);
  @$pb.TagNumber(3)
  void clearTarget() => $_clearField(3);
}

class TracerouteHop extends $pb.GeneratedMessage {
  factory TracerouteHop({
    $core.int? hopNumber,
    $core.String? address,
    $core.String? hostname,
    $core.Iterable<$core.int>? rttMs,
    $core.bool? isTimeout,
  }) {
    final result = create();
    if (hopNumber != null) result.hopNumber = hopNumber;
    if (address != null) result.address = address;
    if (hostname != null) result.hostname = hostname;
    if (rttMs != null) result.rttMs.addAll(rttMs);
    if (isTimeout != null) result.isTimeout = isTimeout;
    return result;
  }

  TracerouteHop._();

  factory TracerouteHop.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TracerouteHop.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TracerouteHop',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'hopNumber')
    ..aOS(2, _omitFieldNames ? '' : 'address')
    ..aOS(3, _omitFieldNames ? '' : 'hostname')
    ..p<$core.int>(4, _omitFieldNames ? '' : 'rttMs', $pb.PbFieldType.K3)
    ..aOB(5, _omitFieldNames ? '' : 'isTimeout')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TracerouteHop clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TracerouteHop copyWith(void Function(TracerouteHop) updates) =>
      super.copyWith((message) => updates(message as TracerouteHop))
          as TracerouteHop;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TracerouteHop create() => TracerouteHop._();
  @$core.override
  TracerouteHop createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TracerouteHop getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TracerouteHop>(create);
  static TracerouteHop? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get hopNumber => $_getIZ(0);
  @$pb.TagNumber(1)
  set hopNumber($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHopNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearHopNumber() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get address => $_getSZ(1);
  @$pb.TagNumber(2)
  set address($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAddress() => $_has(1);
  @$pb.TagNumber(2)
  void clearAddress() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get hostname => $_getSZ(2);
  @$pb.TagNumber(3)
  set hostname($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHostname() => $_has(2);
  @$pb.TagNumber(3)
  void clearHostname() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.int> get rttMs => $_getList(3);

  @$pb.TagNumber(5)
  $core.bool get isTimeout => $_getBF(4);
  @$pb.TagNumber(5)
  set isTimeout($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsTimeout() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsTimeout() => $_clearField(5);
}

class TracerouteResponse extends $pb.GeneratedMessage {
  factory TracerouteResponse({
    $core.bool? success,
    $core.int? realId,
    $core.String? output,
    $core.String? error,
    $core.Iterable<TracerouteHop>? hops,
    $core.bool? reachedDestination,
    $fixnum.Int64? durationMs,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (realId != null) result.realId = realId;
    if (output != null) result.output = output;
    if (error != null) result.error = error;
    if (hops != null) result.hops.addAll(hops);
    if (reachedDestination != null)
      result.reachedDestination = reachedDestination;
    if (durationMs != null) result.durationMs = durationMs;
    return result;
  }

  TracerouteResponse._();

  factory TracerouteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TracerouteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TracerouteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aI(2, _omitFieldNames ? '' : 'realId')
    ..aOS(3, _omitFieldNames ? '' : 'output')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..pPM<TracerouteHop>(5, _omitFieldNames ? '' : 'hops',
        subBuilder: TracerouteHop.create)
    ..aOB(6, _omitFieldNames ? '' : 'reachedDestination')
    ..aInt64(7, _omitFieldNames ? '' : 'durationMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TracerouteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TracerouteResponse copyWith(void Function(TracerouteResponse) updates) =>
      super.copyWith((message) => updates(message as TracerouteResponse))
          as TracerouteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TracerouteResponse create() => TracerouteResponse._();
  @$core.override
  TracerouteResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TracerouteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TracerouteResponse>(create);
  static TracerouteResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get realId => $_getIZ(1);
  @$pb.TagNumber(2)
  set realId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRealId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRealId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get output => $_getSZ(2);
  @$pb.TagNumber(3)
  set output($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOutput() => $_has(2);
  @$pb.TagNumber(3)
  void clearOutput() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<TracerouteHop> get hops => $_getList(4);

  @$pb.TagNumber(6)
  $core.bool get reachedDestination => $_getBF(5);
  @$pb.TagNumber(6)
  set reachedDestination($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasReachedDestination() => $_has(5);
  @$pb.TagNumber(6)
  void clearReachedDestination() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get durationMs => $_getI64(6);
  @$pb.TagNumber(7)
  set durationMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDurationMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearDurationMs() => $_clearField(7);
}

enum ShowCommandRequest_TargetDevice { deviceId, realId, notSet }

class ShowCommandRequest extends $pb.GeneratedMessage {
  factory ShowCommandRequest({
    $fixnum.Int64? deviceId,
    $core.int? realId,
    $core.String? command,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (realId != null) result.realId = realId;
    if (command != null) result.command = command;
    return result;
  }

  ShowCommandRequest._();

  factory ShowCommandRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShowCommandRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ShowCommandRequest_TargetDevice>
      _ShowCommandRequest_TargetDeviceByTag = {
    1: ShowCommandRequest_TargetDevice.deviceId,
    2: ShowCommandRequest_TargetDevice.realId,
    0: ShowCommandRequest_TargetDevice.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShowCommandRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..oo(0, [1, 2])
    ..aInt64(1, _omitFieldNames ? '' : 'deviceId')
    ..aI(2, _omitFieldNames ? '' : 'realId')
    ..aOS(3, _omitFieldNames ? '' : 'command')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShowCommandRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShowCommandRequest copyWith(void Function(ShowCommandRequest) updates) =>
      super.copyWith((message) => updates(message as ShowCommandRequest))
          as ShowCommandRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShowCommandRequest create() => ShowCommandRequest._();
  @$core.override
  ShowCommandRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShowCommandRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShowCommandRequest>(create);
  static ShowCommandRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  ShowCommandRequest_TargetDevice whichTargetDevice() =>
      _ShowCommandRequest_TargetDeviceByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearTargetDevice() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $fixnum.Int64 get deviceId => $_getI64(0);
  @$pb.TagNumber(1)
  set deviceId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get realId => $_getIZ(1);
  @$pb.TagNumber(2)
  set realId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRealId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRealId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get command => $_getSZ(2);
  @$pb.TagNumber(3)
  set command($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommand() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommand() => $_clearField(3);
}

class ShowCommandResponse extends $pb.GeneratedMessage {
  factory ShowCommandResponse({
    $core.bool? success,
    $core.int? realId,
    $core.String? output,
    $core.String? error,
    $fixnum.Int64? durationMs,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (realId != null) result.realId = realId;
    if (output != null) result.output = output;
    if (error != null) result.error = error;
    if (durationMs != null) result.durationMs = durationMs;
    return result;
  }

  ShowCommandResponse._();

  factory ShowCommandResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShowCommandResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShowCommandResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aI(2, _omitFieldNames ? '' : 'realId')
    ..aOS(3, _omitFieldNames ? '' : 'output')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..aInt64(5, _omitFieldNames ? '' : 'durationMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShowCommandResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShowCommandResponse copyWith(void Function(ShowCommandResponse) updates) =>
      super.copyWith((message) => updates(message as ShowCommandResponse))
          as ShowCommandResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShowCommandResponse create() => ShowCommandResponse._();
  @$core.override
  ShowCommandResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShowCommandResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShowCommandResponse>(create);
  static ShowCommandResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get realId => $_getIZ(1);
  @$pb.TagNumber(2)
  set realId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRealId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRealId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get output => $_getSZ(2);
  @$pb.TagNumber(3)
  set output($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOutput() => $_has(2);
  @$pb.TagNumber(3)
  void clearOutput() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get durationMs => $_getI64(4);
  @$pb.TagNumber(5)
  set durationMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDurationMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearDurationMs() => $_clearField(5);
}

class RawCommandRequest extends $pb.GeneratedMessage {
  factory RawCommandRequest({
    $core.int? realId,
    $core.String? command,
  }) {
    final result = create();
    if (realId != null) result.realId = realId;
    if (command != null) result.command = command;
    return result;
  }

  RawCommandRequest._();

  factory RawCommandRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RawCommandRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RawCommandRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'realId')
    ..aOS(2, _omitFieldNames ? '' : 'command')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RawCommandRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RawCommandRequest copyWith(void Function(RawCommandRequest) updates) =>
      super.copyWith((message) => updates(message as RawCommandRequest))
          as RawCommandRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RawCommandRequest create() => RawCommandRequest._();
  @$core.override
  RawCommandRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RawCommandRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RawCommandRequest>(create);
  static RawCommandRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get realId => $_getIZ(0);
  @$pb.TagNumber(1)
  set realId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRealId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRealId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get command => $_getSZ(1);
  @$pb.TagNumber(2)
  set command($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCommand() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommand() => $_clearField(2);
}

class RawCommandResponse extends $pb.GeneratedMessage {
  factory RawCommandResponse({
    $core.bool? success,
    $core.int? realId,
    $core.String? output,
    $core.String? error,
    $fixnum.Int64? durationMs,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (realId != null) result.realId = realId;
    if (output != null) result.output = output;
    if (error != null) result.error = error;
    if (durationMs != null) result.durationMs = durationMs;
    return result;
  }

  RawCommandResponse._();

  factory RawCommandResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RawCommandResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RawCommandResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aI(2, _omitFieldNames ? '' : 'realId')
    ..aOS(3, _omitFieldNames ? '' : 'output')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..aInt64(5, _omitFieldNames ? '' : 'durationMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RawCommandResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RawCommandResponse copyWith(void Function(RawCommandResponse) updates) =>
      super.copyWith((message) => updates(message as RawCommandResponse))
          as RawCommandResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RawCommandResponse create() => RawCommandResponse._();
  @$core.override
  RawCommandResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RawCommandResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RawCommandResponse>(create);
  static RawCommandResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get realId => $_getIZ(1);
  @$pb.TagNumber(2)
  set realId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRealId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRealId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get output => $_getSZ(2);
  @$pb.TagNumber(3)
  set output($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOutput() => $_has(2);
  @$pb.TagNumber(3)
  void clearOutput() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get durationMs => $_getI64(4);
  @$pb.TagNumber(5)
  set durationMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDurationMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearDurationMs() => $_clearField(5);
}

class ReapplyConfigRequest extends $pb.GeneratedMessage {
  factory ReapplyConfigRequest({
    $fixnum.Int64? deviceId,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    return result;
  }

  ReapplyConfigRequest._();

  factory ReapplyConfigRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReapplyConfigRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReapplyConfigRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'deviceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReapplyConfigRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReapplyConfigRequest copyWith(void Function(ReapplyConfigRequest) updates) =>
      super.copyWith((message) => updates(message as ReapplyConfigRequest))
          as ReapplyConfigRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReapplyConfigRequest create() => ReapplyConfigRequest._();
  @$core.override
  ReapplyConfigRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReapplyConfigRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReapplyConfigRequest>(create);
  static ReapplyConfigRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get deviceId => $_getI64(0);
  @$pb.TagNumber(1)
  set deviceId($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);
}

class ReapplyConfigResponse extends $pb.GeneratedMessage {
  factory ReapplyConfigResponse({
    $core.bool? success,
    $core.int? realId,
    $core.int? commandsSent,
    $core.String? error,
    $fixnum.Int64? durationMs,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (realId != null) result.realId = realId;
    if (commandsSent != null) result.commandsSent = commandsSent;
    if (error != null) result.error = error;
    if (durationMs != null) result.durationMs = durationMs;
    return result;
  }

  ReapplyConfigResponse._();

  factory ReapplyConfigResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReapplyConfigResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReapplyConfigResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aI(2, _omitFieldNames ? '' : 'realId')
    ..aI(3, _omitFieldNames ? '' : 'commandsSent')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..aInt64(5, _omitFieldNames ? '' : 'durationMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReapplyConfigResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReapplyConfigResponse copyWith(
          void Function(ReapplyConfigResponse) updates) =>
      super.copyWith((message) => updates(message as ReapplyConfigResponse))
          as ReapplyConfigResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReapplyConfigResponse create() => ReapplyConfigResponse._();
  @$core.override
  ReapplyConfigResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReapplyConfigResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReapplyConfigResponse>(create);
  static ReapplyConfigResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get realId => $_getIZ(1);
  @$pb.TagNumber(2)
  set realId($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRealId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRealId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get commandsSent => $_getIZ(2);
  @$pb.TagNumber(3)
  set commandsSent($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommandsSent() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommandsSent() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get durationMs => $_getI64(4);
  @$pb.TagNumber(5)
  set durationMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDurationMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearDurationMs() => $_clearField(5);
}

class Ping2Request extends $pb.GeneratedMessage {
  factory Ping2Request() => create();

  Ping2Request._();

  factory Ping2Request.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Ping2Request.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ping2Request',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ping2Request clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ping2Request copyWith(void Function(Ping2Request) updates) =>
      super.copyWith((message) => updates(message as Ping2Request))
          as Ping2Request;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ping2Request create() => Ping2Request._();
  @$core.override
  Ping2Request createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Ping2Request getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Ping2Request>(create);
  static Ping2Request? _defaultInstance;
}

class Ping2Response extends $pb.GeneratedMessage {
  factory Ping2Response({
    $core.String? status,
    $core.bool? isRunning,
    $core.int? healthyConnections,
    $core.int? lockedDevices,
  }) {
    final result = create();
    if (status != null) result.status = status;
    if (isRunning != null) result.isRunning = isRunning;
    if (healthyConnections != null)
      result.healthyConnections = healthyConnections;
    if (lockedDevices != null) result.lockedDevices = lockedDevices;
    return result;
  }

  Ping2Response._();

  factory Ping2Response.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Ping2Response.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ping2Response',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'device_manager'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'status')
    ..aOB(2, _omitFieldNames ? '' : 'isRunning')
    ..aI(3, _omitFieldNames ? '' : 'healthyConnections')
    ..aI(4, _omitFieldNames ? '' : 'lockedDevices')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ping2Response clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ping2Response copyWith(void Function(Ping2Response) updates) =>
      super.copyWith((message) => updates(message as Ping2Response))
          as Ping2Response;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ping2Response create() => Ping2Response._();
  @$core.override
  Ping2Response createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Ping2Response getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Ping2Response>(create);
  static Ping2Response? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get status => $_getSZ(0);
  @$pb.TagNumber(1)
  set status($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isRunning => $_getBF(1);
  @$pb.TagNumber(2)
  set isRunning($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsRunning() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsRunning() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get healthyConnections => $_getIZ(2);
  @$pb.TagNumber(3)
  set healthyConnections($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHealthyConnections() => $_has(2);
  @$pb.TagNumber(3)
  void clearHealthyConnections() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get lockedDevices => $_getIZ(3);
  @$pb.TagNumber(4)
  set lockedDevices($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLockedDevices() => $_has(3);
  @$pb.TagNumber(4)
  void clearLockedDevices() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
