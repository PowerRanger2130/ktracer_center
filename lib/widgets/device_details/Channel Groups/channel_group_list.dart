import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/network/port.dart';
import 'package:ktracer_center/widgets/device_details/Interfaces/interface_multi_select.dart';
import 'package:ktracer_center/widgets/device_details/VLANs/vlan_multi_select.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class ChannelGroupList extends StatefulWidget {
  const ChannelGroupList({super.key, required this.device});
  final NetDevice device;

  @override
  State<ChannelGroupList> createState() => _ChannelGroupListState();
}

class _ChannelGroupListState extends State<ChannelGroupList> {
  final ValueNotifier<ChannelGroupConfig?> _selectedGroup = ValueNotifier(null);
  int _selectedGroupIndex = -1;

  @override
  void didUpdateWidget(ChannelGroupList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.id != oldWidget.device.id) {
      _selectedGroup.value = null;
      _selectedGroupIndex = -1;
    }
  }

  @override
  void dispose() {
    _selectedGroup.dispose();
    super.dispose();
  }

  /// Get the speed category of a port based on its name
  String _getPortSpeed(Port port) {
    final name = port.name.toLowerCase();
    if (name.contains('gigabit') || name.startsWith('gi')) {
      return 'gigabit';
    } else if (name.contains('fastethernet') || name.startsWith('fa')) {
      return 'fast';
    } else if (name.contains('tengigabit') || name.startsWith('te')) {
      return 'tengig';
    }
    return 'unknown';
  }

  /// Get all port indices that are already in a channel group
  Set<int> _getAssignedPortIndices() {
    final assigned = <int>{};
    for (final group in widget.device.channelGroups) {
      assigned.addAll(group.portIndices);
    }
    return assigned;
  }

  /// Get available ports for a channel group (same speed, not in other groups)
  List<int> _getAvailablePortIndices(ChannelGroupConfig? currentGroup) {
    final ports = widget.device.interfaces;
    final assigned = _getAssignedPortIndices();

    // If editing existing group, its ports are available
    final currentPorts = currentGroup?.portIndices.toSet() ?? <int>{};

    // Determine the required speed based on current group's ports
    String? requiredSpeed;
    if (currentGroup != null && currentGroup.portIndices.isNotEmpty) {
      requiredSpeed = _getPortSpeed(ports[currentGroup.portIndices.first]);
    }

    final available = <int>[];
    for (var i = 0; i < ports.length; i++) {
      // Skip if assigned to another group
      if (assigned.contains(i) && !currentPorts.contains(i)) continue;

      // If we have a required speed, only include matching ports
      if (requiredSpeed != null && _getPortSpeed(ports[i]) != requiredSpeed) {
        continue;
      }

      available.add(i);
    }
    return available;
  }

  Future<void> _addChannelGroup() async {
    // Find next available group number
    final existingNumbers = widget.device.channelGroups
        .map((g) => g.groupNumber)
        .toSet();
    var nextNumber = 1;
    while (existingNumbers.contains(nextNumber)) {
      nextNumber++;
    }

    final newGroup = ChannelGroupConfig(groupNumber: nextNumber);
    final updatedGroups = [...widget.device.channelGroups, newGroup];

    await Database.updateDeviceConfig(widget.device.id, {
      'channel_groups': updatedGroups.map((g) => g.toJson()).toList(),
    });
  }

  Future<void> _deleteChannelGroup(int index) async {
    final groups = widget.device.channelGroups;
    final updatedGroups = [...groups]..removeAt(index);

    await Database.updateDeviceConfig(widget.device.id, {
      'channel_groups': updatedGroups.map((g) => g.toJson()).toList(),
    });

    _selectedGroup.value = null;
    _selectedGroupIndex = -1;
    setState(() {});
  }

  Widget _buildGroupItem(ChannelGroupConfig group, int index) {
    return ValueListenableBuilder(
      valueListenable: _selectedGroup,
      builder: (context, value, _) => ListTile.selectable(
        title: Text('Port-channel ${group.groupNumber}'),
        subtitle: Text(
          '${group.portIndices.length} ports • ${group.mode.name}',
        ),
        selected: _selectedGroupIndex == index,
        onPressed: () {
          if (_selectedGroupIndex == index) {
            _selectedGroup.value = null;
            _selectedGroupIndex = -1;
          } else {
            _selectedGroup.value = group;
            _selectedGroupIndex = index;
          }
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.device.channelGroups;

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
                    'Channel Groups',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const Spacer(),
                  Button(
                    onPressed: _addChannelGroup,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('Add Group'),
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
                    child: groups.isEmpty
                        ? const Center(child: Text('No channel groups'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: groups.length,
                            itemBuilder: (context, index) =>
                                _buildGroupItem(groups[index], index),
                          ),
                  ),
                  Expanded(
                    child: FluentWidgets.mica(
                      child: ValueListenableBuilder(
                        valueListenable: _selectedGroup,
                        builder: (context, value, _) => value == null
                            ? const Center(
                                child: Text('Select a channel group'),
                              )
                            : _ChannelGroupManagement(
                                group: _selectedGroup,
                                device: widget.device,
                                groupIndex: _selectedGroupIndex,
                                getAvailablePortIndices:
                                    _getAvailablePortIndices,
                                getPortSpeed: _getPortSpeed,
                                onDelete: () =>
                                    _deleteChannelGroup(_selectedGroupIndex),
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

class _ChannelGroupManagement extends StatefulWidget {
  const _ChannelGroupManagement({
    required this.group,
    required this.device,
    required this.groupIndex,
    required this.getAvailablePortIndices,
    required this.getPortSpeed,
    required this.onDelete,
  });

  final ValueNotifier<ChannelGroupConfig?> group;
  final NetDevice device;
  final int groupIndex;
  final List<int> Function(ChannelGroupConfig?) getAvailablePortIndices;
  final String Function(Port) getPortSpeed;
  final VoidCallback onDelete;

  @override
  State<_ChannelGroupManagement> createState() =>
      _ChannelGroupManagementState();
}

class _ChannelGroupManagementState extends State<_ChannelGroupManagement> {
  late TextEditingController _nameController;
  late ChannelGroupMode _selectedMode;
  late Set<int> _selectedPorts;
  late int _nativeVlan;
  late Set<int> _allowedVlans;

  @override
  void initState() {
    super.initState();
    _initFromGroup();
    widget.group.addListener(_handleGroupChange);
  }

  void _initFromGroup() {
    final group = widget.group.value;
    _nameController = TextEditingController(text: group?.name ?? '');
    _selectedMode = group?.mode ?? ChannelGroupMode.on;
    _selectedPorts = group?.portIndices.toSet() ?? {};
    _nativeVlan = group?.nativeVlan ?? 1;
    _allowedVlans = _parseAllowedVlans(group?.allowedVlans ?? 'all');
  }

  Set<int> _parseAllowedVlans(String value) {
    if (value == 'all' || value.isEmpty) return {};
    final result = <int>{};
    for (final part in value.split(',')) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final range = trimmed.split('-');
        if (range.length == 2) {
          final start = int.tryParse(range[0].trim());
          final end = int.tryParse(range[1].trim());
          if (start != null && end != null) {
            for (var i = start; i <= end; i++) {
              result.add(i);
            }
          }
        }
      } else {
        final id = int.tryParse(trimmed);
        if (id != null) result.add(id);
      }
    }
    return result;
  }

  String _formatAllowedVlans(Set<int> vlans) {
    if (vlans.isEmpty) return 'all';
    final sorted = vlans.toList()..sort();
    return sorted.join(',');
  }

  @override
  void didUpdateWidget(_ChannelGroupManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.group != oldWidget.group ||
        widget.groupIndex != oldWidget.groupIndex) {
      oldWidget.group.removeListener(_handleGroupChange);
      _nameController.dispose();
      _initFromGroup();
      widget.group.addListener(_handleGroupChange);
    }
  }

  void _handleGroupChange() {
    final group = widget.group.value;
    if (group != null) {
      _nameController.text = group.name;
      _selectedMode = group.mode;
      _selectedPorts = group.portIndices.toSet();
      _nativeVlan = group.nativeVlan;
      _allowedVlans = _parseAllowedVlans(group.allowedVlans);
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.group.removeListener(_handleGroupChange);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final groups = widget.device.channelGroups;
    final updatedGroup = ChannelGroupConfig(
      groupNumber: widget.group.value!.groupNumber,
      name: _nameController.text,
      mode: _selectedMode,
      portIndices: _selectedPorts.toList()..sort(),
      nativeVlan: _nativeVlan,
      allowedVlans: _formatAllowedVlans(_allowedVlans),
    );

    final updatedGroups = [...groups];
    updatedGroups[widget.groupIndex] = updatedGroup;

    await Database.updateDeviceConfig(widget.device.id, {
      'channel_groups': updatedGroups.map((g) => g.toJson()).toList(),
    });
  }

  /// Get the speed that this group is locked to (based on first selected port)
  String? _getLockedSpeed() {
    if (_selectedPorts.isEmpty) return null;
    final firstPortIndex = _selectedPorts.first;
    return widget.getPortSpeed(widget.device.interfaces[firstPortIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group.value;
    if (group == null) {
      return const Center(child: Text('No group selected'));
    }

    final interfaces = widget.device.interfaces;
    final availableIndices = widget.getAvailablePortIndices(group);
    final lockedSpeed = _getLockedSpeed();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                'Port-channel ${group.groupNumber}',
                style: FluentTheme.of(context).typography.subtitle,
              ),
              const Spacer(),
              Button(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.red.darkest),
                ),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => ContentDialog(
                      title: const Text('Delete Channel Group'),
                      content: Text(
                        'Are you sure you want to delete Port-channel ${group.groupNumber}?',
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
                    widget.onDelete();
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
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Name'),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 300,
                          child: TextBox(
                            controller: _nameController,
                            onChanged: (_) => _saveChanges(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Mode'),
                        const SizedBox(height: 4),
                        ComboBox<ChannelGroupMode>(
                          value: _selectedMode,
                          items: ChannelGroupMode.values
                              .map(
                                (m) => ComboBoxItem<ChannelGroupMode>(
                                  value: m,
                                  child: Text(m.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedMode = value);
                              _saveChanges();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Trunk Settings',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 8),
                Text(
                  'Port-channel members are configured as trunk ports.',
                  style: FluentTheme.of(context).typography.caption,
                ),
                const SizedBox(height: 12),
                const Text('Native VLAN'),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ComboBox<int>(
                    value: _nativeVlan,
                    items: widget.device.vlans
                        .map(
                          (v) => ComboBoxItem<int>(
                            value: v.vlanId,
                            child: Text('VLAN ${v.vlanId} - ${v.name}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _nativeVlan = value);
                        _saveChanges();
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Allowed VLANs'),
                const SizedBox(height: 4),
                VlanMultiSelect(
                  vlans: widget.device.vlans,
                  selectedVlanIds: _allowedVlans,
                  onChanged: (newVlans) {
                    setState(() => _allowedVlans = newVlans);
                    _saveChanges();
                  },
                  placeholder: 'All VLANs allowed',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('Member Ports'),
                    const SizedBox(width: 8),
                    if (lockedSpeed != null)
                      InfoBadge(
                        source: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            lockedSpeed == 'gigabit'
                                ? 'GigabitEthernet only'
                                : lockedSpeed == 'fast'
                                ? 'FastEthernet only'
                                : lockedSpeed,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        color: Colors.blue,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select ports to add to this channel group. Only ports of the same speed can be grouped together.',
                  style: FluentTheme.of(context).typography.caption,
                ),
                const SizedBox(height: 8),
                InterfaceMultiSelect(
                  interfaces: interfaces,
                  selectedInterfaceIndices: _selectedPorts,
                  availableInterfaceIndices: availableIndices,
                  getInterfaceSpeed: widget.getPortSpeed,
                  lockedSpeed: lockedSpeed,
                  onChanged: (newPorts) {
                    setState(() => _selectedPorts = newPorts);
                    _saveChanges();
                  },
                  placeholder: 'Select member ports...',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
