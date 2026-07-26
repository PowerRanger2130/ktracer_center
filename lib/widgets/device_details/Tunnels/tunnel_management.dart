import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/interface_descriptor.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/utils/synced_controller.dart';
import 'package:ktracer_center/widgets/device_details/synced_toggle_switch.dart';
import 'package:ktracer_center/widgets/interface_selector.dart';
import 'package:ktracer_center/widgets/ip_address_field.dart';

class TunnelManagement extends StatefulWidget {
  const TunnelManagement({
    super.key,
    required this.tunnel,
    required this.device,
    required this.tunnelIndex,
    this.onDelete,
  });

  final ValueNotifier<TunnelConfig?> tunnel;
  final NetDevice device;
  final int tunnelIndex;
  final VoidCallback? onDelete;

  @override
  State<TunnelManagement> createState() => _TunnelManagementState();
}

class _TunnelManagementState extends State<TunnelManagement> {
  late RealtimeForm _form;
  late SyncedController<String> _descriptionController;
  late SyncedController<bool> _enabledController;

  // Common tunnel fields
  late SyncedController<String> _tunnelSourceController;
  late SyncedController<String> _tunnelDestinationController;
  late SyncedController<String> _tunnelIpAddressController;
  late SyncedController<int> _mtuController;

  // GRE fields
  late SyncedController<int> _keepaliveIntervalController;
  late SyncedController<int> _keepaliveRetriesController;

  // IPsec fields
  late SyncedController<String> _preSharedKeyController;
  late SyncedController<String> _peerAddressController;
  late SyncedController<int> _isakmpLifetimeController;
  late SyncedController<int> _ipsecLifetimeController;
  late SyncedController<String> _transformSetNameController;
  late SyncedController<String> _cryptoMapNameController;
  late SyncedController<int> _cryptoAclController;

  // PPPoE fields
  late SyncedController<String> _pppUsernameController;
  late SyncedController<String> _pppPasswordController;
  late SyncedController<String> _pppoeServiceNameController;
  late SyncedController<String> _chapHostnameController;
  late SyncedController<int> _dialerPoolNumberController;

  List<NetDevice> _projectDevices = const [];
  bool _isLoadingProjectDevices = false;
  Object? _projectDevicesError;

  @override
  void initState() {
    super.initState();
    _initForm();
    _loadProjectDevices();
    widget.tunnel.addListener(_handleTunnelChange);
    _handleTunnelChange();
  }

  void _initForm() {
    _form = RealtimeForm(tableName: 'net_devices');

    final prefix = 'config.tunnels.${widget.tunnelIndex}';
    _descriptionController = _form.addField('$prefix.description');
    _enabledController = _form.addBoolField('$prefix.enabled');

    // Common tunnel fields
    _tunnelSourceController = _form.addField('$prefix.tunnel_source');
    _tunnelDestinationController = _form.addField('$prefix.tunnel_destination');
    _tunnelIpAddressController = _form.addField('$prefix.tunnel_ip_address');
    _mtuController = _form.addIntField('$prefix.mtu');

    // GRE fields
    _keepaliveIntervalController = _form.addIntField(
      '$prefix.keepalive_interval',
    );
    _keepaliveRetriesController = _form.addIntField(
      '$prefix.keepalive_retries',
    );

    // IPsec fields
    _preSharedKeyController = _form.addField('$prefix.pre_shared_key');
    _peerAddressController = _form.addField('$prefix.peer_address');
    _isakmpLifetimeController = _form.addIntField('$prefix.isakmp_lifetime');
    _ipsecLifetimeController = _form.addIntField('$prefix.ipsec_lifetime');
    _transformSetNameController = _form.addField('$prefix.transform_set_name');
    _cryptoMapNameController = _form.addField('$prefix.crypto_map_name');
    _cryptoAclController = _form.addIntField('$prefix.crypto_acl');

    // PPPoE fields
    _pppUsernameController = _form.addField('$prefix.ppp_username');
    _pppPasswordController = _form.addField('$prefix.ppp_password');
    _pppoeServiceNameController = _form.addField('$prefix.pppoe_service_name');
    _chapHostnameController = _form.addField('$prefix.chap_hostname');
    _dialerPoolNumberController = _form.addIntField(
      '$prefix.dialer_pool_number',
    );
  }

  @override
  void didUpdateWidget(TunnelManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tunnel != oldWidget.tunnel ||
        widget.tunnelIndex != oldWidget.tunnelIndex) {
      oldWidget.tunnel.removeListener(_handleTunnelChange);

      _form.dispose();
      _initForm();

      widget.tunnel.addListener(_handleTunnelChange);
      _handleTunnelChange();
    }

    if (widget.device.projectId != oldWidget.device.projectId) {
      _loadProjectDevices();
    }
  }

  Future<void> _loadProjectDevices() async {
    setState(() {
      _isLoadingProjectDevices = true;
      _projectDevicesError = null;
    });

    try {
      final devices = await Database.getDevicesForProject(
        widget.device.projectId,
      );
      if (!mounted) return;

      devices.sort((a, b) {
        final nameA = a.hostname.toLowerCase();
        final nameB = b.hostname.toLowerCase();
        final byHostname = nameA.compareTo(nameB);
        if (byHostname != 0) return byHostname;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      setState(() {
        _projectDevices = devices;
        _isLoadingProjectDevices = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _projectDevicesError = error;
        _isLoadingProjectDevices = false;
      });
    }
  }

  void _handleTunnelChange() {
    final tunnel = widget.tunnel.value;
    if (tunnel == null) return;

    _form.setId(widget.device.id, {
      'config': {
        'tunnels': {
          '${widget.tunnelIndex}': {
            'description': tunnel.description,
            'enabled': tunnel.enabled,
            'tunnel_source': tunnel.tunnelSource ?? '',
            'tunnel_destination': tunnel.tunnelDestination ?? '',
            'tunnel_ip_address': tunnel.tunnelIpAddress ?? '',
            'mtu': tunnel.mtu ?? 0,
            'keepalive_interval': tunnel.keepaliveInterval ?? 0,
            'keepalive_retries': tunnel.keepaliveRetries ?? 0,
            'pre_shared_key': tunnel.preSharedKey ?? '',
            'peer_address': tunnel.peerAddress ?? '',
            'isakmp_lifetime': tunnel.isakmpLifetime ?? 86400,
            'ipsec_lifetime': tunnel.ipsecLifetime ?? 3600,
            'transform_set_name': tunnel.transformSetName ?? '',
            'crypto_map_name': tunnel.cryptoMapName ?? '',
            'crypto_acl': tunnel.cryptoAcl ?? 0,
            'ppp_username': tunnel.pppUsername ?? '',
            'ppp_password': tunnel.pppPassword ?? '',
            'pppoe_service_name': tunnel.pppoeServiceName ?? '',
            'chap_hostname': tunnel.chapHostname ?? '',
            'dialer_pool_number': tunnel.dialerPoolNumber ?? 1,
          },
        },
      },
    });
  }

  @override
  void dispose() {
    widget.tunnel.removeListener(_handleTunnelChange);
    _form.dispose();
    super.dispose();
  }

  Future<void> _updateTunnelFields(Map<String, dynamic> updates) async {
    final tunnels = widget.device.tunnels;
    if (widget.tunnelIndex < 0 || widget.tunnelIndex >= tunnels.length) return;

    final currentTunnel = widget.tunnel.value ?? tunnels[widget.tunnelIndex];
    final tunnelJson = currentTunnel.toJson()..addAll(updates);
    final updatedTunnel = TunnelConfig.fromJson(tunnelJson);

    final updatedTunnels = [...tunnels];
    updatedTunnels[widget.tunnelIndex] = updatedTunnel;

    await Database.updateDeviceConfig(widget.device.id, {
      'tunnels': updatedTunnels.map((t) => t.toJson()).toList(),
    });

    widget.device.tunnels = updatedTunnels;
    widget.tunnel.value = updatedTunnel;
    setState(() {});
  }

  Future<void> _updateTunnelField(String field, dynamic value) async {
    await _updateTunnelFields({field: value});
  }

  Future<void> _updateSourceInterface(InterfaceDescriptor? iface) async {
    if (iface == null) return;
    _tunnelSourceController.controller.text = iface.name;
    await _updateTunnelField('tunnel_source', iface.name);
  }

  Future<void> _updateTunnelDestination(
    NetDevice device,
    InterfaceDescriptor iface,
  ) async {
    final destinationValue = iface.ipAddress?.address ?? iface.name;
    await _updateTunnelFields({
      'tunnel_destination': destinationValue,
      'tunnel_destination_device_id': device.id,
      'tunnel_destination_interface_key': iface.key,
    });
  }

  Future<void> _clearTunnelDestination() async {
    await _updateTunnelFields({
      'tunnel_destination': null,
      'tunnel_destination_device_id': null,
      'tunnel_destination_interface_key': null,
    });
  }

  Future<void> _updatePppoeSourceInterface(InterfaceDescriptor? iface) async {
    if (iface == null) return;
    await _updateTunnelField('pppoe_source_interface', iface.name);
    setState(() {});
  }

  InterfaceFilter get _tunnelEndpointFilter =>
      const InterfaceFilter(onlyLayer3: true, requireIpv4OrDhcp: true);

  InterfaceDescriptor? _findInterfaceByKey(
    List<InterfaceDescriptor> interfaces,
    String? key,
  ) {
    if (key == null) return null;
    for (final iface in interfaces) {
      if (iface.key == key) {
        return iface;
      }
    }
    return null;
  }

  NetDevice? _findDestinationDevice(TunnelConfig tunnel) {
    final deviceId = tunnel.tunnelDestinationDeviceId;
    if (deviceId == null) return null;

    for (final device in _projectDevices) {
      if (device.id == deviceId) {
        return device;
      }
    }

    return null;
  }

  String _getTunnelDestinationDisplay(TunnelConfig tunnel) {
    final destinationDevice = _findDestinationDevice(tunnel);
    if (destinationDevice != null) {
      final destinationInterface = _findInterfaceByKey(
        _tunnelEndpointFilter.apply(
          InterfaceDescriptor.fromDevice(destinationDevice),
        ),
        tunnel.tunnelDestinationInterfaceKey,
      );

      if (destinationInterface != null) {
        return '${destinationDevice.hostname} • ${destinationInterface.displayName}';
      }

      return destinationDevice.hostname;
    }

    final fallback = tunnel.tunnelDestination?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    return 'Not selected';
  }

  bool _hasTunnelDestination(TunnelConfig tunnel) {
    return (tunnel.tunnelDestinationInterfaceKey?.isNotEmpty ?? false) ||
        (tunnel.tunnelDestination?.trim().isNotEmpty ?? false);
  }

  Future<void> _showTunnelDestinationPicker(TunnelConfig tunnel) async {
    if (_projectDevices.isEmpty && !_isLoadingProjectDevices) {
      await _loadProjectDevices();
    }

    if (!mounted) return;

    final availableDevices = _projectDevices
        .where((device) => device.id != widget.device.id)
        .toList();

    int? selectedDeviceId = tunnel.tunnelDestinationDeviceId;
    String? selectedInterfaceKey = tunnel.tunnelDestinationInterfaceKey;

    await showDialog<void>(
      barrierDismissible: true,
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            NetDevice? selectedDevice;
            for (final device in availableDevices) {
              if (device.id == selectedDeviceId) {
                selectedDevice = device;
                break;
              }
            }

            final selectableInterfaces = selectedDevice == null
                ? const <InterfaceDescriptor>[]
                : _tunnelEndpointFilter.apply(
                    InterfaceDescriptor.fromDevice(selectedDevice),
                  );

            final selectedInterface = _findInterfaceByKey(
              selectableInterfaces,
              selectedInterfaceKey,
            );

            return ContentDialog(
              title: const Text('Select Tunnel Destination'),
              content: SizedBox(
                width: 480,
                child: _isLoadingProjectDevices
                    ? const Center(child: ProgressRing())
                    : _projectDevicesError != null
                    ? InfoBar(
                        title: const Text('Unable to load project devices.'),
                        content: Text(_projectDevicesError.toString()),
                        severity: InfoBarSeverity.error,
                      )
                    : availableDevices.isEmpty
                    ? const InfoBar(
                        title: Text(
                          'No other devices are available in this project.',
                        ),
                        severity: InfoBarSeverity.info,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Device'),
                          const SizedBox(height: 4),
                          ComboBox<int>(
                            value: selectedDeviceId,
                            isExpanded: true,
                            popupColor: FluentTheme.of(context).menuColor,
                            placeholder: const Text('Select a device'),
                            items: availableDevices
                                .map(
                                  (device) => ComboBoxItem<int>(
                                    value: device.id,
                                    child: Text(
                                      '${device.hostname} (${device.name})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedDeviceId = value;
                                selectedInterfaceKey = null;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          if (selectedDevice == null)
                            const InfoBar(
                              title: Text(
                                'Select a device to choose its endpoint interface.',
                              ),
                              severity: InfoBarSeverity.info,
                            )
                          else ...[
                            Text(
                              'Interface',
                              style: FluentTheme.of(
                                context,
                              ).typography.bodyStrong,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 260,
                              child: InterfaceSelector(
                                device: selectedDevice,
                                selectedKey: selectedInterface?.key,
                                mode: InterfaceSelectorMode.list,
                                showIpAddress: false,
                                emptyMessage:
                                    'No DHCP or IPv4-capable interfaces are available on this device.',
                                filter: _tunnelEndpointFilter,
                                onChanged: (iface) {
                                  setDialogState(() {
                                    selectedInterfaceKey = iface?.key;
                                  });
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              actions: [
                Button(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                FilledButton(
                  onPressed: selectedDevice != null && selectedInterface != null
                      ? () async {
                          Navigator.of(dialogContext).pop();
                          await _updateTunnelDestination(
                            selectedDevice!,
                            selectedInterface,
                          );
                        }
                      : null,
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getTunnelTypeLabel(TunnelType type) {
    switch (type) {
      case TunnelType.gre:
        return 'GRE Tunnel';
      case TunnelType.ipsec:
        return 'IPsec VPN';
      case TunnelType.greOverIpsec:
        return 'GRE over IPsec';
      case TunnelType.pppoe:
        return 'PPPoE Client';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tunnel = widget.tunnel.value;
    if (tunnel == null) {
      return const Center(child: Text('No tunnel selected'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                tunnel.displayName,
                style: FluentTheme.of(context).typography.subtitle,
              ),
              const Spacer(),
              SyncedToggleSwitch(
                controller: _enabledController,
                label: 'Enabled',
              ),
              const SizedBox(width: 16),
              Button(
                style: ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(Colors.red),
                ),
                onPressed: widget.onDelete,
                child: const Row(
                  children: [
                    Icon(FluentIcons.delete, size: 14),
                    SizedBox(width: 6),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getTunnelTypeLabel(tunnel.type),
            style: TextStyle(color: Colors.grey[100]),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Description
          const Text('Description'),
          const SizedBox(height: 4),
          TextBox(
            controller: _descriptionController.controller,
            placeholder: 'Enter a description for this tunnel',
          ),
          const SizedBox(height: 20),

          // Type-specific fields
          _buildTypeSpecificFields(tunnel),
        ],
      ),
    );
  }

  Widget _buildTypeSpecificFields(TunnelConfig tunnel) {
    switch (tunnel.type) {
      case TunnelType.gre:
        return _buildGreFields(tunnel);
      case TunnelType.ipsec:
        return _buildIpsecFields(tunnel);
      case TunnelType.greOverIpsec:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreFields(tunnel),
            const SizedBox(height: 24),
            _buildIpsecFields(tunnel),
          ],
        );
      case TunnelType.pppoe:
        return _buildPppoeFields(tunnel);
    }
  }

  Widget _buildGreFields(TunnelConfig tunnel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GRE Configuration',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 12),

        // Tunnel Source
        const Text('Tunnel Source'),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextBox(
                controller: _tunnelSourceController.controller,
                placeholder: 'Interface or IP address',
              ),
            ),
            const SizedBox(width: 8),
            Button(
              child: const Text('Select Interface'),
              onPressed: () {
                showDialog(
                  barrierDismissible: true,
                  context: context,
                  builder: (context) => ContentDialog(
                    title: const Text('Select Source Interface'),
                    content: SizedBox(
                      width: 400,
                      height: 300,
                      child: InterfaceSelector(
                        device: widget.device,
                        mode: InterfaceSelectorMode.list,
                        onChanged: (iface) {
                          _updateSourceInterface(iface);
                          Navigator.of(context).pop();
                        },
                        filter: _tunnelEndpointFilter,
                      ),
                    ),
                    actions: [
                      Button(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tunnel Destination
        const Text('Tunnel Destination'),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                _getTunnelDestinationDisplay(tunnel),
                style: TextStyle(
                  color: _hasTunnelDestination(tunnel)
                      ? null
                      : Colors.grey[100],
                ),
              ),
            ),
            Button(
              child: const Text('Select Interface'),
              onPressed: () => _showTunnelDestinationPicker(tunnel),
            ),
            if (_hasTunnelDestination(tunnel)) ...[
              const SizedBox(width: 8),
              Button(
                child: const Text('Clear'),
                onPressed: _clearTunnelDestination,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Tunnel IP Address
        const Text('Tunnel IP Address (CIDR)'),
        const SizedBox(height: 4),
        IpAddressField(
          controller: _tunnelIpAddressController,
          placeholder: '10.0.0.1/30',
        ),
        const SizedBox(height: 16),

        // Optional settings
        Expander(
          header: const Text('Advanced GRE Settings'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MTU'),
                        const SizedBox(height: 4),
                        NumberBox<int>(
                          value: _mtuController.value > 0
                              ? _mtuController.value
                              : null,
                          placeholder: '1476',
                          min: 68,
                          max: 9000,
                          onChanged: (value) {
                            if (value != null) {
                              _mtuController.onChanged(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Keepalive Interval'),
                        const SizedBox(height: 4),
                        NumberBox<int>(
                          value: _keepaliveIntervalController.value > 0
                              ? _keepaliveIntervalController.value
                              : null,
                          placeholder: '10',
                          min: 1,
                          max: 32767,
                          onChanged: (value) {
                            if (value != null) {
                              _keepaliveIntervalController.onChanged(value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Keepalive Retries'),
                        const SizedBox(height: 4),
                        NumberBox<int>(
                          value: _keepaliveRetriesController.value > 0
                              ? _keepaliveRetriesController.value
                              : null,
                          placeholder: '3',
                          min: 1,
                          max: 255,
                          onChanged: (value) {
                            if (value != null) {
                              _keepaliveRetriesController.onChanged(value);
                            }
                          },
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

  Widget _buildIpsecFields(TunnelConfig tunnel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IPsec Configuration',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 12),

        // Peer Address
        const Text('Peer Address'),
        const SizedBox(height: 4),
        IpAddressField(
          controller: _peerAddressController,
          placeholder: '203.0.113.1',
        ),
        const SizedBox(height: 12),

        // Pre-shared Key
        const Text('Pre-shared Key'),
        const SizedBox(height: 4),
        PasswordBox(
          controller: _preSharedKeyController.controller,
          placeholder: 'Enter pre-shared key',
        ),
        const SizedBox(height: 16),

        // Phase 1 Settings
        Text(
          'Phase 1 (ISAKMP) Settings',
          style: FluentTheme.of(context).typography.body,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Encryption'),
                  const SizedBox(height: 4),
                  ComboBox<IpsecEncryption>(
                    value: tunnel.encryption ?? IpsecEncryption.aes256,
                    isExpanded: true,
                    popupColor: FluentTheme.of(context).menuColor,
                    items: IpsecEncryption.values
                        .map(
                          (e) => ComboBoxItem<IpsecEncryption>(
                            value: e,
                            child: Text(e.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _updateTunnelField('encryption', value.name);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hash'),
                  const SizedBox(height: 4),
                  ComboBox<IpsecHash>(
                    value: tunnel.hash ?? IpsecHash.sha256,
                    isExpanded: true,
                    popupColor: FluentTheme.of(context).menuColor,
                    items: IpsecHash.values
                        .map(
                          (e) => ComboBoxItem<IpsecHash>(
                            value: e,
                            child: Text(e.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _updateTunnelField('hash', value.name);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DH Group'),
                  const SizedBox(height: 4),
                  ComboBox<IpsecDhGroup>(
                    value: tunnel.dhGroup ?? IpsecDhGroup.group14,
                    isExpanded: true,
                    popupColor: FluentTheme.of(context).menuColor,
                    items: IpsecDhGroup.values
                        .map(
                          (e) => ComboBoxItem<IpsecDhGroup>(
                            value: e,
                            child: Text(e.name.replaceAll('group', 'Group ')),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _updateTunnelField('dh_group', value.name);
                      }
                    },
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
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ISAKMP Lifetime (seconds)'),
                  const SizedBox(height: 4),
                  NumberBox<int>(
                    value: _isakmpLifetimeController.value > 0
                        ? _isakmpLifetimeController.value
                        : null,
                    placeholder: '86400',
                    min: 60,
                    max: 86400,
                    onChanged: (value) {
                      if (value != null) {
                        _isakmpLifetimeController.onChanged(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('IPsec SA Lifetime (seconds)'),
                  const SizedBox(height: 4),
                  NumberBox<int>(
                    value: _ipsecLifetimeController.value > 0
                        ? _ipsecLifetimeController.value
                        : null,
                    placeholder: '3600',
                    min: 60,
                    max: 86400,
                    onChanged: (value) {
                      if (value != null) {
                        _ipsecLifetimeController.onChanged(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Advanced IPsec settings
        Expander(
          header: const Text('Advanced IPsec Settings'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Transform Set Name'),
                        const SizedBox(height: 4),
                        TextBox(
                          controller: _transformSetNameController.controller,
                          placeholder: 'e.g., MY-TRANSFORM',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Crypto Map Name'),
                        const SizedBox(height: 4),
                        TextBox(
                          controller: _cryptoMapNameController.controller,
                          placeholder: 'e.g., MY-MAP',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Crypto ACL #'),
                        const SizedBox(height: 4),
                        NumberBox<int>(
                          value: _cryptoAclController.value > 0
                              ? _cryptoAclController.value
                              : null,
                          placeholder: '100',
                          min: 100,
                          max: 199,
                          onChanged: (value) {
                            if (value != null) {
                              _cryptoAclController.onChanged(value);
                            }
                          },
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

  Widget _buildPppoeFields(TunnelConfig tunnel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PPPoE Configuration',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 12),

        // Source Interface
        const Text('Source Interface (Physical)'),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                tunnel.pppoeSourceInterface ?? 'Not selected',
                style: TextStyle(
                  color: tunnel.pppoeSourceInterface == null
                      ? Colors.grey[100]
                      : null,
                ),
              ),
            ),
            Button(
              child: const Text('Select Interface'),
              onPressed: () {
                showDialog(
                  barrierDismissible: true,
                  context: context,
                  builder: (context) => ContentDialog(
                    title: const Text('Select PPPoE Source Interface'),
                    content: SizedBox(
                      width: 400,
                      height: 300,
                      child: InterfaceSelector(
                        device: widget.device,
                        mode: InterfaceSelectorMode.list,
                        onChanged: (iface) {
                          _updatePppoeSourceInterface(iface);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    actions: [
                      Button(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // PPP Credentials
        Text('PPP Credentials', style: FluentTheme.of(context).typography.body),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Username'),
                  const SizedBox(height: 4),
                  TextBox(
                    controller: _pppUsernameController.controller,
                    placeholder: 'ISP username',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Password'),
                  const SizedBox(height: 4),
                  PasswordBox(
                    controller: _pppPasswordController.controller,
                    placeholder: 'ISP password',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Service Name (optional)'),
                  const SizedBox(height: 4),
                  TextBox(
                    controller: _pppoeServiceNameController.controller,
                    placeholder: 'ISP service name',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dialer Pool'),
                  const SizedBox(height: 4),
                  NumberBox<int>(
                    value: _dialerPoolNumberController.value > 0
                        ? _dialerPoolNumberController.value
                        : 1,
                    min: 1,
                    max: 255,
                    onChanged: (value) {
                      if (value != null) {
                        _dialerPoolNumberController.onChanged(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Advanced PPPoE settings
        Expander(
          header: const Text('Advanced PPPoE Settings'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CHAP Hostname'),
              const SizedBox(height: 4),
              TextBox(
                controller: _chapHostnameController.controller,
                placeholder: 'Optional CHAP hostname',
              ),
              const SizedBox(height: 12),
              const Text('Tunnel IP Address'),
              const SizedBox(height: 4),
              TextBox(
                controller: _tunnelIpAddressController.controller,
                placeholder: 'Usually negotiated, or set manually',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MTU'),
                        const SizedBox(height: 4),
                        NumberBox<int>(
                          value: _mtuController.value > 0
                              ? _mtuController.value
                              : null,
                          placeholder: '1492',
                          min: 68,
                          max: 1500,
                          onChanged: (value) {
                            if (value != null) {
                              _mtuController.onChanged(value);
                            }
                          },
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
}
