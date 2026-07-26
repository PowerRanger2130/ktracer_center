import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/devices/device_preset.dart';
import 'package:provider/provider.dart';

/// Shows a dialog to add a new device to the current project
Future<void> showAddDeviceDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => const AddDeviceDialog(),
  );
}

class AddDeviceDialog extends StatefulWidget {
  const AddDeviceDialog({super.key});

  @override
  State<AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<AddDeviceDialog> {
  String? _selectedCategory;
  DevicePreset? _selectedPreset;
  final TextEditingController _hostnameController = TextEditingController();
  bool _isLoading = false;

  List<DevicePreset> _getAvailablePresets(AppState appState) {
    if (_selectedCategory == null) return [];
    return DevicePresets.getByCategory(
      _selectedCategory!,
    ).where((p) => appState.isPresetAvailable(p.id)).toList();
  }

  /// Get categories that have at least one available preset
  List<String> _getAvailableCategories(AppState appState) {
    return DevicePresets.categories.where((category) {
      return DevicePresets.getByCategory(
        category,
      ).any((p) => appState.isPresetAvailable(p.id));
    }).toList();
  }

  @override
  void dispose() {
    _hostnameController.dispose();
    super.dispose();
  }

  Future<void> _addDevice() async {
    if (_selectedPreset == null) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AppState>().addDevice(_selectedPreset!.id);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Error'),
            content: Text('Failed to add device: $e'),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final availableCategories = _getAvailableCategories(appState);
    final availablePresets = _getAvailablePresets(appState);

    return ContentDialog(
      title: const Text('Add Device'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category'),
          const SizedBox(height: 4),
          ComboBox<String>(
            value: _selectedCategory,
            placeholder: Text(
              availableCategories.isEmpty
                  ? 'No devices available'
                  : 'Select category...',
            ),
            isExpanded: true,
            items: availableCategories.map((category) {
              return ComboBoxItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: availableCategories.isEmpty
                ? null
                : (value) {
                    setState(() {
                      _selectedCategory = value;
                      _selectedPreset =
                          null; // Reset preset when category changes
                    });
                  },
          ),
          const SizedBox(height: 16),
          const Text('Device Type'),
          const SizedBox(height: 4),
          ComboBox<DevicePreset>(
            value: _selectedPreset,
            placeholder: Text(
              _selectedCategory == null
                  ? 'Select a category first...'
                  : availablePresets.isEmpty
                  ? 'No devices available in this category'
                  : 'Select device type...',
            ),
            isExpanded: true,
            items: availablePresets.map((preset) {
              final remaining = appState.getAvailableSlots(preset.id);
              return ComboBoxItem<DevicePreset>(
                value: preset,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: preset.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${preset.name} ($remaining left)'),
                  ],
                ),
              );
            }).toList(),
            onChanged: _selectedCategory == null || availablePresets.isEmpty
                ? null
                : (value) {
                    setState(() {
                      _selectedPreset = value;
                    });
                  },
          ),
          const SizedBox(height: 16),
          const Text('Hostname (optional)'),
          const SizedBox(height: 4),
          TextBox(
            controller: _hostnameController,
            placeholder: 'Leave empty for default',
          ),
          if (_selectedPreset != null) ...[
            const SizedBox(height: 16),
            InfoBar(
              title: Text(_selectedPreset!.sku),
              content: Text(
                '${_selectedPreset!.defaultInterfaces().length} ports • '
                '${_selectedPreset!.category.name}',
              ),
              severity: InfoBarSeverity.info,
            ),
          ],
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedPreset == null || _isLoading ? null : _addDevice,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
