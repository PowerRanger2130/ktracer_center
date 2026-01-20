import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/interface_descriptor.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/network/ipv4_utils.dart';
import 'package:ktracer_center/utils/synced_controller.dart';
import 'package:ktracer_center/widgets/constrained_ip_field.dart';
import 'package:ktracer_center/widgets/device_details/synced_toggle_switch.dart';
import 'package:ktracer_center/widgets/interface_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DhcpPoolManagement extends StatefulWidget {
  const DhcpPoolManagement({
    super.key,
    required this.pool,
    required this.device,
    required this.poolIndex,
    this.onDelete,
  });

  final ValueNotifier<DhcpPoolConfig?> pool;
  final NetDevice device;
  final int poolIndex;
  final VoidCallback? onDelete;

  @override
  State<DhcpPoolManagement> createState() => _DhcpPoolManagementState();
}

class _DhcpPoolManagementState extends State<DhcpPoolManagement> {
  late RealtimeForm _form;
  late SyncedController<String> _defaultRouterController;
  late SyncedController<String> _dnsServerController;
  late SyncedController<String> _dnsServerSecondaryController;
  late SyncedController<String> _domainNameController;
  late SyncedController<int> _leaseTimeController;
  late SyncedController<String> _excludeStartController;
  late SyncedController<String> _excludeEndController;
  late SyncedController<bool> _enabledController;

  @override
  void initState() {
    super.initState();
    _initForm();
    widget.pool.addListener(_handlePoolChange);
    _handlePoolChange();
  }

  void _initForm() {
    _form = RealtimeForm(tableName: 'net_devices');

    final prefix = 'config.dhcp_pools.${widget.poolIndex}';
    _defaultRouterController = _form.addField('$prefix.default_router');
    _dnsServerController = _form.addField('$prefix.dns_server');
    _dnsServerSecondaryController = _form.addField(
      '$prefix.dns_server_secondary',
    );
    _domainNameController = _form.addField('$prefix.domain_name');
    _leaseTimeController = _form.addIntField(
      '$prefix.lease_time',
      initialValue: 86400,
    );
    _excludeStartController = _form.addField('$prefix.exclude_start');
    _excludeEndController = _form.addField('$prefix.exclude_end');
    _enabledController = _form.addBoolField('$prefix.enabled');
  }

  @override
  void didUpdateWidget(DhcpPoolManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pool != oldWidget.pool ||
        widget.poolIndex != oldWidget.poolIndex) {
      oldWidget.pool.removeListener(_handlePoolChange);

      // Rebuild form fields with new index
      _form.dispose();
      _initForm();

      widget.pool.addListener(_handlePoolChange);
      _handlePoolChange();
    }
  }

  void _handlePoolChange() {
    final pool = widget.pool.value;
    if (pool == null) return;

    _form.setId(widget.device.id, {
      'config': {
        'dhcp_pools': {
          '${widget.poolIndex}': {
            'network': pool.network,
            'subnet_mask': pool.subnetMask,
            'default_router': pool.defaultRouter ?? '',
            'dns_server': pool.dnsServer ?? '',
            'dns_server_secondary': pool.dnsServerSecondary ?? '',
            'domain_name': pool.domainName ?? '',
            'lease_time': pool.leaseTime,
            'exclude_start': pool.excludeStart ?? '',
            'exclude_end': pool.excludeEnd ?? '',
            'enabled': pool.enabled,
          },
        },
      },
    });
  }

  @override
  void dispose() {
    widget.pool.removeListener(_handlePoolChange);
    _form.dispose();
    super.dispose();
  }

  String _formatLeaseTime(int seconds) {
    if (seconds < 60) return '$seconds seconds';
    if (seconds < 3600) return '${seconds ~/ 60} minutes';
    if (seconds < 86400) return '${seconds ~/ 3600} hours';
    return '${seconds ~/ 86400} days';
  }

  /// Get the selected interface key for the pool
  String? _getSelectedInterfaceKey(DhcpPoolConfig pool) {
    if (pool.vlanId != null) return 'vlan:${pool.vlanId}';
    if (pool.interfaceIndex != null) return 'port:${pool.interfaceIndex}';
    return null;
  }

  /// Get network constraint for this pool's IP fields
  IPv4Network? _getNetworkConstraint(DhcpPoolConfig pool) {
    if (pool.network.isEmpty || pool.subnetMask.isEmpty) return null;
    try {
      final prefix = IPv4Math.maskToPrefixLength(pool.subnetMask);
      if (prefix == null) return null;
      return IPv4Network.fromCIDR('${pool.network}/$prefix');
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateInterface(InterfaceDescriptor? iface) async {
    if (iface == null) return;

    // Get current config from DB and update it
    try {
      final data = await Supabase.instance.client
          .from('net_devices')
          .select('config')
          .eq('id', widget.device.id)
          .single();

      final config = Map<String, dynamic>.from(data['config'] ?? {});
      final dhcpPools = Map<String, dynamic>.from(config['dhcp_pools'] ?? {});
      final poolData = Map<String, dynamic>.from(
        dhcpPools['${widget.poolIndex}'] ?? {},
      );

      // Update interface binding based on type
      if (iface.type == InterfaceType.vlanSvi && iface.vlanId != null) {
        poolData['vlan_id'] = iface.vlanId;
        poolData.remove('interface_index');
      } else if (iface.interfaceIndex != null) {
        poolData['interface_index'] = iface.interfaceIndex;
        poolData.remove('vlan_id');
      }

      // Update network settings from interface
      if (iface.ipAddress != null) {
        // Calculate network address from the interface IP
        final ip = iface.ipAddress!;
        final parts = ip.address.split('.');
        final maskParts = ip.subnetMask.split('.');
        final networkParts = <String>[];
        for (int i = 0; i < 4; i++) {
          networkParts.add(
            (int.parse(parts[i]) & int.parse(maskParts[i])).toString(),
          );
        }
        poolData['network'] = networkParts.join('.');
        poolData['subnet_mask'] = ip.subnetMask;

        // Auto-populate default router with interface IP if not set
        final currentRouter = poolData['default_router'] as String?;
        if (currentRouter == null || currentRouter.isEmpty) {
          poolData['default_router'] = ip.address;
          _defaultRouterController.controller.text = ip.address;
        }
      }

      dhcpPools['${widget.poolIndex}'] = poolData;
      config['dhcp_pools'] = dhcpPools;

      await Supabase.instance.client
          .from('net_devices')
          .update({'config': config})
          .eq('id', widget.device.id);

      setState(() {});
    } catch (e) {
      debugPrint('Error updating interface: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool.value;
    if (pool == null) {
      return const Center(child: Text('No pool selected'));
    }

    final networkConstraint = _getNetworkConstraint(pool);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                pool.name,
                style: FluentTheme.of(context).typography.subtitle,
              ),
              const Spacer(),
              if (widget.onDelete != null)
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
                        title: const Text('Delete DHCP Pool'),
                        content: Text(
                          'Are you sure you want to delete pool "${pool.name}"?',
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
                    if (confirmed == true) {
                      widget.onDelete!();
                    }
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
                      pool.enabled
                          ? FluentIcons.circle_fill
                          : FluentIcons.circle_ring,
                      size: 12,
                      color: pool.enabled ? Colors.successPrimaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pool.enabled ? 'Pool Active' : 'Pool Disabled',
                      style: FluentTheme.of(context).typography.body?.copyWith(
                        color: pool.enabled ? Colors.successPrimaryColor : null,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '~${pool.usableAddresses} addresses',
                      style: FluentTheme.of(context).typography.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Network Settings Section - Interface Selector
                Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Network Interface',
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select the interface this DHCP pool will serve',
                          style: FluentTheme.of(context).typography.caption,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 300,
                      child: InterfaceSelector.withIpAddress(
                        device: widget.device,
                        selectedKey: _getSelectedInterfaceKey(pool),
                        onChanged: _updateInterface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Exclusions Section
                Text(
                  'Address Exclusion',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 4),
                Text(
                  'Exclude IP addresses from being assigned (e.g., for static devices)',
                  style: FluentTheme.of(context).typography.caption,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: networkConstraint != null
                          ? ConstrainedIpField.dhcpRangeStart(
                              controller: _excludeStartController,
                              network: networkConstraint,
                              rangeEndAddress: _excludeEndController.value,
                              label: 'Exclude Start',
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Exclude Star'),
                                const SizedBox(height: 4),
                                TextBox(
                                  prefix: Text("192.168."),
                                  prefixMode: OverlayVisibilityMode.always,
                                  controller:
                                      _excludeStartController.controller,
                                  onChanged: _excludeStartController.onChanged,
                                  placeholder: '192.168.10.1',
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: networkConstraint != null
                          ? ConstrainedIpField.dhcpRangeEnd(
                              controller: _excludeEndController,
                              network: networkConstraint,
                              rangeStartAddress: _excludeStartController.value,
                              label: 'Exclude End',
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Exclude End'),
                                const SizedBox(height: 4),
                                TextBox(
                                  controller: _excludeEndController.controller,
                                  onChanged: _excludeEndController.onChanged,
                                  placeholder: '192.168.10.10',
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Gateway & DNS Section
                Text(
                  'Gateway & DNS',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 8),
                if (networkConstraint != null)
                  ConstrainedIpField.gateway(
                    controller: _defaultRouterController,
                    network: networkConstraint,
                    label: 'Default Router (Gateway)',
                  )
                else ...[
                  const Text('Default Router (Gateway)'),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 300,
                    child: TextBox(
                      controller: _defaultRouterController.controller,
                      onChanged: _defaultRouterController.onChanged,
                      placeholder: '192.168.10.1',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Primary DNS Server'),
                          const SizedBox(height: 4),
                          TextBox(
                            controller: _dnsServerController.controller,
                            onChanged: _dnsServerController.onChanged,
                            placeholder: '8.8.8.8',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Secondary DNS Server'),
                          const SizedBox(height: 4),
                          TextBox(
                            controller:
                                _dnsServerSecondaryController.controller,
                            onChanged: _dnsServerSecondaryController.onChanged,
                            placeholder: '8.8.4.4',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Options Section
                Text(
                  'Options',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 8),
                const Text('Domain Name'),
                const SizedBox(height: 4),
                SizedBox(
                  width: 300,
                  child: TextBox(
                    controller: _domainNameController.controller,
                    onChanged: _domainNameController.onChanged,
                    placeholder: 'example.local',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Lease Time'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    SizedBox(
                      width: 150,
                      child: NumberBox<int>(
                        value: _leaseTimeController.value,
                        onChanged: (value) {
                          if (value != null) {
                            _leaseTimeController.onChanged(value);
                            setState(() {});
                          }
                        },
                        min: 60,
                        max: 2592000, // 30 days
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'seconds (${_formatLeaseTime(_leaseTimeController.value)})',
                      style: FluentTheme.of(context).typography.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Enable/Disable
                SyncedToggleSwitch(
                  label: 'Pool Enabled',
                  controller: _enabledController,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
