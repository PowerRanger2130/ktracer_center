import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/interface_descriptor.dart';
import 'package:ktracer_center/models/net_device.dart';

/// Display mode for the interface selector
enum InterfaceSelectorMode {
  /// ComboBox dropdown
  comboBox,

  /// ListTile list
  list,

  /// Compact chips
  chips,
}

/// A reusable widget for selecting network interfaces
/// Supports multiple display modes and filtering options
class InterfaceSelector extends StatelessWidget {
  /// The device to get interfaces from
  final NetDevice device;

  /// Currently selected interface key (e.g., "vlan:10" or "port:0")
  final String? selectedKey;

  /// Callback when selection changes
  final void Function(InterfaceDescriptor? interface_)? onChanged;

  /// Filter to apply to interfaces
  final InterfaceFilter filter;

  /// Display mode
  final InterfaceSelectorMode mode;

  /// Placeholder text when nothing is selected
  final String placeholder;

  /// Whether to show the IP address in the display
  final bool showIpAddress;

  /// Whether to show the interface icon
  final bool showIcon;

  /// Whether the selector is enabled
  final bool enabled;

  /// Whether to expand to fill available width (for comboBox mode)
  final bool isExpanded;

  /// Custom item builder (optional)
  final Widget Function(BuildContext, InterfaceDescriptor)? itemBuilder;

  /// Empty state message when no interfaces match filter
  final String emptyMessage;

  /// Whether to include tunnel interfaces
  final bool includeTunnels;

  const InterfaceSelector({
    super.key,
    required this.device,
    this.selectedKey,
    this.onChanged,
    this.filter = const InterfaceFilter(),
    this.mode = InterfaceSelectorMode.comboBox,
    this.placeholder = 'Select an interface',
    this.showIpAddress = true,
    this.showIcon = true,
    this.enabled = true,
    this.isExpanded = true,
    this.itemBuilder,
    this.emptyMessage = 'No interfaces available',
    this.includeTunnels = false,
  });

  /// Create a selector for interfaces with IP addresses (for DHCP, routing, etc.)
  factory InterfaceSelector.withIpAddress({
    Key? key,
    required NetDevice device,
    String? selectedKey,
    void Function(InterfaceDescriptor?)? onChanged,
    InterfaceSelectorMode mode = InterfaceSelectorMode.comboBox,
    String placeholder = 'Select an interface',
    bool enabled = true,
  }) {
    return InterfaceSelector(
      key: key,
      device: device,
      selectedKey: selectedKey,
      onChanged: onChanged,
      filter: InterfaceFilter.withIpAddress,
      mode: mode,
      placeholder: placeholder,
      enabled: enabled,
    );
  }

  /// Create a selector for Layer 3 interfaces
  factory InterfaceSelector.layer3({
    Key? key,
    required NetDevice device,
    String? selectedKey,
    void Function(InterfaceDescriptor?)? onChanged,
    InterfaceSelectorMode mode = InterfaceSelectorMode.comboBox,
    String placeholder = 'Select an interface',
    bool enabled = true,
    bool requireIpAddress = false,
    bool includeTunnels = false,
    Set<String>? excludeKeys,
  }) {
    return InterfaceSelector(
      key: key,
      device: device,
      selectedKey: selectedKey,
      onChanged: onChanged,
      filter: InterfaceFilter(
        onlyLayer3: true,
        requireIpAddress: requireIpAddress,
        excludeKeys: excludeKeys,
      ),
      mode: mode,
      placeholder: placeholder,
      enabled: enabled,
      includeTunnels: includeTunnels,
    );
  }

  /// Create a selector for physical ports only
  factory InterfaceSelector.physicalPorts({
    Key? key,
    required NetDevice device,
    String? selectedKey,
    void Function(InterfaceDescriptor?)? onChanged,
    InterfaceSelectorMode mode = InterfaceSelectorMode.comboBox,
    String placeholder = 'Select a port',
    bool enabled = true,
  }) {
    return InterfaceSelector(
      key: key,
      device: device,
      selectedKey: selectedKey,
      onChanged: onChanged,
      filter: InterfaceFilter.physicalPortsOnly,
      mode: mode,
      placeholder: placeholder,
      enabled: enabled,
    );
  }

  /// Create a selector for VLANs only
  factory InterfaceSelector.vlans({
    Key? key,
    required NetDevice device,
    String? selectedKey,
    void Function(InterfaceDescriptor?)? onChanged,
    InterfaceSelectorMode mode = InterfaceSelectorMode.comboBox,
    String placeholder = 'Select a VLAN',
    bool enabled = true,
  }) {
    return InterfaceSelector(
      key: key,
      device: device,
      selectedKey: selectedKey,
      onChanged: onChanged,
      filter: InterfaceFilter.vlansOnly,
      mode: mode,
      placeholder: placeholder,
      enabled: enabled,
    );
  }

  List<InterfaceDescriptor> _getFilteredInterfaces() {
    final allInterfaces = InterfaceDescriptor.fromDevice(
      device,
      includeTunnels: includeTunnels,
    );
    return filter.apply(allInterfaces);
  }

  InterfaceDescriptor? _findByKey(
    String? key,
    List<InterfaceDescriptor> interfaces,
  ) {
    if (key == null) return null;
    return interfaces.where((i) => i.key == key).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final interfaces = _getFilteredInterfaces();

    if (interfaces.isEmpty) {
      return _buildEmptyState(context);
    }

    switch (mode) {
      case InterfaceSelectorMode.comboBox:
        return _buildComboBox(context, interfaces);
      case InterfaceSelectorMode.list:
        return _buildList(context, interfaces);
      case InterfaceSelectorMode.chips:
        return _buildChips(context, interfaces);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return InfoBar(
      title: Text(emptyMessage),
      severity: InfoBarSeverity.warning,
    );
  }

  Widget _buildComboBox(
    BuildContext context,
    List<InterfaceDescriptor> interfaces,
  ) {
    return ComboBox<String>(
      value: selectedKey,
      placeholder: Text(placeholder),
      isExpanded: isExpanded,
      popupColor: FluentTheme.of(context).menuColor,
      items: interfaces.map((iface) {
        return ComboBoxItem<String>(
          value: iface.key,
          child: itemBuilder != null
              ? itemBuilder!(context, iface)
              : _buildDefaultItem(context, iface),
        );
      }).toList(),
      onChanged: enabled
          ? (key) {
              final selected = _findByKey(key, interfaces);
              onChanged?.call(selected);
            }
          : null,
    );
  }

  Widget _buildList(
    BuildContext context,
    List<InterfaceDescriptor> interfaces,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: interfaces.length,
      itemBuilder: (context, index) {
        final iface = interfaces[index];
        final isSelected = iface.key == selectedKey;
        final subtitle =
            iface.ipAddress?.toCIDR() ??
            (iface.usesDhcpForIpv4 ? 'DHCP' : null);

        return ListTile.selectable(
          title: Text(iface.displayName),
          subtitle: showIpAddress && subtitle != null ? Text(subtitle) : null,
          leading: showIcon ? Icon(iface.icon, size: 16) : null,
          selected: isSelected,
          onPressed: enabled
              ? () {
                  onChanged?.call(isSelected ? null : iface);
                }
              : null,
        );
      },
    );
  }

  Widget _buildChips(
    BuildContext context,
    List<InterfaceDescriptor> interfaces,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: interfaces.map((iface) {
        final isSelected = iface.key == selectedKey;
        final compactAddress =
            iface.networkCidr ?? (iface.usesDhcpForIpv4 ? 'DHCP' : null);
        return ToggleButton(
          checked: isSelected,
          onChanged: enabled
              ? (checked) {
                  onChanged?.call(checked ? iface : null);
                }
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(iface.icon, size: 14),
                const SizedBox(width: 4),
              ],
              Text(iface.shortName),
              if (showIpAddress && compactAddress != null) ...[
                const SizedBox(width: 4),
                Text(
                  '($compactAddress)',
                  style: FluentTheme.of(context).typography.caption,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDefaultItem(BuildContext context, InterfaceDescriptor iface) {
    final compactAddress =
        iface.networkCidr ?? (iface.usesDhcpForIpv4 ? 'DHCP' : null);
    return Row(
      children: [
        if (showIcon) ...[Icon(iface.icon, size: 16), const SizedBox(width: 8)],
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(iface.displayName),
              if (showIpAddress && compactAddress != null)
                Text(
                  compactAddress,
                  style: FluentTheme.of(
                    context,
                  ).typography.caption?.copyWith(color: Colors.grey[100]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A multi-select version of the interface selector
class InterfaceMultiSelector extends StatelessWidget {
  /// The device to get interfaces from
  final NetDevice device;

  /// Currently selected interface keys
  final Set<String> selectedKeys;

  /// Callback when selection changes
  final void Function(Set<String> keys)? onChanged;

  /// Filter to apply to interfaces
  final InterfaceFilter filter;

  /// Display mode
  final InterfaceSelectorMode mode;

  /// Whether the selector is enabled
  final bool enabled;

  /// Whether to show the IP address in the display
  final bool showIpAddress;

  /// Whether to show the interface icon
  final bool showIcon;

  /// Empty state message when no interfaces match filter
  final String emptyMessage;

  const InterfaceMultiSelector({
    super.key,
    required this.device,
    required this.selectedKeys,
    this.onChanged,
    this.filter = const InterfaceFilter(),
    this.mode = InterfaceSelectorMode.chips,
    this.enabled = true,
    this.showIpAddress = false,
    this.showIcon = true,
    this.emptyMessage = 'No interfaces available',
  });

  List<InterfaceDescriptor> _getFilteredInterfaces() {
    final allInterfaces = InterfaceDescriptor.fromDevice(device);
    return filter.apply(allInterfaces);
  }

  void _toggleSelection(InterfaceDescriptor iface) {
    if (onChanged == null) return;

    final newKeys = Set<String>.from(selectedKeys);
    if (newKeys.contains(iface.key)) {
      newKeys.remove(iface.key);
    } else {
      newKeys.add(iface.key);
    }
    onChanged!(newKeys);
  }

  @override
  Widget build(BuildContext context) {
    final interfaces = _getFilteredInterfaces();

    if (interfaces.isEmpty) {
      return InfoBar(
        title: Text(emptyMessage),
        severity: InfoBarSeverity.warning,
      );
    }

    switch (mode) {
      case InterfaceSelectorMode.chips:
        return _buildChips(context, interfaces);
      case InterfaceSelectorMode.list:
        return _buildList(context, interfaces);
      case InterfaceSelectorMode.comboBox:
        // Multi-select doesn't support comboBox, fall back to chips
        return _buildChips(context, interfaces);
    }
  }

  Widget _buildChips(
    BuildContext context,
    List<InterfaceDescriptor> interfaces,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: interfaces.map((iface) {
        final isSelected = selectedKeys.contains(iface.key);
        final compactAddress =
            iface.networkCidr ?? (iface.usesDhcpForIpv4 ? 'DHCP' : null);
        return ToggleButton(
          checked: isSelected,
          onChanged: enabled ? (_) => _toggleSelection(iface) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon) ...[
                Icon(iface.icon, size: 14),
                const SizedBox(width: 4),
              ],
              Text(iface.shortName),
              if (showIpAddress && compactAddress != null) ...[
                const SizedBox(width: 4),
                Text(
                  '($compactAddress)',
                  style: FluentTheme.of(context).typography.caption,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<InterfaceDescriptor> interfaces,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: interfaces.length,
      itemBuilder: (context, index) {
        final iface = interfaces[index];
        final isSelected = selectedKeys.contains(iface.key);
        final subtitle =
            iface.ipAddress?.toCIDR() ??
            (iface.usesDhcpForIpv4 ? 'DHCP' : null);

        return Checkbox(
          checked: isSelected,
          onChanged: enabled ? (_) => _toggleSelection(iface) : null,
          content: Row(
            children: [
              if (showIcon) ...[
                Icon(iface.icon, size: 16),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(iface.displayName),
                    if (showIpAddress && subtitle != null)
                      Text(
                        subtitle,
                        style: FluentTheme.of(context).typography.caption,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Simple interface display widget (read-only)
class InterfaceDisplay extends StatelessWidget {
  final InterfaceDescriptor interface_;
  final bool showIcon;
  final bool showIpAddress;
  final bool compact;

  const InterfaceDisplay({
    super.key,
    required this.interface_,
    this.showIcon = true,
    this.showIpAddress = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle =
        interface_.ipAddress?.toCIDR() ??
        (interface_.usesDhcpForIpv4 ? 'DHCP' : null);

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(interface_.icon, size: 14),
            const SizedBox(width: 4),
          ],
          Text(interface_.shortName),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          Icon(interface_.icon, size: 16),
          const SizedBox(width: 8),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(interface_.displayName),
            if (showIpAddress && subtitle != null)
              Text(subtitle, style: FluentTheme.of(context).typography.caption),
          ],
        ),
      ],
    );
  }
}
