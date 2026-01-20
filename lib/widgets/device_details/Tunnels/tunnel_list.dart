import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/Tunnels/tunnel_management.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class TunnelList extends StatefulWidget {
  const TunnelList({super.key, required this.device});
  final NetDevice device;

  @override
  State<TunnelList> createState() => _TunnelListState();
}

class _TunnelListState extends State<TunnelList> {
  final ValueNotifier<TunnelConfig?> _selectedTunnel = ValueNotifier(null);
  int _selectedTunnelIndex = -1;

  // Controllers for add tunnel dialog
  final _descriptionController = TextEditingController();
  TunnelType _selectedType = TunnelType.gre;

  @override
  void didUpdateWidget(TunnelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.id != oldWidget.device.id) {
      _selectedTunnel.value = null;
      _selectedTunnelIndex = -1;
    }
  }

  @override
  void dispose() {
    _selectedTunnel.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addTunnel(TunnelConfig tunnel) async {
    final tunnels = widget.device.tunnels;
    final updatedTunnels = [...tunnels, tunnel];

    await Database.updateDeviceConfig(widget.device.id, {
      'tunnels': updatedTunnels.map((t) => t.toJson()).toList(),
    });
  }

  Future<void> _deleteTunnel(int index) async {
    final tunnels = widget.device.tunnels;
    final updatedTunnels = [...tunnels]..removeAt(index);

    await Database.updateDeviceConfig(widget.device.id, {
      'tunnels': updatedTunnels.map((t) => t.toJson()).toList(),
    });

    _selectedTunnel.value = null;
    _selectedTunnelIndex = -1;
    setState(() {});
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

  IconData _getTunnelTypeIcon(TunnelType type) {
    switch (type) {
      case TunnelType.gre:
        return FluentIcons.relationship;
      case TunnelType.ipsec:
        return FluentIcons.shield;
      case TunnelType.greOverIpsec:
        return FluentIcons.lock;
      case TunnelType.pppoe:
        return FluentIcons.plug_connected;
    }
  }

  int _getNextTunnelNumber() {
    final tunnels = widget.device.tunnels;
    if (tunnels.isEmpty) return 0;

    final usedNumbers = tunnels.map((t) => t.tunnelNumber).toSet();
    int next = 0;
    while (usedNumbers.contains(next)) {
      next++;
    }
    return next;
  }

  void _showAddTunnelDialog() {
    _descriptionController.clear();
    _selectedType = TunnelType.gre;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add Tunnel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tunnel Type selection
              const Text('Tunnel Type'),
              const SizedBox(height: 4),
              SizedBox(
                width: 250,
                child: ComboBox<TunnelType>(
                  value: _selectedType,
                  isExpanded: true,
                  popupColor: FluentTheme.of(context).menuColor,
                  items: TunnelType.values
                      .map(
                        (t) => ComboBoxItem<TunnelType>(
                          value: t,
                          child: Row(
                            children: [
                              Icon(_getTunnelTypeIcon(t), size: 16),
                              const SizedBox(width: 8),
                              Text(_getTunnelTypeLabel(t)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => _selectedType = value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Description
              const Text('Description'),
              const SizedBox(height: 4),
              TextBox(
                controller: _descriptionController,
                placeholder: 'e.g., Site-to-Site VPN to Branch Office',
              ),
            ],
          ),
          actions: [
            Button(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              child: const Text('Add'),
              onPressed: () {
                final tunnel = TunnelConfig(
                  type: _selectedType,
                  tunnelNumber: _getNextTunnelNumber(),
                  description: _descriptionController.text,
                  // Set defaults based on type
                  encryption:
                      _selectedType == TunnelType.ipsec ||
                          _selectedType == TunnelType.greOverIpsec
                      ? IpsecEncryption.aes256
                      : null,
                  hash:
                      _selectedType == TunnelType.ipsec ||
                          _selectedType == TunnelType.greOverIpsec
                      ? IpsecHash.sha256
                      : null,
                  dhGroup:
                      _selectedType == TunnelType.ipsec ||
                          _selectedType == TunnelType.greOverIpsec
                      ? IpsecDhGroup.group14
                      : null,
                  authMethod:
                      _selectedType == TunnelType.ipsec ||
                          _selectedType == TunnelType.greOverIpsec
                      ? IpsecAuthMethod.preSharedKey
                      : null,
                  dialerPoolNumber: _selectedType == TunnelType.pppoe
                      ? 1
                      : null,
                );
                _addTunnel(tunnel);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tunnels = widget.device.tunnels;

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
                    'Tunnels',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const Spacer(),
                  Button(
                    onPressed: _showAddTunnelDialog,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('Add Tunnel'),
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
                    child: tunnels.isEmpty
                        ? const Center(child: Text('No tunnels configured'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: tunnels.length,
                            itemBuilder: (context, index) {
                              final tunnel = tunnels[index];
                              final isSelected = _selectedTunnelIndex == index;

                              return ListTile.selectable(
                                leading: Icon(
                                  _getTunnelTypeIcon(tunnel.type),
                                  size: 16,
                                  color: tunnel.enabled
                                      ? null
                                      : Colors.grey[100],
                                ),
                                title: Text(tunnel.displayName),
                                subtitle: Text(
                                  tunnel.description.isNotEmpty
                                      ? tunnel.description
                                      : _getTunnelTypeLabel(tunnel.type),
                                ),
                                trailing: tunnel.enabled
                                    ? const Icon(
                                        FluentIcons.circle_fill,
                                        size: 8,
                                        color: Colors.successPrimaryColor,
                                      )
                                    : const Icon(
                                        FluentIcons.circle_ring,
                                        size: 8,
                                      ),
                                selected: isSelected,
                                onPressed: () {
                                  if (_selectedTunnelIndex == index) {
                                    _selectedTunnel.value = null;
                                    _selectedTunnelIndex = -1;
                                  } else {
                                    _selectedTunnel.value = tunnel;
                                    _selectedTunnelIndex = index;
                                  }
                                  setState(() {});
                                },
                              );
                            },
                          ),
                  ),
                  Expanded(
                    child: FluentWidgets.mica(
                      child: ValueListenableBuilder<TunnelConfig?>(
                        valueListenable: _selectedTunnel,
                        builder: (context, tunnel, child) => tunnel == null
                            ? const Center(
                                child: Text('Select a tunnel to view details'),
                              )
                            : TunnelManagement(
                                tunnel: _selectedTunnel,
                                device: widget.device,
                                tunnelIndex: _selectedTunnelIndex,
                                onDelete: () =>
                                    _deleteTunnel(_selectedTunnelIndex),
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
