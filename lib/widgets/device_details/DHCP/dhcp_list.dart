import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/widgets/device_details/DHCP/dhcp_pool_management.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

/// Simple helper to hold interface info for pool creation
class _InterfaceOption {
  final int? interfaceIndex;
  final int? vlanId;
  final String name;
  final IPv4 ipAddress;

  _InterfaceOption({
    this.interfaceIndex,
    this.vlanId,
    required this.name,
    required this.ipAddress,
  });

  String get displayName => name;

  bool get isVlan => vlanId != null;

  String get networkCidr {
    // Calculate network address
    final parts = ipAddress.address.split('.');
    final maskParts = ipAddress.subnetMask.split('.');
    final networkParts = <String>[];
    for (int i = 0; i < 4; i++) {
      networkParts.add(
        (int.parse(parts[i]) & int.parse(maskParts[i])).toString(),
      );
    }
    return '${networkParts.join('.')}/${IPv4.subnetMaskToPrefixLength(ipAddress.subnetMask)}';
  }

  String get network {
    final parts = ipAddress.address.split('.');
    final maskParts = ipAddress.subnetMask.split('.');
    final networkParts = <String>[];
    for (int i = 0; i < 4; i++) {
      networkParts.add(
        (int.parse(parts[i]) & int.parse(maskParts[i])).toString(),
      );
    }
    return networkParts.join('.');
  }
}

class DhcpList extends StatefulWidget {
  const DhcpList({required this.device, super.key});
  final NetDevice device;

  @override
  State<DhcpList> createState() => _DhcpListState();
}

class _DhcpListState extends State<DhcpList> {
  final ValueNotifier<DhcpPoolConfig?> _selectedPool = ValueNotifier(null);
  int _selectedPoolIndex = -1;

  final _poolNameController = TextEditingController();
  _InterfaceOption? _selectedInterfaceForAdd;

  @override
  void didUpdateWidget(DhcpList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.id != oldWidget.device.id) {
      _selectedPool.value = null;
      _selectedPoolIndex = -1;
    }
  }

  @override
  void dispose() {
    _selectedPool.dispose();
    _poolNameController.dispose();
    super.dispose();
  }

  List<_InterfaceOption> _getAvailableInterfaces() {
    final options = <_InterfaceOption>[];

    // Add physical ports with IP addresses
    final interfaces = widget.device.interfaces;
    for (int i = 0; i < interfaces.length; i++) {
      final port = interfaces[i];
      if (port.ipAddress != null) {
        options.add(
          _InterfaceOption(
            interfaceIndex: i,
            name: port.name,
            ipAddress: port.ipAddress!,
          ),
        );
      }
    }

    // Add VLANs with IP addresses (SVIs)
    for (final vlan in widget.device.vlans) {
      if (vlan.ipAddress != null) {
        options.add(
          _InterfaceOption(
            vlanId: vlan.vlanId,
            name:
                'VLAN ${vlan.vlanId}${vlan.name.isNotEmpty ? ' (${vlan.name})' : ''}',
            ipAddress: vlan.ipAddress!,
          ),
        );
      }
    }
    return options;
  }

  Future<void> _addPool(String name, _InterfaceOption iface) async {
    final pools = widget.device.dhcpPools;

    // Check if pool name already exists
    if (pools.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
      return;
    }

    final newPool = DhcpPoolConfig(
      name: name,
      interfaceIndex: iface.interfaceIndex,
      vlanId: iface.vlanId,
      network: iface.network,
      subnetMask: iface.ipAddress.subnetMask,
      defaultRouter: iface.ipAddress.address, // Default to interface IP
    );
    final updatedPools = [...pools, newPool];

    await Database.updateDeviceConfig(widget.device.id, {
      'dhcp_pools': updatedPools.map((p) => p.toJson()).toList(),
    });
  }

  Future<void> _deletePool(int index) async {
    final pools = widget.device.dhcpPools;
    final updatedPools = [...pools]..removeAt(index);

    await Database.updateDeviceConfig(widget.device.id, {
      'dhcp_pools': updatedPools.map((p) => p.toJson()).toList(),
    });

    _selectedPool.value = null;
    _selectedPoolIndex = -1;
    setState(() {});
  }

  void _showAddPoolDialog() {
    _poolNameController.clear();
    _selectedInterfaceForAdd = null;
    final availableInterfaces = _getAvailableInterfaces();

    if (availableInterfaces.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Cannot Add DHCP Pool'),
          content: const Text(
            'No interfaces with IP addresses are configured.\n\n'
            'Please configure an IP address on a port or VLAN first before creating a DHCP pool.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add DHCP Pool'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pool Name'),
              const SizedBox(height: 4),
              SizedBox(
                child: TextBox(
                  controller: _poolNameController,
                  placeholder: 'e.g., VLAN10_POOL',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Network Interface'),
              const SizedBox(height: 4),
              SizedBox(
                child: ComboBox<String>(
                  value: _selectedInterfaceForAdd != null
                      ? (_selectedInterfaceForAdd!.vlanId != null
                            ? 'vlan:${_selectedInterfaceForAdd!.vlanId}'
                            : 'port:${_selectedInterfaceForAdd!.interfaceIndex}')
                      : null,
                  placeholder: const Text('Select an interface'),
                  isExpanded: true,
                  popupColor: FluentTheme.of(context).menuColor,
                  items: availableInterfaces.map((iface) {
                    final key = iface.vlanId != null
                        ? 'vlan:${iface.vlanId}'
                        : 'port:${iface.interfaceIndex}';
                    return ComboBoxItem<String>(
                      value: key,
                      child: Row(
                        children: [
                          Icon(
                            iface.isVlan
                                ? FluentIcons.virtual_network
                                : FluentIcons.plug_solid,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(iface.displayName),
                                Text(
                                  iface.networkCidr,
                                  style: FluentTheme.of(context)
                                      .typography
                                      .caption
                                      ?.copyWith(color: Colors.grey[100]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (key) {
                    if (key != null) {
                      setDialogState(() {
                        if (key.startsWith('vlan:')) {
                          final vlanId = int.parse(key.substring(5));
                          _selectedInterfaceForAdd = availableInterfaces
                              .firstWhere((i) => i.vlanId == vlanId);
                        } else {
                          final portIndex = int.parse(key.substring(5));
                          _selectedInterfaceForAdd = availableInterfaces
                              .firstWhere((i) => i.interfaceIndex == portIndex);
                        }
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _selectedInterfaceForAdd == null
                  ? null
                  : () {
                      final name = _poolNameController.text.trim();
                      if (name.isNotEmpty && _selectedInterfaceForAdd != null) {
                        _addPool(name, _selectedInterfaceForAdd!);
                        Navigator.of(context).pop();
                      }
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoolItem(DhcpPoolConfig pool, int index) =>
      ValueListenableBuilder(
        valueListenable: _selectedPool,
        builder: (context, value, _) => ListTile.selectable(
          title: Text(pool.name),
          subtitle: Text('${pool.network}/${_maskToCidr(pool.subnetMask)}'),
          selected: _selectedPoolIndex == index,
          trailing: pool.enabled
              ? const Icon(
                  FluentIcons.circle_fill,
                  size: 8,
                  color: Colors.successPrimaryColor,
                )
              : const Icon(FluentIcons.circle_ring, size: 8),
          onPressed: () {
            if (_selectedPoolIndex == index) {
              _selectedPool.value = null;
              _selectedPoolIndex = -1;
            } else {
              _selectedPool.value = pool;
              _selectedPoolIndex = index;
            }
            setState(() {});
          },
        ),
      );

  int _maskToCidr(String mask) {
    try {
      final parts = mask.split('.').map(int.parse).toList();
      int maskInt = 0;
      for (int i = 0; i < 4; i++) {
        maskInt = (maskInt << 8) | parts[i];
      }
      int count = 0;
      while (maskInt != 0) {
        count += maskInt & 1;
        maskInt >>= 1;
      }
      return count;
    } catch (_) {
      return 24;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pools = widget.device.dhcpPools;

    return FluentWidgets.mica(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    'DHCP Pools',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const Spacer(),
                  Button(
                    onPressed: _showAddPoolDialog,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('Add Pool'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    child: pools.isEmpty
                        ? const Center(child: Text('No DHCP pools configured'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: pools.length,
                            itemBuilder: (context, index) =>
                                _buildPoolItem(pools[index], index),
                          ),
                  ),
                  Expanded(
                    child: FluentWidgets.mica(
                      child: ValueListenableBuilder(
                        valueListenable: _selectedPool,
                        builder: (context, value, _) => value == null
                            ? const Center(child: Text('No pool selected'))
                            : DhcpPoolManagement(
                                pool: _selectedPool,
                                device: widget.device,
                                poolIndex: _selectedPoolIndex,
                                onDelete: () => _deletePool(_selectedPoolIndex),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
