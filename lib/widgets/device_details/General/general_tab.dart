import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/devices/device_preset.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/utils/config_exporter.dart';
import 'package:ktracer_center/utils/synced_controller.dart';
import 'package:ktracer_center/widgets/device_details/device_details.dart';
import 'package:ktracer_center/widgets/device_details/synced_toggle_switch.dart';
import 'package:ktracer_center/widgets/ip_address_field.dart';
import 'package:provider/provider.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class GeneralTab extends StatefulWidget {
  const GeneralTab({required this.device, super.key});
  final NetDevice device;

  @override
  State<GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<GeneralTab> {
  late RealtimeForm _form;
  late SyncedController<String> _hostnameController;
  late SyncedController<bool> _domainLookupController;
  late SyncedController<bool> _ipRoutingController;
  late SyncedController<String> _defaultGatewayIpv4Controller;
  late SyncedController<String> _domainNameController;
  late SyncedController<String> _bannerMOTDController;
  late SyncedController<VTPMode> _vtpModeController;
  late SyncedController<String> _vtpDomainNameController;
  late SyncedController<String> _vtpPasswordController;
  late SyncedController<VTPVersion> _vtpVersionController;
  late SyncedController<String> _deviceGroupController;

  /// Returns the list of VTP versions supported by the device based on capabilities.
  List<VTPVersion> get _supportedVtpVersions {
    final caps = widget.device.preset.capabilities;
    final versions = <VTPVersion>[];
    if (caps.contains('vtp-v1')) versions.add(VTPVersion.v1);
    if (caps.contains('vtp-v2')) versions.add(VTPVersion.v2);
    if (caps.contains('vtp-v3')) versions.add(VTPVersion.v3);
    return versions;
  }

  void _setId() {
    _form.setId(widget.device.id, {
      'config': {
        'hostname': widget.device.hostname,
        'domain_lookup': widget.device.domainLookup,
        'default_gateway_ipv4': widget.device.defaultGatewayIpv4,
        'domain_name': widget.device.config['domain_name'],
        'banner_motd': widget.device.config['banner_motd'],
        'vtp_mode': widget.device.config['vtp_mode'],
        'vtp_domain': widget.device.config['vtp_domain'],
        'vtp_password': widget.device.config['vtp_password'],
        'vtp_version': widget.device.config['vtp_version'],
        'device_group': widget.device.deviceGroup,
      },
    });
  }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.id != oldWidget.device.id) _setId();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _form = RealtimeForm(tableName: 'net_devices');
    _hostnameController = _form.addField('config.hostname');
    _domainLookupController = _form.addBoolField('config.domain_lookup');
    _ipRoutingController = _form.addBoolField('config.ip_routing');
    _defaultGatewayIpv4Controller = _form.addField(
      'config.default_gateway_ipv4',
    );
    _domainNameController = _form.addField('config.domain_name');
    _bannerMOTDController = _form.addField('config.banner_motd');
    _deviceGroupController = _form.addField('config.device_group');
    _vtpModeController = _form.addEnumField<VTPMode>(
      'config.vtp_mode',
      initialValue: VTPMode.server,
      values: VTPMode.values,
    );
    _vtpDomainNameController = _form.addField('config.vtp_domain');
    _vtpPasswordController = _form.addField('config.vtp_password');
    // VTP version uses only the supported versions for this device
    final supportedVersions = _supportedVtpVersions;
    if (supportedVersions.isNotEmpty) {
      _vtpVersionController = _form.addEnumField<VTPVersion>(
        'config.vtp_version',
        initialValue: supportedVersions.first,
        values: supportedVersions,
      );
    }
    _setId();
  }

  List<Widget> _buildField(
    String label,
    SyncedController<String> syncedController,
  ) => [
    Text(label),
    const SizedBox(height: 4),
    SizedBox(
      width: 300,
      child: TextBox(
        controller: syncedController.controller,
        onChanged: syncedController.onChanged,
      ),
    ),
  ];

  Widget _buildDefaultGatewayIpv4Field() {
    return SizedBox(
      width: 300,
      child: IpAddressField(
        key: const ValueKey('default-gateway-ipv4'),
        controller: _defaultGatewayIpv4Controller,
        label: 'Default Gateway (IPv4)',
        placeholder: '192.168.1.1',
        enableCidr: false,
      ),
    );
  }

  Widget _buildDeviceGroupSelector(AppState state) {
    final existingGroups = state.deviceGroups;
    final position = state.getDevicePositionInGroup(widget.device.id);
    final total = state.getDeviceCountInGroup(widget.device.deviceGroup);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text("Device Group"),
            const SizedBox(width: 8),
            Text(
              '($position of $total)',
              style: TextStyle(fontSize: 11, color: Colors.grey[120]),
            ),
            const Spacer(),
            Tooltip(
              message: 'Move up in list',
              child: IconButton(
                icon: const Icon(FluentIcons.chevron_up, size: 12),
                onPressed: position > 1
                    ? () => state.moveDeviceUp(widget.device.id)
                    : null,
              ),
            ),
            Tooltip(
              message: 'Move down in list',
              child: IconButton(
                icon: const Icon(FluentIcons.chevron_down, size: 12),
                onPressed: position < total
                    ? () => state.moveDeviceDown(widget.device.id)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<String>(
          valueListenable: _deviceGroupController,
          builder: (context, groupValue, _) {
            return AutoSuggestBox<String>(
              controller: _deviceGroupController.controller,
              placeholder: 'No group (ungrouped)',
              items: [
                // Option to remove from group
                AutoSuggestBoxItem<String>(
                  value: '',
                  label: 'No group (ungrouped)',
                ),
                // Existing groups
                ...existingGroups.map(
                  (g) => AutoSuggestBoxItem<String>(value: g, label: g),
                ),
              ],
              onChanged: (text, reason) {
                if (reason == TextChangedReason.userInput) {
                  // User is typing - will create new group if needed
                  _deviceGroupController.onChanged(text);
                }
              },
              onSelected: (item) {
                _deviceGroupController.onChanged(item.value ?? '');
              },
            );
          },
        ),
      ],
    );
  }

  void _showExportDialog(BuildContext context, AppState state) {
    final exporter = ConfigExporter(
      device: widget.device,
      projectProperties: state.selectedProject?.properties,
    );
    final commands = exporter.generateCommandString();

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text('Export Config: ${widget.device.hostname}'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'IOS Terminal Commands',
                    style: FluentTheme.of(context).typography.bodyStrong,
                  ),
                  const Spacer(),
                  Button(
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.copy, size: 14),
                        SizedBox(width: 6),
                        Text('Copy'),
                      ],
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: commands));
                      displayInfoBar(
                        context,
                        builder: (ctx, close) => const InfoBar(
                          title: Text('Copied to clipboard'),
                          severity: InfoBarSeverity.success,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(80),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    commands,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lockService = state.lockService;
    final lock = lockService?.getLock(widget.device.id);
    final realId = lock?.realId;
    final hasLock = lockService?.hasLock(widget.device.id) ?? false;

    return Column(
      children: [
        Expanded(
          child: FluentWidgets.mica(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    widget.device.sku,
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Hostname"),
                            const SizedBox(height: 4),
                            TextBox(
                              controller: _hostnameController.controller,
                              onChanged: _hostnameController.onChanged,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Type"),
                            const SizedBox(height: 4),
                            TextBox(
                              controller: TextEditingController(
                                text: widget.device.name,
                              ),
                              enabled: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("SKU"),
                            const SizedBox(height: 4),
                            TextBox(
                              controller: TextEditingController(
                                text: widget.device.sku,
                              ),
                              enabled: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDeviceGroupSelector(state)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Button(
                        onPressed: hasLock && realId != null
                            ? () {
                                context
                                    .read<AppState>()
                                    .deviceController
                                    ?.sendCommand(
                                      widget.device.id,
                                      realId,
                                      'show run',
                                    );
                              }
                            : null,
                        child: const Text("Send Show Request"),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: () => _showExportDialog(context, state),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.download, size: 14),
                            SizedBox(width: 6),
                            Text('Export Config'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!hasLock) ...[
                        InfoBadge(
                          source: const Icon(FluentIcons.lock, size: 12),
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Lock required to send commands',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ] else if (realId == null) ...[
                        InfoBadge(
                          source: const Icon(FluentIcons.warning, size: 12),
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'No physical device assigned',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ] else ...[
                        Icon(
                          FluentIcons.check_mark,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Physical device: #$realId',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SyncedToggleSwitch(
                        label: "Domain Lookup",
                        controller: _domainLookupController,
                      ),
                      const SizedBox(height: 12),
                      if (widget.device.category == NetDeviceCategory.Router)
                        SyncedToggleSwitch(
                          label: "IP Routing",
                          controller: _ipRoutingController,
                        ),
                      const SizedBox(height: 12),
                      if (widget.device.category ==
                          NetDeviceCategory.Switch) ...[
                        _buildDefaultGatewayIpv4Field(),
                        const SizedBox(height: 12),
                      ],
                      ..._buildField("Domain Name", _domainNameController),
                      const SizedBox(height: 12),
                      ..._buildField("Banner MOTD", _bannerMOTDController),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_supportedVtpVersions.isNotEmpty) ...[
          const SizedBox(height: 24),
          FluentWidgets.mica(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VTP Configuration',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Mode'),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<VTPMode>(
                        valueListenable: _vtpModeController,
                        builder: (context, mode, _) {
                          return ComboBox<VTPMode>(
                            value: mode,
                            items: VTPMode.values
                                .map(
                                  (m) => ComboBoxItem<VTPMode>(
                                    value: m,
                                    child: Text(
                                      m.name[0].toUpperCase() +
                                          m.name.substring(1),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _vtpModeController.onChanged,
                          );
                        },
                      ),
                      const SizedBox(width: 24),
                      const Text('Version'),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<VTPVersion>(
                        valueListenable: _vtpVersionController,
                        builder: (context, version, _) {
                          return ComboBox<VTPVersion>(
                            value: version,
                            items: _supportedVtpVersions
                                .map(
                                  (v) => ComboBoxItem<VTPVersion>(
                                    value: v,
                                    child: Text(v.name.toUpperCase()),
                                  ),
                                )
                                .toList(),
                            onChanged: _vtpVersionController.onChanged,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._buildField('VTP Domain', _vtpDomainNameController),
                  const SizedBox(height: 12),
                  ..._buildField('VTP Password', _vtpPasswordController),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        // Delete device button
        FluentWidgets.mica(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Button(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      Colors.red.darkest,
                    ),
                  ),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => ContentDialog(
                        title: const Text('Delete Device'),
                        content: Text(
                          'Are you sure you want to delete "${widget.device.hostname}"?',
                        ),
                        actions: [
                          Button(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                Colors.red,
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      final hostname = widget.device.hostname;
                      await context.read<AppState>().deleteDevice(
                        widget.device.id,
                      );
                      if (context.mounted) {
                        displayInfoBar(
                          context,
                          builder: (context, close) => InfoBar(
                            title: const Text('Device deleted'),
                            content: Text('Deleted "$hostname"'),
                            severity: InfoBarSeverity.success,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Delete Device'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
