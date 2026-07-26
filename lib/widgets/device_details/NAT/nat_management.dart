import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/interface_descriptor.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/utils/synced_controller.dart';
import 'package:ktracer_center/widgets/device_details/synced_toggle_switch.dart';
import 'package:ktracer_center/widgets/interface_selector.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NatManagement extends StatefulWidget {
  const NatManagement({
    super.key,
    required this.rule,
    required this.device,
    required this.ruleIndex,
    this.onDelete,
  });

  final ValueNotifier<NatRule?> rule;
  final NetDevice device;
  final int ruleIndex;
  final VoidCallback? onDelete;

  @override
  State<NatManagement> createState() => _NatManagementState();
}

class _NatManagementState extends State<NatManagement> {
  late RealtimeForm _form;
  late SyncedController<String> _descriptionController;
  late SyncedController<bool> _enabledController;

  // Static NAT controllers
  late SyncedController<String> _insideLocalController;
  late SyncedController<String> _insideGlobalController;

  // Dynamic NAT / PAT controllers
  late SyncedController<String> _poolNameController;
  late SyncedController<String> _poolStartController;
  late SyncedController<String> _poolEndController;
  late SyncedController<String> _poolNetmaskController;
  late SyncedController<int> _aclNumberController;
  late SyncedController<bool> _useInterfaceOverloadController;

  // Static PAT controllers
  late SyncedController<int> _localPortController;
  late SyncedController<int> _globalPortController;
  late SyncedController<String> _protocolController;

  // Local state for inline ACL (source networks)
  List<String> _sourceNetworks = [];
  final TextEditingController _newNetworkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initForm();
    widget.rule.addListener(_handleRuleChange);
    _handleRuleChange();
  }

  void _initForm() {
    _form = RealtimeForm(tableName: 'net_devices');

    final prefix = 'config.nat_rules.${widget.ruleIndex}';
    _descriptionController = _form.addField('$prefix.description');
    _enabledController = _form.addBoolField('$prefix.enabled');

    // Static NAT fields
    _insideLocalController = _form.addField('$prefix.inside_local');
    _insideGlobalController = _form.addField('$prefix.inside_global');

    // Dynamic NAT / PAT fields
    _poolNameController = _form.addField('$prefix.pool_name');
    _poolStartController = _form.addField('$prefix.pool_start');
    _poolEndController = _form.addField('$prefix.pool_end');
    _poolNetmaskController = _form.addField('$prefix.pool_netmask');
    _aclNumberController = _form.addIntField('$prefix.acl_number');
    _useInterfaceOverloadController = _form.addBoolField(
      '$prefix.use_interface_overload',
    );

    // Static PAT fields
    _localPortController = _form.addIntField('$prefix.local_port');
    _globalPortController = _form.addIntField('$prefix.global_port');
    _protocolController = _form.addField('$prefix.protocol');

    // Initialize source networks from rule
    final rule = widget.rule.value;
    if (rule != null) {
      _sourceNetworks = List<String>.from(rule.natSourceNetworks);
    }
  }

  @override
  void didUpdateWidget(NatManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rule != oldWidget.rule ||
        widget.ruleIndex != oldWidget.ruleIndex) {
      oldWidget.rule.removeListener(_handleRuleChange);

      _form.dispose();
      _initForm();

      widget.rule.addListener(_handleRuleChange);
      _handleRuleChange();
    }
  }

  void _handleRuleChange() {
    final rule = widget.rule.value;
    if (rule == null) return;

    _form.setId(widget.device.id, {
      'config': {
        'nat_rules': {
          '${widget.ruleIndex}': {
            'description': rule.description,
            'enabled': rule.enabled,
            'inside_local': rule.insideLocal ?? '',
            'inside_global': rule.insideGlobal ?? '',
            'pool_name': rule.poolName ?? '',
            'pool_start': rule.poolStart ?? '',
            'pool_end': rule.poolEnd ?? '',
            'pool_netmask': rule.poolNetmask ?? '',
            'acl_number': rule.aclNumber,
            'use_interface_overload': rule.useInterfaceOverload,
            'local_port': rule.localPort,
            'global_port': rule.globalPort,
            'protocol': rule.protocol ?? 'tcp',
          },
        },
      },
    });

    // Update local source networks list
    if (!listEquals(_sourceNetworks, rule.natSourceNetworks)) {
      setState(() {
        _sourceNetworks = List<String>.from(rule.natSourceNetworks);
      });
    }
  }

  @override
  void dispose() {
    widget.rule.removeListener(_handleRuleChange);
    _form.dispose();
    _newNetworkController.dispose();
    super.dispose();
  }

  /// Get interface key from interface name
  String? _getInterfaceKeyFromName(String? interfaceName) {
    if (interfaceName == null || interfaceName.isEmpty) return null;

    // Check if it's a VLAN SVI
    if (interfaceName.toLowerCase().startsWith('vlan')) {
      final vlanId = int.tryParse(
        interfaceName.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      if (vlanId != null) return 'vlan:$vlanId';
    }

    // Check physical ports
    final interfaces = widget.device.interfaces;
    for (int i = 0; i < interfaces.length; i++) {
      if (interfaces[i].name == interfaceName) {
        return 'port:$i';
      }
    }

    return null;
  }

  Future<void> _updateInterface(
    String field,
    InterfaceDescriptor? iface,
  ) async {
    if (iface == null) return;

    final rules = widget.device.natRules;
    final rule = rules[widget.ruleIndex];

    NatRule updatedRule;
    if (field == 'inside_interface') {
      updatedRule = rule.copyWith(insideInterface: iface.name);
    } else {
      updatedRule = rule.copyWith(outsideInterface: iface.name);
    }

    final updatedRules = [...rules];
    updatedRules[widget.ruleIndex] = updatedRule;

    await Database.updateDeviceConfig(widget.device.id, {
      'nat_rules': updatedRules.map((r) => r.toJson()).toList(),
    });

    widget.rule.value = updatedRule;
    setState(() {});
  }

  /// Save the source networks list to the database
  Future<void> _saveSourceNetworks(List<String> networks) async {
    final config = Map<String, dynamic>.from(widget.device.config);

    // nat_rules is stored as a List, not a Map
    final natRulesList = List<dynamic>.from(config['nat_rules'] ?? []);

    // Ensure the list is long enough
    while (natRulesList.length <= widget.ruleIndex) {
      natRulesList.add(<String, dynamic>{});
    }

    // Update the specific rule
    final ruleData = Map<String, dynamic>.from(
      natRulesList[widget.ruleIndex] ?? {},
    );
    ruleData['nat_source_networks'] = networks;
    natRulesList[widget.ruleIndex] = ruleData;

    config['nat_rules'] = natRulesList;

    await Supabase.instance.client
        .from('net_devices')
        .update({'config': config})
        .eq('id', widget.device.id);
  }

  /// Add a source network to the inline ACL
  Future<void> _addSourceNetwork(String network) async {
    if (network.isEmpty) return;

    // Handle 'any' keyword
    final normalizedNetwork = network.trim().toLowerCase();
    if (normalizedNetwork == 'any') {
      if (_sourceNetworks.contains('any')) return;
      final updated = [..._sourceNetworks, 'any'];
      setState(() => _sourceNetworks = updated);
      await _saveSourceNetworks(updated);
      _newNetworkController.clear();
      return;
    }

    // Validate and normalize the network using IPv4 class
    final parsed = IPv4.tryParse(network);
    if (parsed == null) {
      // Try parsing as just an IP address (assume /32)
      if (IPv4.isValidAddress(network)) {
        final cidr = '$network/32';
        if (_sourceNetworks.contains(cidr)) return;
        final updated = [..._sourceNetworks, cidr];
        setState(() => _sourceNetworks = updated);
        await _saveSourceNetworks(updated);
        _newNetworkController.clear();
        return;
      }
      // Invalid format - show error
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Invalid network format'),
            content: const Text(
              'Use CIDR notation (e.g., 192.168.1.0/24) or "any"',
            ),
            severity: InfoBarSeverity.warning,
            onClose: close,
          ),
        );
      }
      return;
    }

    // Normalize to network address (apply the mask)
    final normalizedCidr = parsed.networkCIDR;
    if (_sourceNetworks.contains(normalizedCidr)) return;

    final updated = [..._sourceNetworks, normalizedCidr];
    setState(() => _sourceNetworks = updated);
    await _saveSourceNetworks(updated);
    _newNetworkController.clear();
  }

  /// Remove a source network from the inline ACL
  Future<void> _removeSourceNetwork(String network) async {
    final updated = _sourceNetworks.where((n) => n != network).toList();
    setState(() {
      _sourceNetworks = updated;
    });
    await _saveSourceNetworks(updated);
  }

  String _getNatTypeLabel(NatType type) {
    switch (type) {
      case NatType.staticNat:
        return 'Static NAT';
      case NatType.dynamicNat:
        return 'Dynamic NAT';
      case NatType.pat:
        return 'PAT (Overload)';
      case NatType.staticPat:
        return 'Static PAT';
    }
  }

  Widget _buildStaticNatFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Address Translation',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inside Local (Private IP)'),
                  const SizedBox(height: 4),
                  TextBox(
                    controller: _insideLocalController.controller,
                    placeholder: 'e.g., 192.168.1.10',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(FluentIcons.forward),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inside Global (Public IP)'),
                  const SizedBox(height: 4),
                  TextBox(
                    controller: _insideGlobalController.controller,
                    placeholder: 'e.g., 203.0.113.10',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDynamicNatFields() {
    final rule = widget.rule.value;
    if (rule == null) return const SizedBox();

    final isPat = rule.type == NatType.pat;
    final useOverload = _useInterfaceOverloadController.value;

    return Consumer<AppState>(
      builder: (context, appState, child) {
        final connectedDevices = _getConnectedVirtualDevices(appState);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === Section 1: Outside Address Configuration ===
            _buildSectionHeader(
              'Outside Address Configuration',
              subtitle:
                  'Public/Global IP addresses that inside hosts will be translated to',
            ),
            const SizedBox(height: 12),

            // Interface Overload Option (PAT only)
            if (isPat) ...[
              Row(
                children: [
                  ToggleSwitch(
                    checked: useOverload,
                    onChanged: (value) {
                      _useInterfaceOverloadController.onChanged(value);
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use Interface Overload',
                          style: FluentTheme.of(context).typography.body,
                        ),
                        Text(
                          'Use the outside interface\'s IP address instead of a pool',
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(color: Colors.grey[100]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Pool Configuration (if not using overload)
            if (!useOverload) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: FluentTheme.of(context).accentColor.withAlpha(50),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(FluentIcons.globe, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'NAT Pool (Outside/Public IPs)',
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Pool Name'),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 200,
                      child: TextBox(
                        controller: _poolNameController.controller,
                        placeholder: 'e.g., PUBLIC_POOL',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Address'),
                              const SizedBox(height: 4),
                              TextBox(
                                controller: _poolStartController.controller,
                                placeholder: 'e.g., 203.0.113.10',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Address'),
                              const SizedBox(height: 4),
                              TextBox(
                                controller: _poolEndController.controller,
                                placeholder: 'e.g., 203.0.113.20',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Netmask'),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 200,
                      child: TextBox(
                        controller: _poolNetmaskController.controller,
                        placeholder: 'e.g., 255.255.255.0',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // === Section 2: Inside Hosts (ACL) ===
            _buildSectionHeader(
              'Inside Hosts (Source Networks)',
              subtitle:
                  'Which private networks/hosts are allowed to use this NAT',
            ),
            const SizedBox(height: 12),

            // Quick-add from connected devices
            if (connectedDevices.isNotEmpty) ...[
              Text(
                'Quick Add from Topology:',
                style: FluentTheme.of(context).typography.caption,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: connectedDevices
                    .where((d) => d.ipAddress != null)
                    .map((device) {
                      final network = _getNetworkFromIp(device.ipAddress!);
                      final alreadyAdded = _sourceNetworks.contains(network);

                      return Tooltip(
                        message: alreadyAdded
                            ? 'Already added'
                            : 'Add network $network',
                        child: Button(
                          style: ButtonStyle(
                            backgroundColor: alreadyAdded
                                ? WidgetStatePropertyAll(
                                    FluentTheme.of(
                                      context,
                                    ).accentColor.withValues(alpha: 0.15),
                                  )
                                : null,
                            foregroundColor: alreadyAdded
                                ? WidgetStatePropertyAll(Colors.grey[120])
                                : null,
                          ),
                          onPressed: alreadyAdded
                              ? null
                              : () => _addSourceNetwork(network),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getDeviceIcon(device.type), size: 14),
                              const SizedBox(width: 4),
                              Text(device.name),
                              if (alreadyAdded) ...[
                                const SizedBox(width: 4),
                                const Icon(FluentIcons.check_mark, size: 12),
                              ],
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Source networks list
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FluentTheme.of(
                  context,
                ).resources.controlFillColorDefault,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: FluentTheme.of(
                    context,
                  ).resources.controlStrokeColorDefault,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_sourceNetworks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No source networks defined. Add networks below.',
                        style: FluentTheme.of(
                          context,
                        ).typography.caption?.copyWith(color: Colors.grey[100]),
                      ),
                    )
                  else
                    ..._sourceNetworks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final network = entry.value;
                      return Column(
                        children: [
                          if (index > 0) const Divider(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(FluentIcons.home, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(network)),
                                IconButton(
                                  icon: const Icon(
                                    FluentIcons.delete,
                                    size: 14,
                                  ),
                                  onPressed: () =>
                                      _removeSourceNetwork(network),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: _newNetworkController,
                          placeholder: 'e.g., 192.168.1.0/24 or any',
                          onSubmitted: (value) => _addSourceNetwork(value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        child: const Text('Add'),
                        onPressed: () =>
                            _addSourceNetwork(_newNetworkController.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Legacy ACL number option (for reference to existing ACLs)
            Expander(
              header: const Text('Advanced: Use Existing ACL'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'If you have already defined an ACL in the ACL tab, you can reference it here instead of using inline source networks.',
                    style: FluentTheme.of(context).typography.caption,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 120,
                    child: NumberBox<int>(
                      value: _aclNumberController.value > 0
                          ? _aclNumberController.value
                          : null,
                      min: 1,
                      max: 199,
                      placeholder: 'ACL #',
                      onChanged: (value) {
                        if (value != null) {
                          _aclNumberController.onChanged(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: FluentTheme.of(context).typography.bodyStrong),
        if (subtitle != null)
          Text(
            subtitle,
            style: FluentTheme.of(
              context,
            ).typography.caption?.copyWith(color: Colors.grey[100]),
          ),
      ],
    );
  }

  /// Convert an IP address to its /24 network CIDR
  String _getNetworkFromIp(String ip) {
    return IPv4.addressToNetworkCIDR(ip, prefixLength: 24);
  }

  Widget _buildStaticPatFields() {
    final rule = widget.rule.value;
    if (rule == null) return const SizedBox();

    return Consumer<AppState>(
      builder: (context, appState, child) {
        final connectedDevices = _getConnectedVirtualDevices(appState);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Port Address Translation',
              style: FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(height: 8),
            // Quick select from connected topology devices
            if (connectedDevices.isNotEmpty) ...[
              const Text('Quick Select Destination'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: connectedDevices.map((device) {
                  final isSelected =
                      device.ipAddress != null &&
                      _insideLocalController.value == device.ipAddress;
                  return GestureDetector(
                    onTap: () {
                      if (device.ipAddress != null) {
                        _insideLocalController.onChanged(device.ipAddress!);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? FluentTheme.of(
                                context,
                              ).accentColor.withValues(alpha: 0.2)
                            : FluentTheme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? FluentTheme.of(context).accentColor
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getDeviceIcon(device.type), size: 14),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                device.name,
                                style: FluentTheme.of(
                                  context,
                                ).typography.caption,
                              ),
                              if (device.ipAddress != null)
                                Text(
                                  device.ipAddress!,
                                  style: FluentTheme.of(context)
                                      .typography
                                      .caption
                                      ?.copyWith(
                                        fontSize: 10,
                                        color: Colors.grey[100],
                                      ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Inside Local (Private IP)'),
                      const SizedBox(height: 4),
                      TextBox(
                        controller: _insideLocalController.controller,
                        placeholder: 'e.g., 192.168.1.10',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Inside Global (Public IP)'),
                      const SizedBox(height: 4),
                      TextBox(
                        controller: _insideGlobalController.controller,
                        placeholder: 'e.g., 203.0.113.1',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Protocol'),
                      const SizedBox(height: 4),
                      ComboBox<String>(
                        value: _protocolController.value.isNotEmpty
                            ? _protocolController.value
                            : 'tcp',
                        isExpanded: true,
                        popupColor: FluentTheme.of(context).menuColor,
                        items: const [
                          ComboBoxItem(value: 'tcp', child: Text('TCP')),
                          ComboBoxItem(value: 'udp', child: Text('UDP')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _protocolController.onChanged(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Local Port'),
                      const SizedBox(height: 4),
                      NumberBox<int>(
                        value: _localPortController.value > 0
                            ? _localPortController.value
                            : null,
                        min: 1,
                        max: 65535,
                        placeholder: 'e.g., 80',
                        onChanged: (value) {
                          if (value != null) {
                            _localPortController.onChanged(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Global Port'),
                      const SizedBox(height: 4),
                      NumberBox<int>(
                        value: _globalPortController.value > 0
                            ? _globalPortController.value
                            : null,
                        min: 1,
                        max: 65535,
                        placeholder: 'e.g., 8080',
                        onChanged: (value) {
                          if (value != null) {
                            _globalPortController.onChanged(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Get interfaces configured as NAT inside
  Set<String> _getInsideInterfaceNames() {
    final insideInterfaces = <String>{};
    final interfaces = widget.device.interfaces;
    final portsData = widget.device.config['ports'];

    for (int i = 0; i < interfaces.length; i++) {
      Map<String, dynamic>? portConfig;

      // Handle both List and Map formats for ports config
      if (portsData is List && i < portsData.length) {
        portConfig = portsData[i] as Map<String, dynamic>?;
      } else if (portsData is Map<String, dynamic>) {
        portConfig = portsData[i.toString()] as Map<String, dynamic>?;
      }

      if (portConfig != null) {
        final roleStr = portConfig['natRole'] as String?;
        if (roleStr == 'inside') {
          insideInterfaces.add(interfaces[i].name);
        }
      }
    }
    return insideInterfaces;
  }

  /// Get connected virtual devices from topology by walking the graph
  /// Follows inside interfaces through switches to find all reachable endpoints
  List<VirtualDevice> _getConnectedVirtualDevices(AppState appState) {
    final topology = appState.selectedProject?.properties.topology;
    if (topology == null) return [];

    final devices = appState.devices;
    final insideInterfaces = _getInsideInterfaceNames();

    // Track visited devices to avoid infinite loops
    final visitedDevices = <int>{widget.device.id};
    final connectedDevices = <VirtualDevice>[];

    // Queue of device IDs to explore
    final toExplore = <int>[];

    // Start with connections from this device's inside interfaces
    for (final conn in topology.connections) {
      if (conn.sourceDeviceId == widget.device.id &&
          (insideInterfaces.isEmpty ||
              insideInterfaces.contains(conn.sourcePort))) {
        toExplore.add(conn.targetDeviceId);
      } else if (conn.targetDeviceId == widget.device.id &&
          (insideInterfaces.isEmpty ||
              insideInterfaces.contains(conn.targetPort))) {
        toExplore.add(conn.sourceDeviceId);
      }
    }

    // Also check virtual devices directly connected to this device
    for (final vConn in topology.virtualConnections) {
      if (vConn.realDeviceId == widget.device.id &&
          (insideInterfaces.isEmpty ||
              insideInterfaces.contains(vConn.realDevicePort))) {
        final vDevice = topology.virtualDevices.firstWhere(
          (v) => v.id == vConn.virtualDeviceId,
          orElse: () => VirtualDevice(
            id: '',
            type: VirtualDeviceType.pc,
            name: 'Unknown',
            x: 0,
            y: 0,
          ),
        );
        if (vDevice.id.isNotEmpty) {
          connectedDevices.add(vDevice);
        }
      }
    }

    // BFS through connected devices
    while (toExplore.isNotEmpty) {
      final currentDeviceId = toExplore.removeAt(0);

      if (visitedDevices.contains(currentDeviceId)) continue;
      visitedDevices.add(currentDeviceId);

      // Find virtual devices connected to this device
      for (final vConn in topology.virtualConnections) {
        if (vConn.realDeviceId == currentDeviceId) {
          final vDevice = topology.virtualDevices.firstWhere(
            (v) => v.id == vConn.virtualDeviceId,
            orElse: () => VirtualDevice(
              id: '',
              type: VirtualDeviceType.pc,
              name: 'Unknown',
              x: 0,
              y: 0,
            ),
          );
          if (vDevice.id.isNotEmpty) {
            connectedDevices.add(vDevice);
          }
        }
      }

      // Check if this is a switch (layer 2 device) - continue walking if so
      final device = devices.firstWhere(
        (d) => d.id == currentDeviceId,
        orElse: () => widget.device,
      );

      // Only continue through layer 2 devices (switches), not routers
      final isSwitch =
          device.preset.capabilities.contains('vlan') &&
          !device.preset.capabilities.contains('static-routing');

      if (isSwitch) {
        for (final conn in topology.connections) {
          if (conn.sourceDeviceId == currentDeviceId &&
              !visitedDevices.contains(conn.targetDeviceId)) {
            toExplore.add(conn.targetDeviceId);
          } else if (conn.targetDeviceId == currentDeviceId &&
              !visitedDevices.contains(conn.sourceDeviceId)) {
            toExplore.add(conn.sourceDeviceId);
          }
        }
      }
    }

    return connectedDevices;
  }

  /// Get icon for virtual device type
  IconData _getDeviceIcon(VirtualDeviceType type) {
    switch (type) {
      case VirtualDeviceType.pc:
        return FluentIcons.desktop_flow;
      case VirtualDeviceType.server:
        return FluentIcons.server;
      case VirtualDeviceType.cloud:
        return FluentIcons.cloud;
      case VirtualDeviceType.phone:
        return FluentIcons.cell_phone;
    }
  }

  Widget _buildPatFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDynamicNatFields(),
        const SizedBox(height: 16),
        const InfoBar(
          title: Text('PAT Mode'),
          content: Text(
            'This pool uses overload (PAT), allowing multiple inside hosts to share a single outside address using different ports.',
          ),
          severity: InfoBarSeverity.info,
        ),
      ],
    );
  }

  Widget _buildInterfaceSection() {
    final rule = widget.rule.value;
    if (rule == null) return const SizedBox();

    // Get interfaces with NAT roles configured
    final insideInterfaces = _getInterfacesWithNatRole(NatInterfaceRole.inside);
    final outsideInterfaces = _getInterfacesWithNatRole(
      NatInterfaceRole.outside,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interface Configuration',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 8),
        // Show configured NAT interface roles
        if (insideInterfaces.isNotEmpty || outsideInterfaces.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FluentTheme.of(context).cardColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (insideInterfaces.isNotEmpty)
                  Row(
                    children: [
                      const Icon(FluentIcons.home, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'Inside: ',
                        style: FluentTheme.of(context).typography.caption
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        insideInterfaces.join(', '),
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                  ),
                if (outsideInterfaces.isNotEmpty) ...[
                  if (insideInterfaces.isNotEmpty) const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(FluentIcons.globe, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'Outside: ',
                        style: FluentTheme.of(context).typography.caption
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        outsideInterfaces.join(', '),
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ] else ...[
          const InfoBar(
            title: Text('No NAT Interfaces Configured'),
            content: Text(
              'Configure NAT roles on interfaces in the Interfaces tab.',
            ),
            severity: InfoBarSeverity.warning,
          ),
          const SizedBox(height: 8),
        ],
        // Legacy per-rule interface config (hidden behind expander)
        Expander(
          header: const Text('Per-Rule Interface Override (Advanced)'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Override the global NAT interface roles for this specific rule.',
                style: FluentTheme.of(context).typography.caption,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Inside Interface'),
                        const SizedBox(height: 4),
                        InterfaceSelector.layer3(
                          device: widget.device,
                          selectedKey: _getInterfaceKeyFromName(
                            rule.insideInterface,
                          ),
                          onChanged: (iface) =>
                              _updateInterface('inside_interface', iface),
                          placeholder: 'Use global setting',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Outside Interface'),
                        const SizedBox(height: 4),
                        InterfaceSelector.layer3(
                          device: widget.device,
                          selectedKey: _getInterfaceKeyFromName(
                            rule.outsideInterface,
                          ),
                          onChanged: (iface) =>
                              _updateInterface('outside_interface', iface),
                          placeholder: 'Use global setting',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Get interface names that have a specific NAT role configured
  List<String> _getInterfacesWithNatRole(NatInterfaceRole role) {
    final result = <String>[];
    final interfaces = widget.device.interfaces;
    final portsData = widget.device.config['ports'];

    for (int i = 0; i < interfaces.length; i++) {
      Map<String, dynamic>? portConfig;

      // Handle both List and Map formats for ports config
      if (portsData is List && i < portsData.length) {
        portConfig = portsData[i] as Map<String, dynamic>?;
      } else if (portsData is Map<String, dynamic>) {
        portConfig = portsData[i.toString()] as Map<String, dynamic>?;
      }

      if (portConfig != null) {
        final roleStr = portConfig['natRole'] as String?;
        if (roleStr != null) {
          final configuredRole = NatInterfaceRole.values.firstWhere(
            (r) => r.name == roleStr,
            orElse: () => NatInterfaceRole.none,
          );
          if (configuredRole == role) {
            result.add(interfaces[i].name);
          }
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule.value;
    if (rule == null) {
      return const Center(child: Text('No rule selected'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                rule.displayName,
                style: FluentTheme.of(context).typography.subtitle,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FluentTheme.of(
                    context,
                  ).accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getNatTypeLabel(rule.type),
                  style: FluentTheme.of(context).typography.caption,
                ),
              ),
              const Spacer(),
              if (widget.onDelete != null)
                Button(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ContentDialog(
                        title: const Text('Delete NAT Rule'),
                        content: Text(
                          'Are you sure you want to delete "${rule.displayName}"?',
                        ),
                        actions: [
                          Button(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onDelete!();
                            },
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                Colors.red,
                              ),
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Delete'),
                ),
            ],
          ),
        ),
        Divider(
          style: DividerTheme.of(
            context,
          ).merge(const DividerThemeData(horizontalMargin: EdgeInsets.all(0))),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: ListView(
              shrinkWrap: true,
              children: [
                // Status indicator
                Row(
                  children: [
                    Icon(
                      rule.enabled
                          ? FluentIcons.circle_fill
                          : FluentIcons.circle_ring,
                      size: 10,
                      color: rule.enabled
                          ? Colors.successPrimaryColor
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(rule.enabled ? 'Enabled' : 'Disabled'),
                    const Spacer(),
                    SyncedToggleSwitch(
                      label: 'Active',
                      controller: _enabledController,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                const Text('Description'),
                const SizedBox(height: 4),
                TextBox(
                  controller: _descriptionController.controller,
                  placeholder: 'Optional description',
                ),
                const SizedBox(height: 16),

                // Type-specific fields
                if (rule.type == NatType.staticNat) _buildStaticNatFields(),
                if (rule.type == NatType.dynamicNat) _buildDynamicNatFields(),
                if (rule.type == NatType.pat) _buildPatFields(),
                if (rule.type == NatType.staticPat) _buildStaticPatFields(),

                const SizedBox(height: 16),

                // Interface configuration
                _buildInterfaceSection(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
