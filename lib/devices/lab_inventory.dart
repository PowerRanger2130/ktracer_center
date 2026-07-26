import 'package:ktracer_center/devices/lab_config.dart';
export 'package:ktracer_center/devices/lab_config.dart' show LabDevice;

/// Represents a physical device in the lab.
/// Each entry is a reference to a preset (device type) with a unique real_id.
///
/// NOTE: This class is now deprecated. Use [LabDevice] from lab_config.dart instead.
/// This file provides backward compatibility by delegating to [LabConfig].

/// The physical inventory of devices in the lab.
/// Loaded from Supabase on startup.
///
/// Must call [LabConfig.initialize()] before using any methods.
class LabInventory {
  /// All devices in the lab
  static List<LabDevice> get devices => LabConfig.instance.devices;

  /// Get device by realId
  static LabDevice? getByRealId(int realId) {
    return LabConfig.instance.getDeviceByRealId(realId);
  }

  /// Get all devices with a specific preset
  static List<LabDevice> getByPresetId(int presetId) {
    return LabConfig.instance.getDevicesByPresetId(presetId);
  }

  /// Count how many devices of a preset exist in the lab
  static int countByPresetId(int presetId) {
    return LabConfig.instance.countByPresetId(presetId);
  }

  /// Get all assignable devices (excluding system-reserved ones)
  static List<LabDevice> getAssignableDevices() {
    return LabConfig.instance.getAssignableDevices();
  }

  /// Get assignable devices by preset (excluding system-reserved ones)
  static List<LabDevice> getAssignableByPresetId(int presetId) {
    return LabConfig.instance.getAssignableByPresetId(presetId);
  }

  /// Count how many assignable (non-reserved) devices of a preset exist
  static int countAssignableByPresetId(int presetId) {
    return LabConfig.instance.countAssignableByPresetId(presetId);
  }
}
