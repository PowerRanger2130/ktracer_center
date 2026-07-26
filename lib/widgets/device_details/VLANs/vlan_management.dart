import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/ipv4_utils.dart';
import 'package:ktracer_center/utils/ip_change_relay.dart';
import 'package:ktracer_center/utils/synced_controller.dart';
import 'package:ktracer_center/widgets/device_details/synced_toggle_switch.dart';
import 'package:ktracer_center/widgets/ip_address_field.dart';
import 'package:ktracer_center/widgets/ipv6_address_field.dart';

class VlanManagement extends StatefulWidget {
  const VlanManagement({
    super.key,
    required this.vlan,
    required this.device,
    required this.vlanIndex,
    this.onDelete,
    this.isReadOnly = false,
  });

  final ValueNotifier<VlanConfig?> vlan;
  final NetDevice device;
  final int vlanIndex;
  final VoidCallback? onDelete;
  final bool isReadOnly;

  @override
  State<VlanManagement> createState() => _VlanManagementState();
}

class _VlanManagementState extends State<VlanManagement> {
  late RealtimeForm _form;
  late SyncedController<String> _nameController;
  late SyncedController<String> _descriptionController;
  late SyncedController<bool> _enabledController;
  late SyncedController<String> _ipCidrController;
  late SyncedController<String> _ipv6CidrController;

  // IP change relay tracking
  String? _previousIpCidr;

  @override
  void initState() {
    super.initState();
    _form = RealtimeForm(tableName: 'net_devices');

    _nameController = _form.addField('config.vlans.${widget.vlanIndex}.name');
    _descriptionController = _form.addField(
      'config.vlans.${widget.vlanIndex}.description',
    );
    _enabledController = _form.addBoolField(
      'config.vlans.${widget.vlanIndex}.enabled',
    );
    _ipCidrController = _form.addField(
      'config.vlans.${widget.vlanIndex}.ip_cidr',
    );
    _ipv6CidrController = _form.addField(
      'config.vlans.${widget.vlanIndex}.ipv6_cidr',
    );

    widget.vlan.addListener(_handleVlanChange);
    _handleVlanChange();

    // Listen for IP changes to trigger relay
    _ipCidrController.addListener(_handleIpChange);
  }

  /// Handle IP address changes and relay to dependent DHCP pools
  Future<void> _handleIpChange() async {
    final newIpCidr = _ipCidrController.value;
    final vlan = widget.vlan.value;
    if (vlan == null) return;

    // Skip if no actual change
    if (newIpCidr == _previousIpCidr) return;

    final oldIpCidr = _previousIpCidr;
    _previousIpCidr = newIpCidr;

    // Check if this VLAN has any DHCP pools
    if (!widget.device.hasAffectedDhcpPools(vlanId: vlan.vlanId)) {
      return;
    }

    // Build the change object
    final change = IpAddressChange(
      oldAddress: oldIpCidr != null && oldIpCidr.isNotEmpty
          ? IPv4.tryParse(oldIpCidr)
          : null,
      newAddress: newIpCidr.isNotEmpty ? IPv4.tryParse(newIpCidr) : null,
      source: InterfaceChangeSource.vlan,
      vlanId: vlan.vlanId,
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

  @override
  void didUpdateWidget(VlanManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vlan != oldWidget.vlan ||
        widget.vlanIndex != oldWidget.vlanIndex) {
      oldWidget.vlan.removeListener(_handleVlanChange);
      _ipCidrController.removeListener(_handleIpChange);

      // Rebuild form fields with new index
      _form.dispose();
      _form = RealtimeForm(tableName: 'net_devices');
      _nameController = _form.addField('config.vlans.${widget.vlanIndex}.name');
      _descriptionController = _form.addField(
        'config.vlans.${widget.vlanIndex}.description',
      );
      _enabledController = _form.addBoolField(
        'config.vlans.${widget.vlanIndex}.enabled',
      );
      _ipCidrController = _form.addField(
        'config.vlans.${widget.vlanIndex}.ip_cidr',
      );
      _ipv6CidrController = _form.addField(
        'config.vlans.${widget.vlanIndex}.ipv6_cidr',
      );

      // Reset previous IP for new VLAN
      _previousIpCidr = null;

      widget.vlan.addListener(_handleVlanChange);
      _handleVlanChange();

      _ipCidrController.addListener(_handleIpChange);
    }
  }

  void _handleVlanChange() {
    final vlan = widget.vlan.value;
    if (vlan == null) return;

    // Initialize previous IP for relay tracking
    _previousIpCidr ??= vlan.ipAddress?.toCIDR() ?? '';

    _form.setId(widget.device.id, {
      'config': {
        'vlans': {
          '${widget.vlanIndex}': {
            'name': vlan.name,
            'description': vlan.description ?? '',
            'enabled': vlan.enabled,
            'ip_cidr': vlan.ipAddress?.toCIDR() ?? '',
            'ipv6_cidr': vlan.ipv6Address?.toCIDR() ?? '',
          },
        },
      },
    });
  }

  /// Build read-only content for system-reserved VLANs
  Widget _buildReadOnlyContent(VlanConfig vlan) {
    return ListView(
      shrinkWrap: true,
      children: [
        const InfoBar(
          title: Text('System Reserved'),
          content: Text(
            'This VLAN is reserved for system management and cannot be modified.',
          ),
          severity: InfoBarSeverity.warning,
          isLong: true,
        ),
        const SizedBox(height: 16),
        _buildReadOnlyField('Name', vlan.name),
        const SizedBox(height: 12),
        _buildReadOnlyField('Status', vlan.enabled ? 'Enabled' : 'Disabled'),
        if (vlan.description != null && vlan.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildReadOnlyField('Description', vlan.description!),
        ],
        if (vlan.ipAddress != null) ...[
          const SizedBox(height: 16),
          _buildReadOnlyField('IP Address', vlan.ipAddress!.address),
          const SizedBox(height: 8),
          _buildReadOnlyField('Subnet Mask', vlan.ipAddress!.subnetMask),
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
          width: 100,
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
    widget.vlan.removeListener(_handleVlanChange);
    _ipCidrController.removeListener(_handleIpChange);
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vlan = widget.vlan.value;
    if (vlan == null) {
      return const Center(child: Text('No VLAN selected'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                'VLAN ${vlan.vlanId}',
                style: FluentTheme.of(context).typography.subtitle,
              ),
              if (widget.isReadOnly) ...[
                const SizedBox(width: 8),
                const Icon(
                  FluentIcons.lock,
                  size: 14,
                  color: Colors.warningPrimaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'System Reserved',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: Colors.warningPrimaryColor,
                  ),
                ),
              ],
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
                        title: const Text('Delete VLAN'),
                        content: Text(
                          'Are you sure you want to delete VLAN ${vlan.vlanId} (${vlan.name})?',
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
            child: widget.isReadOnly
                ? _buildReadOnlyContent(vlan)
                : ListView(
                    shrinkWrap: true,
                    children: [
                      const Text('Name'),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 300,
                        child: TextBox(
                          controller: _nameController.controller,
                          onChanged: _nameController.onChanged,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 16),
                      Text(
                        'Layer 3 Configuration (SVI)',
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                      const SizedBox(height: 8),
                      IpAddressField(
                        controller: _ipCidrController,
                        conflictChecker: IpConflictChecker.fromDevice(
                          widget.device,
                          excludeVlanId: vlan.vlanId,
                        ),
                      ),
                      if (vlan.ipAddress != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Address: ${vlan.ipAddress!.address}  •  Mask: ${vlan.ipAddress!.subnetMask}',
                          style: FluentTheme.of(context).typography.caption,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Ipv6AddressField(controller: _ipv6CidrController),
                      if (vlan.ipv6Address != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'IPv6: ${vlan.ipv6Address!.toCIDR()}',
                          style: FluentTheme.of(context).typography.caption,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
