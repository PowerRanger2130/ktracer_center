import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/models/project.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class VrfTab extends StatefulWidget {
  const VrfTab({super.key, required this.project, required this.devices});
  final Project project;
  final List<NetDevice> devices;

  @override
  State<VrfTab> createState() => _VrfTabState();
}

class _VrfTabState extends State<VrfTab> {
  VrfConfig? _selectedConfig;

  List<VrfConfig> get _configs => widget.project.properties.vrfConfigs;

  List<NetDevice> get _vrfCapableDevices {
    return widget.devices.where((d) {
      final caps = d.preset.capabilities;
      return caps.contains('vrf') || caps.contains('vrf-lite');
    }).toList();
  }

  String _getDeviceName(int deviceId) {
    final device = widget.devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => NetDevice(
        id: -1,
        projectId: -1,
        presetId: 1,
        config: {'hostname': 'Unknown'},
      ),
    );
    return device.hostname;
  }

  Future<void> _addVrfConfig() async {
    final availableDevices = _vrfCapableDevices
        .where((d) => !_configs.any((c) => c.deviceId == d.id))
        .toList();

    if (availableDevices.isEmpty) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('No available devices'),
          content: const Text(
            'All VRF-capable devices already have VRF configurations.',
          ),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return;
    }

    NetDevice? selectedDevice = availableDevices.first;

    final result = await showDialog<VrfConfig>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add VRF Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Device'),
              const SizedBox(height: 4),
              ComboBox<NetDevice>(
                value: selectedDevice,
                items: availableDevices
                    .map((d) => ComboBoxItem(value: d, child: Text(d.hostname)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedDevice = v),
              ),
              const SizedBox(height: 8),
              Text(
                'VRF instances will be added after creating the device configuration.',
                style: FluentTheme.of(context).typography.caption,
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedDevice == null) return;
                Navigator.pop(context, VrfConfig(deviceId: selectedDevice!.id));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final updated = widget.project.properties.copyWith(
        vrfConfigs: [..._configs, result],
      );
      await widget.project.updateProperties(updated);
      setState(() => _selectedConfig = result);
    }
  }

  Future<void> _deleteVrfConfig(VrfConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete VRF Configuration'),
        content: Text(
          'Are you sure you want to delete VRF configuration for "${_getDeviceName(config.deviceId)}"?',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.red),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = widget.project.properties.copyWith(
        vrfConfigs: _configs
            .where((c) => c.deviceId != config.deviceId)
            .toList(),
      );
      await widget.project.updateProperties(updated);
      if (_selectedConfig?.deviceId == config.deviceId) {
        _selectedConfig = null;
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Column(
            children: [
              CommandBar(
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.add),
                    label: const Text('Add Device'),
                    onPressed: _addVrfConfig,
                  ),
                ],
              ),
              Expanded(
                child: _configs.isEmpty
                    ? const Center(child: Text('No VRF configurations'))
                    : ListView.builder(
                        itemCount: _configs.length,
                        itemBuilder: (context, index) {
                          final config = _configs[index];
                          return ListTile.selectable(
                            leading: Icon(
                              config.vrfInstances.isNotEmpty
                                  ? FluentIcons.check_mark
                                  : FluentIcons.circle_ring,
                              size: 12,
                              color: config.vrfInstances.isNotEmpty
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            title: Text(_getDeviceName(config.deviceId)),
                            subtitle: Text(
                              '${config.vrfInstances.length} VRF instance(s)',
                            ),
                            selected:
                                _selectedConfig?.deviceId == config.deviceId,
                            trailing: IconButton(
                              icon: const Icon(FluentIcons.delete, size: 14),
                              onPressed: () => _deleteVrfConfig(config),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedConfig =
                                    _selectedConfig?.deviceId == config.deviceId
                                    ? null
                                    : config;
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedConfig == null
              ? const Center(
                  child: Text('Select a device to view VRF configuration'),
                )
              : _VrfConfigDetails(
                  config: _selectedConfig!,
                  deviceName: _getDeviceName(_selectedConfig!.deviceId),
                  project: widget.project,
                  onUpdated: (updated) {
                    setState(() => _selectedConfig = updated);
                  },
                ),
        ),
      ],
    );
  }
}

class _VrfConfigDetails extends StatefulWidget {
  const _VrfConfigDetails({
    required this.config,
    required this.deviceName,
    required this.project,
    required this.onUpdated,
  });
  final VrfConfig config;
  final String deviceName;
  final Project project;
  final void Function(VrfConfig) onUpdated;

  @override
  State<_VrfConfigDetails> createState() => _VrfConfigDetailsState();
}

class _VrfConfigDetailsState extends State<_VrfConfigDetails> {
  VrfInstance? _selectedInstance;

  Future<void> _updateConfig(VrfConfig updated) async {
    final configs = widget.project.properties.vrfConfigs
        .map((c) => c.deviceId == widget.config.deviceId ? updated : c)
        .toList();
    await widget.project.updateProperties(
      widget.project.properties.copyWith(vrfConfigs: configs),
    );
    widget.onUpdated(updated);
  }

  Future<void> _addVrfInstance() async {
    final nameController = TextEditingController();
    final rdController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<VrfInstance>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Add VRF Instance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('VRF Name'),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: TextBox(
                controller: nameController,
                placeholder: 'e.g., CUSTOMER_A',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Route Distinguisher (optional for VRF-Lite)'),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: TextBox(
                controller: rdController,
                placeholder: 'e.g., 65000:1',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Format: ASN:nn or IP:nn',
              style: FluentTheme.of(context).typography.caption,
            ),
            const SizedBox(height: 12),
            const Text('Description (optional)'),
            const SizedBox(height: 4),
            SizedBox(
              width: 300,
              child: TextBox(
                controller: descController,
                placeholder: 'e.g., Customer A network',
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final rd = rdController.text.trim();
              final desc = descController.text.trim();
              Navigator.pop(
                context,
                VrfInstance(
                  name: name,
                  routeDistinguisher: rd.isNotEmpty ? rd : null,
                  description: desc.isNotEmpty ? desc : null,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updated = widget.config.copyWith(
        vrfInstances: [...widget.config.vrfInstances, result],
      );
      await _updateConfig(updated);
    }
  }

  Future<void> _removeVrfInstance(VrfInstance instance) async {
    final updated = widget.config.copyWith(
      vrfInstances: widget.config.vrfInstances
          .where((i) => i.identifier != instance.identifier)
          .toList(),
    );
    if (_selectedInstance?.identifier == instance.identifier) {
      _selectedInstance = null;
    }
    await _updateConfig(updated);
    setState(() {});
  }

  Future<void> _toggleInstanceEnabled(VrfInstance instance) async {
    final updatedInstance = instance.copyWith(enabled: !instance.enabled);
    final updatedInstances = widget.config.vrfInstances
        .map((i) => i.identifier == instance.identifier ? updatedInstance : i)
        .toList();
    final updated = widget.config.copyWith(vrfInstances: updatedInstances);
    await _updateConfig(updated);
    if (_selectedInstance?.identifier == instance.identifier) {
      _selectedInstance = updatedInstance;
    }
    setState(() {});
  }

  Future<void> _addRouteTarget(VrfInstance instance) async {
    final rtController = TextEditingController();
    bool importRt = true;
    bool exportRt = true;

    final result = await showDialog<VrfRouteTarget>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add Route Target'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Route Target'),
              const SizedBox(height: 4),
              SizedBox(
                width: 200,
                child: TextBox(
                  controller: rtController,
                  placeholder: 'e.g., 65000:100',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Format: ASN:nn',
                style: FluentTheme.of(context).typography.caption,
              ),
              const SizedBox(height: 12),
              Checkbox(
                checked: importRt,
                onChanged: (v) => setDialogState(() => importRt = v ?? true),
                content: const Text('Import'),
              ),
              const SizedBox(height: 8),
              Checkbox(
                checked: exportRt,
                onChanged: (v) => setDialogState(() => exportRt = v ?? true),
                content: const Text('Export'),
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final rt = rtController.text.trim();
                if (rt.isEmpty) return;
                Navigator.pop(
                  context,
                  VrfRouteTarget(
                    target: rt,
                    import: importRt,
                    export: exportRt,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final updatedInstance = instance.copyWith(
        routeTargets: [...instance.routeTargets, result],
      );
      final updatedInstances = widget.config.vrfInstances
          .map((i) => i.identifier == instance.identifier ? updatedInstance : i)
          .toList();
      final updated = widget.config.copyWith(vrfInstances: updatedInstances);
      await _updateConfig(updated);
      setState(() => _selectedInstance = updatedInstance);
    }
  }

  Future<void> _removeRouteTarget(
    VrfInstance instance,
    VrfRouteTarget rt,
  ) async {
    final updatedInstance = instance.copyWith(
      routeTargets: instance.routeTargets
          .where((r) => r.target != rt.target)
          .toList(),
    );
    final updatedInstances = widget.config.vrfInstances
        .map((i) => i.identifier == instance.identifier ? updatedInstance : i)
        .toList();
    final updated = widget.config.copyWith(vrfInstances: updatedInstances);
    await _updateConfig(updated);
    setState(() => _selectedInstance = updatedInstance);
  }

  Future<void> _addInterface(VrfInstance instance) async {
    final interfaceController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Add Interface'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Interface Name'),
            const SizedBox(height: 4),
            SizedBox(
              width: 250,
              child: TextBox(
                controller: interfaceController,
                placeholder: 'e.g., GigabitEthernet0/0',
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final iface = interfaceController.text.trim();
              if (iface.isEmpty) return;
              Navigator.pop(context, iface);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedInstance = instance.copyWith(
        interfaces: [...instance.interfaces, result],
      );
      final updatedInstances = widget.config.vrfInstances
          .map((i) => i.identifier == instance.identifier ? updatedInstance : i)
          .toList();
      final updated = widget.config.copyWith(vrfInstances: updatedInstances);
      await _updateConfig(updated);
      setState(() => _selectedInstance = updatedInstance);
    }
  }

  Future<void> _removeInterface(VrfInstance instance, String iface) async {
    final updatedInstance = instance.copyWith(
      interfaces: instance.interfaces.where((i) => i != iface).toList(),
    );
    final updatedInstances = widget.config.vrfInstances
        .map((i) => i.identifier == instance.identifier ? updatedInstance : i)
        .toList();
    final updated = widget.config.copyWith(vrfInstances: updatedInstances);
    await _updateConfig(updated);
    setState(() => _selectedInstance = updatedInstance);
  }

  @override
  Widget build(BuildContext context) {
    return FluentWidgets.mica(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VRF Configuration: ${widget.deviceName}',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // VRF Instances list
                  SizedBox(
                    width: 250,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CommandBar(
                          primaryItems: [
                            CommandBarButton(
                              icon: const Icon(FluentIcons.add),
                              label: const Text('Add VRF'),
                              onPressed: _addVrfInstance,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'VRF Instances',
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: widget.config.vrfInstances.isEmpty
                              ? const Center(
                                  child: Text('No VRF instances configured'),
                                )
                              : ListView.builder(
                                  itemCount: widget.config.vrfInstances.length,
                                  itemBuilder: (context, index) {
                                    final instance =
                                        widget.config.vrfInstances[index];
                                    return ListTile.selectable(
                                      leading: Icon(
                                        instance.enabled
                                            ? FluentIcons.check_mark
                                            : FluentIcons.cancel,
                                        size: 12,
                                        color: instance.enabled
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      title: Text(instance.name),
                                      subtitle: Text(
                                        'RD: ${instance.routeDistinguisher ?? 'N/A'}\n'
                                        '${instance.interfaces.length} interface(s)',
                                      ),
                                      selected:
                                          _selectedInstance?.identifier ==
                                          instance.identifier,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ToggleSwitch(
                                            checked: instance.enabled,
                                            onChanged: (_) =>
                                                _toggleInstanceEnabled(
                                                  instance,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                              FluentIcons.delete,
                                              size: 14,
                                            ),
                                            onPressed: () =>
                                                _removeVrfInstance(instance),
                                          ),
                                        ],
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedInstance =
                                              _selectedInstance?.identifier ==
                                                  instance.identifier
                                              ? null
                                              : instance;
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Instance details
                  Expanded(
                    child: _selectedInstance == null
                        ? const Center(
                            child: Text(
                              'Select a VRF instance to view details',
                            ),
                          )
                        : _buildInstanceDetails(_selectedInstance!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstanceDetails(VrfInstance instance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'VRF: ${instance.name}',
              style: FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(width: 16),
            if (instance.routeDistinguisher != null)
              Text('RD: ${instance.routeDistinguisher}'),
          ],
        ),
        if (instance.description != null) ...[
          const SizedBox(height: 4),
          Text(
            instance.description!,
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
        const SizedBox(height: 16),
        // Route Targets
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Route Targets'),
                  Button(
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('Add'),
                      ],
                    ),
                    onPressed: () => _addRouteTarget(instance),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: instance.routeTargets.isEmpty
                    ? const Center(child: Text('No route targets'))
                    : ListView.builder(
                        itemCount: instance.routeTargets.length,
                        itemBuilder: (context, index) {
                          final rt = instance.routeTargets[index];
                          return ListTile(
                            title: Text(rt.target),
                            subtitle: Text(
                              [
                                if (rt.import) 'Import',
                                if (rt.export) 'Export',
                              ].join(', '),
                            ),
                            trailing: IconButton(
                              icon: const Icon(FluentIcons.delete, size: 14),
                              onPressed: () => _removeRouteTarget(instance, rt),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Interfaces
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Interfaces'),
                  Button(
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('Add'),
                      ],
                    ),
                    onPressed: () => _addInterface(instance),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: instance.interfaces.isEmpty
                    ? const Center(child: Text('No interfaces assigned'))
                    : ListView.builder(
                        itemCount: instance.interfaces.length,
                        itemBuilder: (context, index) {
                          final iface = instance.interfaces[index];
                          return ListTile(
                            title: Text(iface),
                            trailing: IconButton(
                              icon: const Icon(FluentIcons.delete, size: 14),
                              onPressed: () =>
                                  _removeInterface(instance, iface),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
