import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/devices/switchport.dart';
import 'package:ktracer_center/devices/system_constraints.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/network/port.dart';
import 'package:ktracer_center/widgets/device_details/Interfaces/interface_management.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

/// Represents either a single interface, a subinterface, or a port-channel group
class InterfaceListItem {
  final int? interfaceIndex; // null for port-channel
  final ChannelGroupConfig? channelGroup;
  final List<int>
  memberInterfaceIndices; // for port-channel, the member interfaces
  final int?
  parentInterfaceIndex; // for subinterfaces, the parent interface index
  final List<int>
  subinterfaceIndices; // for parent interfaces, list of subinterface indices

  InterfaceListItem.interface_(
    this.interfaceIndex, {
    this.subinterfaceIndices = const [],
  }) : channelGroup = null,
       memberInterfaceIndices = [],
       parentInterfaceIndex = null;

  InterfaceListItem.subinterface(this.interfaceIndex, this.parentInterfaceIndex)
    : channelGroup = null,
      memberInterfaceIndices = [],
      subinterfaceIndices = [];

  InterfaceListItem.channelGroup(this.channelGroup, this.memberInterfaceIndices)
    : interfaceIndex = null,
      parentInterfaceIndex = null,
      subinterfaceIndices = [];

  bool get isChannelGroup => channelGroup != null;
  bool get isSubinterface => parentInterfaceIndex != null;
  bool get hasSubinterfaces => subinterfaceIndices.isNotEmpty;
}

class InterfaceList extends StatefulWidget {
  const InterfaceList({super.key, required this.device});
  final NetDevice device;

  @override
  State<InterfaceList> createState() => _InterfaceListState();
}

class _InterfaceListState extends State<InterfaceList> {
  // Multi-select: set of selected interface indices
  final Set<int> _selectedInterfaceIndices = {};
  // For channel groups, store selected group numbers
  final Set<int> _selectedChannelGroups = {};
  // Last clicked index for shift-select
  int? _lastClickedIndex;
  // Track if we're in port-channel selection mode
  bool _isChannelGroupMode = false;

  // Flyout controller for context menu
  final _contextMenuController = FlyoutController();

  // Controllers for add subinterface dialog
  final _subinterfaceNumberController = TextEditingController();
  final _subinterfaceVlanController = TextEditingController();

  @override
  void didUpdateWidget(InterfaceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.id != oldWidget.device.id) {
      _selectedInterfaceIndices.clear();
      _selectedChannelGroups.clear();
      _lastClickedIndex = null;
      _isChannelGroupMode = false;
    }
  }

  @override
  void dispose() {
    _contextMenuController.dispose();
    _subinterfaceNumberController.dispose();
    _subinterfaceVlanController.dispose();
    super.dispose();
  }

  /// Check if the device supports subinterfaces
  bool get _hasSubinterfaceCapability =>
      widget.device.preset.capabilities.contains('subinterfaces');

  Future<void> _addSubinterface(
    String parentName,
    int subNumber,
    int vlanId,
  ) async {
    final interfaces = widget.device.interfaces;
    final subinterfaceName = '$parentName.$subNumber';

    // Check if subinterface already exists
    if (interfaces.any((p) => p.name == subinterfaceName)) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Subinterface already exists'),
            content: Text('$subinterfaceName is already configured.'),
            severity: InfoBarSeverity.warning,
            onClose: close,
          ),
        );
      }
      return;
    }

    // Fetch current ports JSON from database to preserve all fields
    final current = await Database.getDeviceConfig(widget.device.id);

    // Handle both List and Map formats for ports
    // Config can store ports as either:
    // - List: Full port definitions
    // - Map: Sparse overrides keyed by port index
    final portsData = current?['ports'];
    List<Map<String, dynamic>> currentPorts;

    if (portsData is List) {
      currentPorts = portsData
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
    } else if (portsData is Map<String, dynamic>) {
      // Convert Map format to List format using current device interfaces
      currentPorts = widget.device.interfaces.map((p) => p.toJson()).toList();
    } else {
      // No ports data, use device's current interfaces
      currentPorts = widget.device.interfaces.map((p) => p.toJson()).toList();
    }

    // Create new subinterface JSON
    final newSubinterface = <String, dynamic>{
      'name': subinterfaceName,
      'description': 'VLAN $vlanId subinterface',
      'enabled': true,
      'is_switchport': false,
      'encapsulation': 'dot1q',
      'encapsulation_vlan': vlanId,
    };

    // Append to existing ports
    currentPorts.add(newSubinterface);

    await Database.updateDeviceConfig(widget.device.id, {
      'ports': currentPorts,
    });

    setState(() {});
  }

  /// Get the speed category of an interface based on its name
  String _getInterfaceSpeed(Port interface_) {
    final name = interface_.name.toLowerCase();
    if (name.contains('gigabit') || name.startsWith('gi')) {
      return 'gigabit';
    } else if (name.contains('fastethernet') || name.startsWith('fa')) {
      return 'fast';
    } else if (name.contains('tengigabit') || name.startsWith('te')) {
      return 'tengig';
    }
    return 'unknown';
  }

  /// Check if all selected interfaces have the same speed (required for channel groups)
  bool _canCreateChannelGroup() {
    if (_selectedInterfaceIndices.length < 2) return false;
    if (_isChannelGroupMode) {
      return false; // Can't create from channel group selection}
    }

    final interfaces = widget.device.interfaces;
    final speeds = _selectedInterfaceIndices
        .where((i) => i < interfaces.length)
        .map((i) => _getInterfaceSpeed(interfaces[i]))
        .toSet();

    return speeds.length == 1;
  }

  /// Get interface indices that are already in a channel group
  Set<int> _getInterfacesInChannelGroups() {
    final inGroups = <int>{};
    for (final group in widget.device.channelGroups) {
      inGroups.addAll(group.portIndices);
    }
    return inGroups;
  }

  /// Check if any selected interfaces are already in a channel group
  bool _anySelectedInterfaceInChannelGroup() {
    final inGroups = _getInterfacesInChannelGroups();
    return _selectedInterfaceIndices.any((i) => inGroups.contains(i));
  }

  Future<void> _createChannelGroup() async {
    if (!_canCreateChannelGroup()) return;
    if (_anySelectedInterfaceInChannelGroup()) {
      // Show warning
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Cannot create channel group'),
            content: const Text(
              'Some selected interfaces are already in a channel group.',
            ),
            severity: InfoBarSeverity.warning,
            onClose: close,
          ),
        );
      }
      return;
    }

    // Find next available group number
    final existingNumbers = widget.device.channelGroups
        .map((g) => g.groupNumber)
        .toSet();
    var nextNumber = 1;
    while (existingNumbers.contains(nextNumber)) {
      nextNumber++;
    }

    final newGroup = ChannelGroupConfig(
      groupNumber: nextNumber,
      portIndices: _selectedInterfaceIndices.toList()..sort(),
    );
    final updatedGroups = [...widget.device.channelGroups, newGroup];

    await Database.updateDeviceConfig(widget.device.id, {
      'channel_groups': updatedGroups.map((g) => g.toJson()).toList(),
    });

    // Clear selection after creating group
    setState(() {
      _selectedInterfaceIndices.clear();
      _selectedChannelGroups.clear();
      _isChannelGroupMode = false;
    });
  }

  void _showContextMenu(BuildContext targetContext, Offset globalPosition) {
    final hasEtherchannelCapability =
        widget.device.preset.capabilities.contains('etherchannel') ||
        widget.device.preset.capabilities.contains('lacp');

    if (!hasEtherchannelCapability) return;
    if (_selectedInterfaceIndices.isEmpty) return;

    final canCreate =
        _canCreateChannelGroup() && !_anySelectedInterfaceInChannelGroup();

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: globalPosition.dx,
            top: globalPosition.dy,
            child: FlyoutContent(
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HoverButton(
                      onPressed: canCreate
                          ? () {
                              Navigator.of(context).pop();
                              _createChannelGroup();
                            }
                          : null,
                      builder: (context, states) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        color: states.isHovered && canCreate
                            ? FluentTheme.of(
                                context,
                              ).resources.subtleFillColorSecondary
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Icon(
                              FluentIcons.link,
                              size: 14,
                              color: canCreate
                                  ? null
                                  : FluentTheme.of(
                                      context,
                                    ).resources.textFillColorDisabled,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Create Channel Group',
                              style: TextStyle(
                                color: canCreate
                                    ? null
                                    : FluentTheme.of(
                                        context,
                                      ).resources.textFillColorDisabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!canCreate && _selectedInterfaceIndices.length < 2)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Text(
                          'Select at least 2 interfaces',
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(
                                color: FluentTheme.of(
                                  context,
                                ).resources.textFillColorSecondary,
                              ),
                        ),
                      ),
                    if (!canCreate &&
                        _selectedInterfaceIndices.length >= 2 &&
                        !_canCreateChannelGroup())
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Text(
                          'Interfaces must have the same speed',
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(
                                color: FluentTheme.of(
                                  context,
                                ).resources.textFillColorSecondary,
                              ),
                        ),
                      ),
                    if (!canCreate && _anySelectedInterfaceInChannelGroup())
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Text(
                          'Some interfaces are already in a group',
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(
                                color: FluentTheme.of(
                                  context,
                                ).resources.textFillColorSecondary,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the list of items to display (interfaces + port-channels as single items)
  /// Subinterfaces are grouped under their parent interfaces
  List<InterfaceListItem> _buildInterfaceListItems() {
    final interfaces = widget.device.interfaces;
    final channelGroups = widget.device.channelGroups;
    final items = <InterfaceListItem>[];

    // Get all interface indices that are in channel groups
    final interfacesInChannelGroups = <int>{};
    for (final group in channelGroups) {
      interfacesInChannelGroups.addAll(group.portIndices);
    }

    // Build a map of parent interface names to their indices
    // and identify which interfaces are subinterfaces
    final parentNameToIndex = <String, int>{};
    final subinterfacesByParent = <int, List<int>>{};
    final subinterfaceIndices = <int>{};

    for (var i = 0; i < interfaces.length; i++) {
      final name = interfaces[i].name;
      if (name.contains('.')) {
        // This is a subinterface - find its parent
        final parentName = name.substring(0, name.lastIndexOf('.'));
        subinterfaceIndices.add(i);

        // Find parent index
        for (var j = 0; j < interfaces.length; j++) {
          if (interfaces[j].name == parentName) {
            subinterfacesByParent.putIfAbsent(j, () => []).add(i);
            break;
          }
        }
      } else {
        // This is a physical interface - store its name for lookup
        parentNameToIndex[name] = i;
      }
    }

    // Add individual interfaces (not in any channel group and not a subinterface)
    for (var i = 0; i < interfaces.length; i++) {
      if (!interfacesInChannelGroups.contains(i) &&
          !subinterfaceIndices.contains(i)) {
        final subinterfaces = subinterfacesByParent[i] ?? [];
        items.add(
          InterfaceListItem.interface_(i, subinterfaceIndices: subinterfaces),
        );

        // Add subinterfaces immediately after their parent
        for (final subIdx in subinterfaces) {
          items.add(InterfaceListItem.subinterface(subIdx, i));
        }
      }
    }

    // Add channel groups as single items
    for (final group in channelGroups) {
      if (group.portIndices.isNotEmpty) {
        items.add(InterfaceListItem.channelGroup(group, group.portIndices));
      }
    }

    return items;
  }

  void _handleItemClick(
    InterfaceListItem item,
    int displayIndex,
    bool isCtrlPressed,
    bool isShiftPressed,
  ) {
    setState(() {
      if (item.isChannelGroup) {
        // Channel group selection
        final groupNum = item.channelGroup!.groupNumber;

        if (isCtrlPressed) {
          // Toggle channel group selection
          if (_selectedChannelGroups.contains(groupNum)) {
            _selectedChannelGroups.remove(groupNum);
            // Also remove member interfaces from selection
            _selectedInterfaceIndices.removeAll(item.memberInterfaceIndices);
          } else {
            _selectedChannelGroups.add(groupNum);
            // Also add member interfaces to selection
            _selectedInterfaceIndices.addAll(item.memberInterfaceIndices);
          }
          _isChannelGroupMode = _selectedChannelGroups.isNotEmpty;
        } else if (!isShiftPressed) {
          // Single click - clear and select
          _selectedInterfaceIndices.clear();
          _selectedChannelGroups.clear();
          _selectedChannelGroups.add(groupNum);
          _selectedInterfaceIndices.addAll(item.memberInterfaceIndices);
          _isChannelGroupMode = true;
        }
        _lastClickedIndex = displayIndex;
      } else {
        // Regular interface selection
        final interfaceIndex = item.interfaceIndex!;

        if (isCtrlPressed) {
          // Toggle single interface
          if (_selectedInterfaceIndices.contains(interfaceIndex)) {
            _selectedInterfaceIndices.remove(interfaceIndex);
          } else {
            _selectedInterfaceIndices.add(interfaceIndex);
          }
          _selectedChannelGroups.clear();
          _isChannelGroupMode = false;
        } else if (isShiftPressed && _lastClickedIndex != null) {
          // Range select
          final items = _buildInterfaceListItems();
          final start = _lastClickedIndex!.clamp(0, items.length - 1);
          final end = displayIndex;
          final minIdx = start < end ? start : end;
          final maxIdx = start > end ? start : end;

          for (var i = minIdx; i <= maxIdx; i++) {
            final rangeItem = items[i];
            if (!rangeItem.isChannelGroup && rangeItem.interfaceIndex != null) {
              _selectedInterfaceIndices.add(rangeItem.interfaceIndex!);
            }
          }
          _selectedChannelGroups.clear();
          _isChannelGroupMode = false;
        } else {
          // Single click - clear and select
          _selectedInterfaceIndices.clear();
          _selectedChannelGroups.clear();
          _selectedInterfaceIndices.add(interfaceIndex);
          _isChannelGroupMode = false;
        }
        _lastClickedIndex = displayIndex;
      }
    });
  }

  bool _isItemSelected(InterfaceListItem item) {
    if (item.isChannelGroup) {
      return _selectedChannelGroups.contains(item.channelGroup!.groupNumber);
    } else {
      return _selectedInterfaceIndices.contains(item.interfaceIndex);
    }
  }

  String _getShortInterfaceName(String name) {
    return name
        .replaceAll('FastEthernet', 'Fa')
        .replaceAll('GigabitEthernet', 'Gi')
        .replaceAll('TenGigabitEthernet', 'Te');
  }

  Widget _buildInterfaceItem(InterfaceListItem item, int displayIndex) {
    final interfaces = widget.device.interfaces;
    final isSelected = _isItemSelected(item);

    if (item.isChannelGroup) {
      // Port-channel item
      final group = item.channelGroup!;
      final memberNames = item.memberInterfaceIndices
          .map((i) => _getShortInterfaceName(interfaces[i].name))
          .join(', ');

      return ListTile.selectable(
        leading: const Icon(FluentIcons.link, size: 16),
        title: Text('Po${group.groupNumber}'),
        subtitle: Text(
          '${item.memberInterfaceIndices.length} interfaces: $memberNames',
        ),
        selected: isSelected,
        onPressed: () {
          final isCtrl = HardwareKeyboard.instance.isControlPressed;
          final isShift = HardwareKeyboard.instance.isShiftPressed;
          _handleItemClick(item, displayIndex, isCtrl, isShift);
        },
      );
    } else if (item.isSubinterface) {
      // Subinterface item - indented under parent
      final interface_ = interfaces[item.interfaceIndex!];
      final shortName = _getShortInterfaceName(interface_.name);
      // Extract just the subinterface number (after the dot)
      final subNumber = shortName.contains('.')
          ? shortName.substring(shortName.lastIndexOf('.'))
          : shortName;

      return Padding(
        padding: const EdgeInsets.only(left: 24),
        child: GestureDetector(
          onSecondaryTapUp: (details) {
            final interfaceIndex = item.interfaceIndex!;
            if (!_selectedInterfaceIndices.contains(interfaceIndex)) {
              setState(() {
                _selectedInterfaceIndices.clear();
                _selectedChannelGroups.clear();
                _selectedInterfaceIndices.add(interfaceIndex);
                _isChannelGroupMode = false;
              });
            }
            _showContextMenu(context, details.globalPosition);
          },
          child: ListTile.selectable(
            leading: const Icon(FluentIcons.flow, size: 14),
            title: Text(subNumber, style: const TextStyle(fontSize: 13)),
            selected: isSelected,
            onPressed: () {
              final isCtrl = HardwareKeyboard.instance.isControlPressed;
              final isShift = HardwareKeyboard.instance.isShiftPressed;
              _handleItemClick(item, displayIndex, isCtrl, isShift);
            },
          ),
        ),
      );
    } else {
      // Regular interface item (potentially a parent of subinterfaces)
      final interface_ = interfaces[item.interfaceIndex!];
      String? subtitle;
      if (interface_ is Switchport) {
        subtitle = interface_.mode == SwitchportMode.trunk
            ? 'Trunk'
            : 'Access VLAN ${interface_.vlan}';
      }

      // Determine icon based on interface type
      IconData interfaceIcon =
          FluentIcons.plug_solid; // Default for FastEthernet
      final nameLower = interface_.name.toLowerCase();
      if (nameLower.startsWith('gi') || nameLower.contains('gigabit')) {
        interfaceIcon = FluentIcons.lightning_bolt_solid;
      } else if (nameLower.startsWith('te') ||
          nameLower.contains('tengigabit')) {
        interfaceIcon = FluentIcons.fast_forward;
      } else if (nameLower.startsWith('s') && nameLower.contains('/') ||
          nameLower.contains('serial')) {
        interfaceIcon = FluentIcons.code;
      } else if (nameLower.startsWith('tu') || nameLower.contains('tunnel')) {
        interfaceIcon = FluentIcons.split_object;
      }

      // Check if this interface can have subinterfaces added
      final canAddSub =
          _hasSubinterfaceCapability &&
          _canAddSubinterfaceToPort(interface_.name);

      // Check if this port is system-locked
      final isSystemLocked = isPortReserved(interface_.name);

      return GestureDetector(
        onSecondaryTapUp: isSystemLocked
            ? null
            : (details) {
                // First select this interface if not already selected
                final interfaceIndex = item.interfaceIndex!;
                if (!_selectedInterfaceIndices.contains(interfaceIndex)) {
                  setState(() {
                    _selectedInterfaceIndices.clear();
                    _selectedChannelGroups.clear();
                    _selectedInterfaceIndices.add(interfaceIndex);
                    _isChannelGroupMode = false;
                  });
                }
                // Show context menu
                _showContextMenu(context, details.globalPosition);
              },
        child: ListTile.selectable(
          leading: Icon(interfaceIcon, size: 16),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_getShortInterfaceName(interface_.name)),
              if (isSystemLocked) ...[
                const SizedBox(width: 6),
                const Icon(
                  FluentIcons.lock,
                  size: 12,
                  color: Colors.warningPrimaryColor,
                ),
              ],
            ],
          ),
          subtitle: subtitle != null
              ? Text(isSystemLocked ? '$subtitle (System Reserved)' : subtitle)
              : (isSystemLocked ? const Text('System Reserved') : null),
          selected: isSelected,
          trailing: canAddSub && !isSystemLocked
              ? IconButton(
                  icon: const Icon(FluentIcons.add, size: 12),
                  onPressed: () =>
                      _showAddSubinterfaceDialogFor(interface_.name),
                )
              : null,
          onPressed: isSystemLocked
              ? null
              : () {
                  final isCtrl = HardwareKeyboard.instance.isControlPressed;
                  final isShift = HardwareKeyboard.instance.isShiftPressed;
                  _handleItemClick(item, displayIndex, isCtrl, isShift);
                },
        ),
      );
    }
  }

  /// Check if a specific port can have subinterfaces added (Fa/Gi/Te physical ports only)
  bool _canAddSubinterfaceToPort(String portName) {
    final name = portName.toLowerCase();
    final isPhysicalPort =
        (name.startsWith('fa') ||
            name.startsWith('gi') ||
            name.startsWith('te') ||
            name.contains('fastethernet') ||
            name.contains('gigabitethernet') ||
            name.contains('tengigabitethernet')) &&
        !name.contains('.');
    return isPhysicalPort;
  }

  /// Show add subinterface dialog for a specific parent interface
  void _showAddSubinterfaceDialogFor(String parentName) {
    _subinterfaceNumberController.clear();
    _subinterfaceVlanController.clear();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ContentDialog(
        title: const Text('Add Subinterface'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Parent Interface: $parentName'),
            const SizedBox(height: 12),
            const Text('Subinterface Number'),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: NumberBox<int>(
                value: int.tryParse(_subinterfaceNumberController.text),
                onChanged: (value) {
                  _subinterfaceNumberController.text = value?.toString() ?? '';
                  // Auto-fill VLAN if empty
                  if (_subinterfaceVlanController.text.isEmpty &&
                      value != null) {
                    _subinterfaceVlanController.text = value.toString();
                  }
                },
                min: 1,
                max: 4094,
                placeholder: 'e.g., 10',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Encapsulation VLAN (802.1Q)'),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: NumberBox<int>(
                value: int.tryParse(_subinterfaceVlanController.text),
                onChanged: (value) {
                  _subinterfaceVlanController.text = value?.toString() ?? '';
                },
                min: 1,
                max: 4094,
                placeholder: 'e.g., 10',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Subinterface will be created as $parentName.<number>',
              style: FluentTheme.of(context).typography.caption,
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
              final subNumber = int.tryParse(
                _subinterfaceNumberController.text,
              );
              final vlanId = int.tryParse(_subinterfaceVlanController.text);

              if (subNumber != null && vlanId != null) {
                _addSubinterface(parentName, subNumber, vlanId);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildInterfaceListItems();
    final interfaces = widget.device.interfaces;

    // Clean up any invalid selections (indices that exceed current interfaces count)
    _selectedInterfaceIndices.removeWhere((idx) => idx >= interfaces.length);

    // Determine what to show in the management panel
    Widget managementPanel;

    if (_selectedInterfaceIndices.isEmpty && _selectedChannelGroups.isEmpty) {
      managementPanel = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.touch_pointer, size: 32),
            SizedBox(height: 8),
            Text('Select an interface'),
            SizedBox(height: 4),
            Text(
              'Ctrl+Click to select multiple\nShift+Click for range select',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    } else if (_isChannelGroupMode && _selectedChannelGroups.length == 1) {
      // Single channel group selected - show channel group management
      final groupNum = _selectedChannelGroups.first;
      final group = widget.device.channelGroups.firstWhere(
        (g) => g.groupNumber == groupNum,
      );
      managementPanel = _ChannelGroupInterfaceManagement(
        channelGroup: group,
        device: widget.device,
        selectedInterfaceIndices: _selectedInterfaceIndices,
      );
    } else {
      // One or more interfaces selected - show interface management
      managementPanel = InterfaceManagement(
        interface_: ValueNotifier(interfaces[_selectedInterfaceIndices.first]),
        device: widget.device,
        interfaceIndex: _selectedInterfaceIndices.first,
        selectedInterfaceIndices: _selectedInterfaceIndices,
      );
    }

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
                    'Interfaces',
                    style: FluentTheme.of(context).typography.subtitle,
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
                    child: items.isEmpty
                        ? const Center(child: Text('No interfaces configured'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, index) =>
                                _buildInterfaceItem(items[index], index),
                          ),
                  ),
                  Expanded(child: FluentWidgets.mica(child: managementPanel)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Management panel for a port-channel group
class _ChannelGroupInterfaceManagement extends StatelessWidget {
  const _ChannelGroupInterfaceManagement({
    required this.channelGroup,
    required this.device,
    required this.selectedInterfaceIndices,
  });

  final ChannelGroupConfig channelGroup;
  final NetDevice device;
  final Set<int> selectedInterfaceIndices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(FluentIcons.link, size: 20),
              const SizedBox(width: 8),
              Text(
                'Port-channel ${channelGroup.groupNumber}',
                style: FluentTheme.of(context).typography.subtitle,
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
                Text(
                  'Channel Group Settings',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Mode:'),
                    const SizedBox(width: 8),
                    Text(
                      channelGroup.mode.name.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Member Interfaces:'),
                    const SizedBox(width: 8),
                    Text('${channelGroup.portIndices.length}'),
                  ],
                ),
                const SizedBox(height: 16),
                InfoBar(
                  title: const Text('Port-Channel Configuration'),
                  content: const Text(
                    'Member interfaces are configured as trunk ports. '
                    'Edit native VLAN and allowed VLANs in the Channel Groups tab.',
                  ),
                  severity: InfoBarSeverity.info,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
