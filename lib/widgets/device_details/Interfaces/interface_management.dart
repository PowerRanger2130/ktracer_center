import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/devices/switchport.dart';
import 'package:ktracer_center/devices/system_constraints.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/ipv4_utils.dart';
import 'package:ktracer_center/network/port.dart';
import 'package:ktracer_center/utils/ip_change_relay.dart';
import 'package:ktracer_center/utils/synced_controller.dart';
import 'package:ktracer_center/widgets/device_details/mac_address_multi_select.dart';
import 'package:ktracer_center/widgets/device_details/synced_toggle_switch.dart';
import 'package:ktracer_center/widgets/device_details/VLANs/vlan_multi_select.dart';
import 'package:ktracer_center/widgets/ip_address_field.dart';
import 'package:ktracer_center/widgets/ipv6_address_field.dart';

class InterfaceManagement extends StatefulWidget {
  const InterfaceManagement({
    super.key,
    required this.interface_,
    required this.device,
    required this.interfaceIndex,
    this.selectedInterfaceIndices,
  });

  final ValueNotifier<Port?> interface_;
  final NetDevice device;
  final int interfaceIndex;

  /// When multiple interfaces are selected, changes apply to all of them
  final Set<int>? selectedInterfaceIndices;

  @override
  State<InterfaceManagement> createState() => _InterfaceManagementState();
}

class _InterfaceManagementState extends State<InterfaceManagement> {
  late RealtimeForm _form;
  late SyncedController<String> _descriptionController;
  late SyncedController<bool> _enabledController;
  late SyncedController<SwitchportMode> _modeController;
  late SyncedController<int> _vlanController;
  late SyncedController<int> _nativeVlanController;
  late SyncedController<Set<int>> _allowedVlansController;

  // IP Address controller (for routed ports - CIDR format)
  late SyncedController<String> _ipCidrController;

  // IPv6 Address controller (for routed ports - CIDR format)
  late SyncedController<String> _ipv6CidrController;

  // Port Security controllers
  late SyncedController<bool> _portSecurityEnabledController;
  late SyncedController<Set<String>> _portSecurityMacAddressesController;
  late SyncedController<bool> _portSecurityStickyController;
  late SyncedController<PortSecurityViolation> _portSecurityViolationController;
  late SyncedController<int> _portSecurityMaximumController;

  // Protected port controller
  late SyncedController<bool> _protectedPortController;

  // Spanning Tree controllers
  late SyncedController<bool> _spanningTreePortfastController;
  late SyncedController<bool> _spanningTreeBpduGuardController;
  late SyncedController<bool> _spanningTreeBpduFilterController;
  late SyncedController<int> _spanningTreeCostController;
  late SyncedController<int> _spanningTreePortPriorityController;
  late SyncedController<SpanningTreeGuard> _spanningTreeGuardController;

  // NAT Role controller (for routed ports on NAT-capable devices)
  late SyncedController<NatInterfaceRole> _natRoleController;

  // IP change relay tracking
  String? _previousIpCidr;

  /// Check if multiple interfaces are selected
  bool get _isMultiSelect =>
      widget.selectedInterfaceIndices != null &&
      widget.selectedInterfaceIndices!.length > 1;

  /// Get the set of interface indices to apply changes to
  Set<int> get _targetInterfaceIndices =>
      widget.selectedInterfaceIndices ?? {widget.interfaceIndex};

  /// Format selected interface indices as IOS-style ranges (e.g., "Fa0/1-5,Fa0/8")
  String _formatInterfaceRange() {
    if (!_isMultiSelect) return '';

    final interfaces = widget.device.interfaces;
    final interfaceIndices = _targetInterfaceIndices;

    // Group interfaces by their prefix (e.g., Fa0/, Gi0/)
    final interfacesByPrefix = <String, List<int>>{};

    for (final idx in interfaceIndices) {
      if (idx >= interfaces.length) continue;
      final name = _getShortInterfaceName(interfaces[idx].name);
      // Extract prefix and number, e.g., "Fa0/1" -> prefix="Fa0/", number=1
      final match = RegExp(r'^(.+?)(\d+)$').firstMatch(name);
      if (match != null) {
        final prefix = match.group(1)!;
        final number = int.parse(match.group(2)!);
        interfacesByPrefix.putIfAbsent(prefix, () => []).add(number);
      }
    }

    // Build range strings for each prefix
    final ranges = <String>[];
    for (final entry in interfacesByPrefix.entries) {
      final prefix = entry.key;
      final numbers = entry.value..sort();

      // Convert sorted numbers to ranges
      final rangeStrings = <String>[];
      int? rangeStart;
      int? rangeEnd;

      for (final num in numbers) {
        if (rangeStart == null) {
          rangeStart = num;
          rangeEnd = num;
        } else if (num == rangeEnd! + 1) {
          rangeEnd = num;
        } else {
          // End current range and start new one
          if (rangeStart == rangeEnd) {
            rangeStrings.add('$prefix$rangeStart');
          } else {
            rangeStrings.add('$prefix$rangeStart-$rangeEnd');
          }
          rangeStart = num;
          rangeEnd = num;
        }
      }

      // Don't forget the last range
      if (rangeStart != null) {
        if (rangeStart == rangeEnd) {
          rangeStrings.add('$prefix$rangeStart');
        } else {
          rangeStrings.add('$prefix$rangeStart-$rangeEnd');
        }
      }

      ranges.addAll(rangeStrings);
    }

    return ranges.join(', ');
  }

  String _getShortInterfaceName(String name) {
    return name
        .replaceAll('FastEthernet', 'Fa')
        .replaceAll('GigabitEthernet', 'Gi')
        .replaceAll('TenGigabitEthernet', 'Te');
  }

  @override
  void initState() {
    super.initState();
    _initFormControllers();

    widget.interface_.addListener(_handleInterfaceChange);
    _handleInterfaceChange();

    // Listen for IP changes to trigger relay
    _ipCidrController.addListener(_handleIpChange);
  }

  /// Handle IP address changes and relay to dependent DHCP pools
  Future<void> _handleIpChange() async {
    final newIpCidr = _ipCidrController.value;

    // Skip if no actual change
    if (newIpCidr == _previousIpCidr) return;

    final oldIpCidr = _previousIpCidr;
    _previousIpCidr = newIpCidr;

    // Check if this interface has any DHCP pools
    if (!widget.device.hasAffectedDhcpPools(
      interfaceIndex: widget.interfaceIndex,
    )) {
      return;
    }

    // Build the change object
    final change = IpAddressChange(
      oldAddress: oldIpCidr != null && oldIpCidr.isNotEmpty
          ? IPv4.tryParse(oldIpCidr)
          : null,
      newAddress: newIpCidr.isNotEmpty ? IPv4.tryParse(newIpCidr) : null,
      source: InterfaceChangeSource.port,
      interfaceIndex: widget.interfaceIndex,
    );

    // Preview what will change
    final preview = IpChangeRelayService.previewIpChange(widget.device, change);

    if (!preview.hasChanges || !mounted) return;

    // Show confirmation dialog
    final confirmed = await _showCascadingChangeDialog(preview);

    if (confirmed == true && mounted) {
      final result = await IpChangeRelayService.applyPreviewedChange(
        widget.device,
        preview,
      );

      if (result.hasAffectedPools && mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('DHCP Pools Updated'),
            content: Text('Updated pools: ${result.affectedPools.join(", ")}'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      }
    }
  }

  /// Show dialog to confirm cascading changes
  Future<bool?> _showCascadingChangeDialog(IpChangePreview preview) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Update Related Configuration?'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Changing this IP address will affect the following configurations:',
              ),
              const SizedBox(height: 16),
              ...preview.dhcpPoolChanges.map(
                (poolChange) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Expander(
                    header: Row(
                      children: [
                        const Icon(FluentIcons.server, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'DHCP Pool: ${poolChange.poolName}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: poolChange.changes
                          .map(
                            (change) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '• $change',
                                style: FluentTheme.of(context).typography.body,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Do you want to update these configurations automatically?',
                style: FluentTheme.of(
                  context,
                ).typography.body?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, Keep Current'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Update All'),
          ),
        ],
      ),
    );
  }

  void _initFormControllers() {
    _form = RealtimeForm(tableName: 'net_devices');
    _descriptionController = _form.addField(
      'config.ports.${widget.interfaceIndex}.description',
    );
    _enabledController = _form.addBoolField(
      'config.ports.${widget.interfaceIndex}.enabled',
    );

    // IP Address controller (for routed ports - CIDR format)
    _ipCidrController = _form.addField(
      'config.ports.${widget.interfaceIndex}.ip_cidr',
    );

    // IPv6 Address controller (for routed ports - CIDR format)
    _ipv6CidrController = _form.addField(
      'config.ports.${widget.interfaceIndex}.ipv6_cidr',
    );

    _modeController = _form.addEnumField<SwitchportMode>(
      'config.ports.${widget.interfaceIndex}.mode',
      initialValue: SwitchportMode.access,
      values: SwitchportMode.values,
    );
    _vlanController = _form.addIntField(
      'config.ports.${widget.interfaceIndex}.vlan',
      initialValue: 1,
    );
    _nativeVlanController = _form.addIntField(
      'config.ports.${widget.interfaceIndex}.nativeVlan',
      initialValue: 1,
    );
    _allowedVlansController = _form.addIntSetField(
      'config.ports.${widget.interfaceIndex}.allowedVlans',
    );

    // Protected port controller
    _protectedPortController = _form.addBoolField(
      'config.ports.${widget.interfaceIndex}.protectedPort',
    );

    // Port Security controllers
    _portSecurityEnabledController = _form.addBoolField(
      'config.ports.${widget.interfaceIndex}.portSecurityEnabled',
    );
    _portSecurityMacAddressesController = _form.addStringSetField(
      'config.ports.${widget.interfaceIndex}.portSecurityMacAddresses',
    );
    _portSecurityStickyController = _form.addBoolField(
      'config.ports.${widget.interfaceIndex}.portSecuritySticky',
    );
    _portSecurityViolationController = _form
        .addEnumField<PortSecurityViolation>(
          'config.ports.${widget.interfaceIndex}.portSecurityViolation',
          initialValue: PortSecurityViolation.shutdown,
          values: PortSecurityViolation.values,
        );
    _portSecurityMaximumController = _form.addIntField(
      'config.ports.${widget.interfaceIndex}.portSecurityMaximum',
      initialValue: 1,
    );

    // Spanning Tree controllers
    _spanningTreePortfastController = _form.addBoolField(
      'config.ports.${widget.interfaceIndex}.spanningTreePortfast',
    );
    _spanningTreeBpduGuardController = _form.addBoolField(
      'config.ports.${widget.interfaceIndex}.spanningTreeBpduGuard',
    );
    _spanningTreeBpduFilterController = _form.addBoolField(
      'config.ports.${widget.interfaceIndex}.spanningTreeBpduFilter',
    );
    _spanningTreeCostController = _form.addIntField(
      'config.ports.${widget.interfaceIndex}.spanningTreeCost',
      initialValue: 0,
    );
    _spanningTreePortPriorityController = _form.addIntField(
      'config.ports.${widget.interfaceIndex}.spanningTreePortPriority',
      initialValue: 128,
    );
    _spanningTreeGuardController = _form.addEnumField<SpanningTreeGuard>(
      'config.ports.${widget.interfaceIndex}.spanningTreeGuard',
      initialValue: SpanningTreeGuard.none,
      values: SpanningTreeGuard.values,
    );

    // NAT Role controller (for routed ports on NAT-capable devices)
    _natRoleController = _form.addEnumField<NatInterfaceRole>(
      'config.ports.${widget.interfaceIndex}.natRole',
      initialValue: NatInterfaceRole.none,
      values: NatInterfaceRole.values,
    );
  }

  @override
  void didUpdateWidget(InterfaceManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.interface_ != oldWidget.interface_ ||
        widget.interfaceIndex != oldWidget.interfaceIndex) {
      oldWidget.interface_.removeListener(_handleInterfaceChange);

      // Reset previous IP tracking when interface changes
      _previousIpCidr = null;

      // Rebuild form fields with new index
      _form.dispose();
      _initFormControllers();

      widget.interface_.addListener(_handleInterfaceChange);
      _handleInterfaceChange();
    } else if (widget.selectedInterfaceIndices !=
        oldWidget.selectedInterfaceIndices) {
      // Update multi-select indices without rebuilding the whole form
      _updateMultiSelectIndices();
    }
  }

  void _updateMultiSelectIndices() {
    if (_isMultiSelect) {
      final otherInterfaces = Set<int>.from(_targetInterfaceIndices)
        ..remove(widget.interfaceIndex);
      _form.additionalPortIndices = otherInterfaces;
    } else {
      _form.additionalPortIndices = null;
    }
  }

  void _handleInterfaceChange() {
    final interface_ = widget.interface_.value;
    if (interface_ == null) return;

    // Initialize previous IP for relay tracking
    _previousIpCidr ??= interface_.ipAddress?.toCIDR() ?? '';

    final interfaceConfig = <String, dynamic>{
      'description': interface_.description ?? '',
      'enabled': interface_.enabled,
      'ip_cidr': interface_.ipAddress?.toCIDR() ?? '',
      'ipv6_cidr': interface_.ipv6Address?.toCIDR() ?? '',
    };

    if (interface_ is Switchport) {
      interfaceConfig['mode'] = interface_.mode.name;
      interfaceConfig['vlan'] = interface_.vlan;
      interfaceConfig['nativeVlan'] = interface_.nativeVlan ?? 1;
      interfaceConfig['allowedVlans'] = interface_.allowedVlans ?? 'all';
      interfaceConfig['protectedPort'] = interface_.protectedPort;

      // Port Security
      interfaceConfig['portSecurityEnabled'] = interface_.portSecurityEnabled;
      interfaceConfig['portSecurityMacAddresses'] =
          interface_.portSecurityMacAddresses?.join(',') ?? '';
      interfaceConfig['portSecuritySticky'] = interface_.portSecuritySticky;
      interfaceConfig['portSecurityViolation'] =
          interface_.portSecurityViolation.name;
      interfaceConfig['portSecurityMaximum'] = interface_.portSecurityMaximum;

      // Spanning Tree
      interfaceConfig['spanningTreePortfast'] = interface_.spanningTreePortfast;
      interfaceConfig['spanningTreeBpduGuard'] =
          interface_.spanningTreeBpduGuard;
      interfaceConfig['spanningTreeBpduFilter'] =
          interface_.spanningTreeBpduFilter;
      interfaceConfig['spanningTreeCost'] = interface_.spanningTreeCost ?? 0;
      interfaceConfig['spanningTreePortPriority'] =
          interface_.spanningTreePortPriority ?? 128;
      interfaceConfig['spanningTreeGuard'] = interface_.spanningTreeGuard.name;
    }

    _form.setId(widget.device.id, {
      'config': {
        'ports': {'${widget.interfaceIndex}': interfaceConfig},
      },
    });

    // Set additional interface indices for multi-select mode
    if (_isMultiSelect) {
      // Exclude the primary interface index since it's already handled by the form path
      final otherInterfaces = Set<int>.from(_targetInterfaceIndices)
        ..remove(widget.interfaceIndex);
      _form.additionalPortIndices = otherInterfaces;
    } else {
      _form.additionalPortIndices = null;
    }
  }

  /// Build read-only content for system-reserved ports
  Widget _buildReadOnlyContent(Port interface_) {
    return ListView(
      shrinkWrap: true,
      children: [
        const InfoBar(
          title: Text('System Reserved'),
          content: Text(
            'This port is reserved for system management and cannot be modified.',
          ),
          severity: InfoBarSeverity.warning,
          isLong: true,
        ),
        const SizedBox(height: 16),
        _buildReadOnlyField(
          'Status',
          interface_.enabled ? 'Enabled' : 'Disabled',
        ),
        if (interface_.description != null &&
            interface_.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildReadOnlyField('Description', interface_.description!),
        ],
        if (interface_ is Switchport) ...[
          const SizedBox(height: 16),
          _buildReadOnlyField('Mode', interface_.mode.name.toUpperCase()),
          if (interface_.mode == SwitchportMode.access) ...[
            const SizedBox(height: 8),
            _buildReadOnlyField('Access VLAN', interface_.vlan.toString()),
          ] else ...[
            const SizedBox(height: 8),
            _buildReadOnlyField(
              'Native VLAN',
              interface_.nativeVlan.toString(),
            ),
            const SizedBox(height: 8),
            _buildReadOnlyField(
              'Allowed VLANs',
              interface_.allowedVlans ?? 'all',
            ),
          ],
        ],
      ],
    );
  }

  /// Build a read-only field display
  Widget _buildReadOnlyField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  @override
  void dispose() {
    widget.interface_.removeListener(_handleInterfaceChange);
    _ipCidrController.removeListener(_handleIpChange);
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interface_ = widget.interface_.value;
    if (interface_ == null) {
      return const Center(child: Text('No interface selected'));
    }

    // Check if this interface is system-locked (reserved port or system subinterface)
    final realId = widget.device.realId;
    final isLocked =
        isPortReserved(interface_.name, realId: realId) ||
        (realId != null && isSystemSubinterface(realId, interface_.name));

    final hasProtectedPortCapability = widget.device.preset.capabilities
        .contains('protected-port');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      _isMultiSelect
                          ? _formatInterfaceRange()
                          : interface_.name,
                      style: FluentTheme.of(context).typography.subtitle,
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        FluentIcons.lock,
                        size: 14,
                        color: Colors.warningPrimaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'System Reserved',
                        style: FluentTheme.of(context).typography.caption
                            ?.copyWith(color: Colors.warningPrimaryColor),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(
          style: DividerTheme.of(
            context,
          ).merge(const DividerThemeData(horizontalMargin: EdgeInsets.all(0))),
        ),
        if (isLocked)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildReadOnlyContent(interface_),
            ),
          )
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: ListView(
                shrinkWrap: true,
                children: [
                  SyncedToggleSwitch(
                    label: 'Enabled',
                    controller: _enabledController,
                  ),
                  const SizedBox(height: 12),
                  const Text('Description'),
                  const SizedBox(height: 4),
                  TextBox(
                    controller: _descriptionController.controller,
                    onChanged: _descriptionController.onChanged,
                  ),
                  const SizedBox(height: 12),
                  if (interface_ is Switchport) ...[
                    Text(
                      'Switchport Configuration',
                      style: FluentTheme.of(context).typography.bodyStrong,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Mode'),
                        const SizedBox(width: 12),
                        ValueListenableBuilder<SwitchportMode>(
                          valueListenable: _modeController,
                          builder: (context, mode, _) {
                            return ComboBox<SwitchportMode>(
                              value: mode,
                              items: SwitchportMode.values
                                  .map(
                                    (m) => ComboBoxItem<SwitchportMode>(
                                      value: m,
                                      child: Text(m.name.toUpperCase()),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _modeController.onChanged,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (hasProtectedPortCapability) ...[
                      SyncedToggleSwitch(
                        label: 'Protected Port',
                        controller: _protectedPortController,
                      ),
                      const SizedBox(height: 12),
                    ],
                    ValueListenableBuilder<SwitchportMode>(
                      valueListenable: _modeController,
                      builder: (context, mode, _) {
                        return _buildModeSpecificFields(context, mode);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildPortSecuritySection(context),
                    const SizedBox(height: 20),
                    _buildSpanningTreeSection(context),
                  ] else ...[
                    Text(
                      'Routed Port Configuration',
                      style: FluentTheme.of(context).typography.bodyStrong,
                    ),
                    const SizedBox(height: 8),
                    IpAddressField(
                      controller: _ipCidrController,
                      conflictChecker: IpConflictChecker.fromDevice(
                        widget.device,
                        excludePortIndex: widget.interfaceIndex,
                      ),
                    ),
                    if (interface_.ipAddress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'CIDR: ${interface_.ipAddress!.toCIDR()}',
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Ipv6AddressField(controller: _ipv6CidrController),
                    if (interface_.ipv6Address != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'IPv6: ${interface_.ipv6Address!.toCIDR()}',
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                    // NAT Role section (only for NAT-capable devices)
                    if (widget.device.preset.capabilities.contains('nat')) ...[
                      const SizedBox(height: 20),
                      _buildNatRoleSection(context),
                    ],
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNatRoleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NAT Configuration',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('NAT Role'),
            const SizedBox(width: 12),
            ValueListenableBuilder<NatInterfaceRole>(
              valueListenable: _natRoleController,
              builder: (context, role, _) {
                return ComboBox<NatInterfaceRole>(
                  value: role,
                  items: NatInterfaceRole.values
                      .map(
                        (r) => ComboBoxItem<NatInterfaceRole>(
                          value: r,
                          child: Text(_formatNatRole(r)),
                        ),
                      )
                      .toList(),
                  onChanged: _natRoleController.onChanged,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _getNatRoleDescription(_natRoleController.value),
          style: FluentTheme.of(context).typography.caption,
        ),
      ],
    );
  }

  String _formatNatRole(NatInterfaceRole role) {
    switch (role) {
      case NatInterfaceRole.none:
        return 'None';
      case NatInterfaceRole.inside:
        return 'Inside (ip nat inside)';
      case NatInterfaceRole.outside:
        return 'Outside (ip nat outside)';
    }
  }

  String _getNatRoleDescription(NatInterfaceRole role) {
    switch (role) {
      case NatInterfaceRole.none:
        return 'No NAT role assigned to this interface';
      case NatInterfaceRole.inside:
        return 'Interface connects to internal/private network';
      case NatInterfaceRole.outside:
        return 'Interface connects to external/public network';
    }
  }

  Widget _buildModeSpecificFields(BuildContext context, SwitchportMode mode) {
    final vlans = widget.device.vlans;

    switch (mode) {
      case SwitchportMode.access:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Access VLAN'),
            const SizedBox(height: 4),
            ValueListenableBuilder<int>(
              valueListenable: _vlanController,
              builder: (context, vlanId, _) {
                return ComboBox<int>(
                  value: vlanId,
                  items: vlans
                      .map(
                        (v) => ComboBoxItem<int>(
                          value: v.vlanId,
                          child: _buildVlanItem(v),
                        ),
                      )
                      .toList(),
                  onChanged: _vlanController.onChanged,
                );
              },
            ),
          ],
        );
      case SwitchportMode.trunk:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Native VLAN'),
            const SizedBox(height: 4),
            ValueListenableBuilder<int>(
              valueListenable: _nativeVlanController,
              builder: (context, vlanId, _) {
                return ComboBox<int>(
                  value: vlanId,
                  items: vlans
                      .map(
                        (v) => ComboBoxItem<int>(
                          value: v.vlanId,
                          child: _buildVlanItem(v),
                        ),
                      )
                      .toList(),
                  onChanged: _nativeVlanController.onChanged,
                );
              },
            ),
            const SizedBox(height: 12),
            const Text('Allowed VLANs'),
            const SizedBox(height: 4),
            ValueListenableBuilder<Set<int>>(
              valueListenable: _allowedVlansController,
              builder: (context, selectedVlans, _) {
                return VlanMultiSelect(
                  vlans: vlans,
                  selectedVlanIds: selectedVlans,
                  onChanged: _allowedVlansController.onChanged,
                  placeholder: 'All VLANs allowed',
                );
              },
            ),
          ],
        );
    }
  }

  Widget _buildVlanItem(VlanConfig vlan) {
    final hasName = vlan.name.isNotEmpty && vlan.name != 'VLAN ${vlan.vlanId}';
    if (hasName) {
      return Text('VLAN ${vlan.vlanId} - ${vlan.name}');
    }
    return Text('VLAN ${vlan.vlanId}');
  }

  Widget _buildPortSecuritySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Port Security',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 8),
        SyncedToggleSwitch(
          label: 'Enable Port Security',
          controller: _portSecurityEnabledController,
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<bool>(
          valueListenable: _portSecurityEnabledController,
          builder: (context, enabled, _) {
            if (!enabled) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Maximum MAC Addresses'),
                    const SizedBox(width: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: _portSecurityMaximumController,
                      builder: (context, maximum, _) {
                        return ComboBox<int>(
                          value: maximum.clamp(1, 8),
                          items: List.generate(
                            8,
                            (i) => ComboBoxItem<int>(
                              value: i + 1,
                              child: Text('${i + 1}'),
                            ),
                          ),
                          onChanged: _portSecurityMaximumController.onChanged,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Violation Action'),
                    const SizedBox(width: 12),
                    ValueListenableBuilder<PortSecurityViolation>(
                      valueListenable: _portSecurityViolationController,
                      builder: (context, violation, _) {
                        return ComboBox<PortSecurityViolation>(
                          value: violation,
                          items: PortSecurityViolation.values
                              .map(
                                (v) => ComboBoxItem<PortSecurityViolation>(
                                  value: v,
                                  child: Text(_formatViolationAction(v)),
                                ),
                              )
                              .toList(),
                          onChanged: _portSecurityViolationController.onChanged,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SyncedToggleSwitch(
                  label: 'Sticky MAC Addresses',
                  controller: _portSecurityStickyController,
                ),
                const SizedBox(height: 12),
                const Text('Allowed MAC Addresses'),
                const SizedBox(height: 4),
                ValueListenableBuilder<Set<String>>(
                  valueListenable: _portSecurityMacAddressesController,
                  builder: (context, macAddresses, _) {
                    return MacAddressMultiSelect(
                      selectedMacAddresses: macAddresses,
                      onChanged: _portSecurityMacAddressesController.onChanged,
                      placeholder: 'No static MAC addresses configured',
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatViolationAction(PortSecurityViolation violation) {
    switch (violation) {
      case PortSecurityViolation.shutdown:
        return 'Shutdown (err-disable port)';
      case PortSecurityViolation.protect:
        return 'Protect (drop packets)';
      case PortSecurityViolation.restrict:
        return 'Restrict (drop + log)';
    }
  }

  Widget _buildSpanningTreeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spanning Tree',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 8),
        SyncedToggleSwitch(
          label: 'PortFast',
          controller: _spanningTreePortfastController,
        ),
        const SizedBox(height: 12),
        SyncedToggleSwitch(
          label: 'BPDU Guard',
          controller: _spanningTreeBpduGuardController,
        ),
        const SizedBox(height: 12),
        SyncedToggleSwitch(
          label: 'BPDU Filter',
          controller: _spanningTreeBpduFilterController,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Guard'),
            const SizedBox(width: 12),
            ValueListenableBuilder<SpanningTreeGuard>(
              valueListenable: _spanningTreeGuardController,
              builder: (context, guard, _) {
                return ComboBox<SpanningTreeGuard>(
                  value: guard,
                  items: SpanningTreeGuard.values
                      .map(
                        (g) => ComboBoxItem<SpanningTreeGuard>(
                          value: g,
                          child: Text(_formatGuardOption(g)),
                        ),
                      )
                      .toList(),
                  onChanged: _spanningTreeGuardController.onChanged,
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Cost'),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: NumberBox<int>(
                value: _spanningTreeCostController.value,
                min: 0,
                max: 200000000,
                onChanged: (value) {
                  if (value != null) {
                    _spanningTreeCostController.onChanged(value);
                  }
                },
                mode: SpinButtonPlacementMode.none,
                placeholder: 'Auto',
              ),
            ),
            const SizedBox(width: 8),
            const Text('(0 = auto)', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Port Priority'),
            const SizedBox(width: 12),
            ValueListenableBuilder<int>(
              valueListenable: _spanningTreePortPriorityController,
              builder: (context, priority, _) {
                // STP port priority must be in increments of 16, from 0 to 240
                return ComboBox<int>(
                  value: (priority ~/ 16) * 16,
                  items: List.generate(
                    16,
                    (i) => ComboBoxItem<int>(
                      value: i * 16,
                      child: Text('${i * 16}'),
                    ),
                  ),
                  onChanged: _spanningTreePortPriorityController.onChanged,
                );
              },
            ),
            const SizedBox(width: 8),
            const Text('(default: 128)', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _formatGuardOption(SpanningTreeGuard guard) {
    switch (guard) {
      case SpanningTreeGuard.none:
        return 'None';
      case SpanningTreeGuard.root:
        return 'Root Guard';
      case SpanningTreeGuard.loop:
        return 'Loop Guard';
    }
  }
}
