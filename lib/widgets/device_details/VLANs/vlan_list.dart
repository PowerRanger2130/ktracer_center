import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/devices/system_constraints.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/VLANs/vlan_management.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class VlanList extends StatefulWidget {
  const VlanList({super.key, required this.device});
  final NetDevice device;

  @override
  State<VlanList> createState() => _VlanListState();
}

class _VlanListState extends State<VlanList> {
  final ValueNotifier<VlanConfig?> _selectedVlan = ValueNotifier(null);
  int _selectedVlanIndex = -1;

  final _vlanIdController = TextEditingController();
  final _vlanNameController = TextEditingController();

  @override
  void didUpdateWidget(VlanList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.id != oldWidget.device.id) {
      _selectedVlan.value = null;
      _selectedVlanIndex = -1;
    }
  }

  @override
  void dispose() {
    _selectedVlan.dispose();
    _vlanIdController.dispose();
    _vlanNameController.dispose();
    super.dispose();
  }

  Future<void> _addVlan(int vlanId, String name) async {
    final vlans = widget.device.vlans;

    // Check if VLAN ID already exists
    if (vlans.any((v) => v.vlanId == vlanId)) {
      return;
    }

    final newVlan = VlanConfig(vlanId: vlanId, name: name);
    final updatedVlans = [...vlans, newVlan];

    // Sort by VLAN ID
    updatedVlans.sort((a, b) => a.vlanId.compareTo(b.vlanId));

    await Database.updateDeviceConfig(widget.device.id, {
      'vlans': updatedVlans.map((v) => v.toJson()).toList(),
    });
  }

  Future<void> _deleteVlan(int index) async {
    final vlans = widget.device.vlans;

    // Don't allow deleting VLAN 1 or reserved VLANs
    if (vlans[index].vlanId == 1 || isVlanReserved(vlans[index].vlanId)) {
      return;
    }

    final updatedVlans = [...vlans]..removeAt(index);

    await Database.updateDeviceConfig(widget.device.id, {
      'vlans': updatedVlans.map((v) => v.toJson()).toList(),
    });

    _selectedVlan.value = null;
    _selectedVlanIndex = -1;
    setState(() {});
  }

  void _showAddVlanDialog() {
    _vlanIdController.clear();
    _vlanNameController.clear();

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Add VLAN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('VLAN ID'),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: NumberBox<int>(
                value: int.tryParse(_vlanIdController.text),
                onChanged: (value) {
                  _vlanIdController.text = value?.toString() ?? '';
                },
                min: 2,
                max: 4094,
                placeholder: 'Enter VLAN ID (2-4094)',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Name'),
            const SizedBox(height: 4),
            SizedBox(
              width: 300,
              child: TextBox(
                controller: _vlanNameController,
                placeholder: 'Enter VLAN name',
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
            onPressed: () {
              final vlanId = int.tryParse(_vlanIdController.text);
              final name = _vlanNameController.text.trim();

              if (vlanId != null && vlanId >= 2 && vlanId <= 4094) {
                _addVlan(vlanId, name.isEmpty ? 'VLAN $vlanId' : name);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildVlanItem(VlanConfig vlan, int index) {
    final isLocked = isVlanReserved(vlan.vlanId);

    return ValueListenableBuilder(
      valueListenable: _selectedVlan,
      builder: (context, value, _) => ListTile.selectable(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('VLAN ${vlan.vlanId}'),
            if (isLocked) ...[
              const SizedBox(width: 6),
              const Icon(
                FluentIcons.lock,
                size: 12,
                color: Colors.warningPrimaryColor,
              ),
            ],
          ],
        ),
        subtitle: Text(isLocked ? '${vlan.name} (System Reserved)' : vlan.name),
        selected: _selectedVlanIndex == index,
        onPressed: () {
          if (_selectedVlanIndex == index) {
            _selectedVlan.value = null;
            _selectedVlanIndex = -1;
          } else {
            _selectedVlan.value = vlan;
            _selectedVlanIndex = index;
          }
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vlans = widget.device.vlans;

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
                    'VLANs',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const Spacer(),
                  Button(
                    onPressed: _showAddVlanDialog,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('Add VLAN'),
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
                    child: vlans.isEmpty
                        ? const Center(child: Text('No VLANs configured'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: vlans.length,
                            itemBuilder: (context, index) =>
                                _buildVlanItem(vlans[index], index),
                          ),
                  ),
                  Expanded(
                    child: FluentWidgets.mica(
                      child: ValueListenableBuilder(
                        valueListenable: _selectedVlan,
                        builder: (context, value, _) {
                          if (value == null ||
                              _selectedVlanIndex < 0 ||
                              _selectedVlanIndex >= vlans.length) {
                            return const Center(
                              child: Text('No VLAN selected'),
                            );
                          }
                          final canDelete =
                              vlans[_selectedVlanIndex].vlanId != 1 &&
                              !isVlanReserved(vlans[_selectedVlanIndex].vlanId);
                          return VlanManagement(
                            vlan: _selectedVlan,
                            device: widget.device,
                            vlanIndex: _selectedVlanIndex,
                            onDelete: canDelete
                                ? () => _deleteVlan(_selectedVlanIndex)
                                : null,
                            isReadOnly: isVlanReserved(value.vlanId),
                          );
                        },
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
