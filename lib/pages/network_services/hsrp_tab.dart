import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/models/project.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/port.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

/// Helper class to pair a device with its matching interface
class _DeviceWithInterface {
  final NetDevice device;
  final Port port;
  const _DeviceWithInterface({required this.device, required this.port});
}

/// Preview of changes to a single member when virtual IP changes
class _MemberChangePreview {
  final HsrpMember member;
  final String? newInterfaceName; // If switching to different interface
  final String? currentInterfaceIp; // If updating interface IP
  final String? newInterfaceIp;
  final Port? interfaceToUpdate;
  final String? changeDescription;
  final String? errorMessage;

  _MemberChangePreview({
    required this.member,
    this.newInterfaceName,
    this.currentInterfaceIp,
    this.newInterfaceIp,
    this.interfaceToUpdate,
    this.changeDescription,
    this.errorMessage,
  });

  bool get hasChange => newInterfaceName != null || newInterfaceIp != null;
}

/// Preview of all changes when virtual IP changes
class _VirtualIpChangePreview {
  final String? oldVirtualIp;
  final String newVirtualIp;
  final List<_MemberChangePreview> memberChanges;

  _VirtualIpChangePreview({
    required this.oldVirtualIp,
    required this.newVirtualIp,
    required this.memberChanges,
  });

  bool get hasChanges =>
      memberChanges.any((c) => c.hasChange || c.errorMessage != null);
}

class HsrpTab extends StatefulWidget {
  const HsrpTab({super.key, required this.project, required this.devices});
  final Project project;
  final List<NetDevice> devices;

  @override
  State<HsrpTab> createState() => _HsrpTabState();
}

class _HsrpTabState extends State<HsrpTab> {
  HsrpGroup? _selectedGroup;

  /// Get only devices with HSRP capability
  List<NetDevice> get _hsrpCapableDevices => widget.devices
      .where((d) => d.preset.capabilities.contains('hsrp'))
      .toList();

  Future<void> _addHsrpGroup() async {
    final nameController = TextEditingController();
    final groupNumberController = TextEditingController(text: '0');

    final result = await showDialog<HsrpGroup>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ContentDialog(
        title: const Text('Add HSRP Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Name'),
            const SizedBox(height: 4),
            SizedBox(
              width: 250,
              child: TextBox(
                controller: nameController,
                placeholder: 'e.g., Core Gateway',
                autofocus: true,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Group Number'),
            const SizedBox(height: 4),
            SizedBox(
              width: 150,
              child: NumberBox<int>(
                value: int.tryParse(groupNumberController.text) ?? 0,
                onChanged: (v) =>
                    groupNumberController.text = v?.toString() ?? '0',
                min: 0,
                max: 255,
                placeholder: '0-255',
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final groupNumber = int.tryParse(groupNumberController.text) ?? 0;

              if (name.isNotEmpty) {
                Navigator.pop(
                  context,
                  HsrpGroup(name: name, groupNumber: groupNumber),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updated = widget.project.properties.copyWith(
        hsrpGroups: [...widget.project.properties.hsrpGroups, result],
      );
      await widget.project.updateProperties(updated);
      setState(() => _selectedGroup = result);
    }
  }

  Future<void> _deleteHsrpGroup(HsrpGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ContentDialog(
        title: const Text('Delete HSRP Group'),
        content: Text('Are you sure you want to delete "${group.name}"?'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updated = widget.project.properties.copyWith(
        hsrpGroups: widget.project.properties.hsrpGroups
            .where((g) => g.identifier != group.identifier)
            .toList(),
      );
      await widget.project.updateProperties(updated);
      if (_selectedGroup?.identifier == group.identifier) {
        _selectedGroup = null;
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.project.properties.hsrpGroups;

    return Row(
      children: [
        // Left: List of HSRP groups
        SizedBox(
          width: 280,
          child: Column(
            children: [
              CommandBar(
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.add),
                    label: const Text('Add Group'),
                    onPressed: _addHsrpGroup,
                  ),
                ],
              ),
              Expanded(
                child: groups.isEmpty
                    ? const Center(child: Text('No HSRP groups configured'))
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return ListTile.selectable(
                            title: Text(group.name),
                            subtitle: Text(
                              'Group ${group.groupNumber}${group.virtualIp != null ? ' • ${group.virtualIp}' : ''}',
                            ),
                            selected:
                                _selectedGroup?.identifier == group.identifier,
                            trailing: IconButton(
                              icon: const Icon(FluentIcons.delete, size: 14),
                              onPressed: () => _deleteHsrpGroup(group),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedGroup =
                                    _selectedGroup?.identifier ==
                                        group.identifier
                                    ? null
                                    : group;
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        // Right: Group details
        Expanded(
          child: _selectedGroup == null
              ? const Center(
                  child: Text('Select an HSRP group to view details'),
                )
              : _HsrpGroupDetails(
                  key: ValueKey(_selectedGroup!.identifier),
                  group: _selectedGroup!,
                  devices: _hsrpCapableDevices,
                  project: widget.project,
                  onUpdated: (updatedGroup) {
                    _selectedGroup = updatedGroup;
                    setState(() {});
                  },
                ),
        ),
      ],
    );
  }
}

class _HsrpGroupDetails extends StatefulWidget {
  const _HsrpGroupDetails({
    super.key,
    required this.group,
    required this.devices,
    required this.project,
    required this.onUpdated,
  });
  final HsrpGroup group;
  final List<NetDevice> devices;
  final Project project;
  final ValueChanged<HsrpGroup> onUpdated;

  @override
  State<_HsrpGroupDetails> createState() => _HsrpGroupDetailsState();
}

class _HsrpGroupDetailsState extends State<_HsrpGroupDetails> {
  late TextEditingController _nameController;
  late TextEditingController _virtualIpController;
  late TextEditingController _helloTimerController;
  late TextEditingController _holdTimerController;
  late TextEditingController _authKeyController;
  late int _version;
  late int _vlanId;
  final _addMemberFlyoutController = FlyoutController();
  final _selectedDevices = <int>{};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameController = TextEditingController(text: widget.group.name);
    _virtualIpController = TextEditingController(
      text: widget.group.virtualIp ?? '',
    );
    _helloTimerController = TextEditingController(
      text: widget.group.helloTimer.toString(),
    );
    _holdTimerController = TextEditingController(
      text: widget.group.holdTimer.toString(),
    );
    _authKeyController = TextEditingController(
      text: widget.group.authenticationKey ?? '',
    );
    _version = widget.group.version;
    _vlanId = widget.group.vlanId;
  }

  @override
  void didUpdateWidget(_HsrpGroupDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.identifier != widget.group.identifier) {
      _initControllers();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _virtualIpController.dispose();
    _helloTimerController.dispose();
    _holdTimerController.dispose();
    _authKeyController.dispose();
    _addMemberFlyoutController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final newVirtualIp = _virtualIpController.text.trim().isNotEmpty
        ? _virtualIpController.text.trim()
        : null;
    final virtualIpChanged = newVirtualIp != widget.group.virtualIp;
    final hasMembers = widget.group.members.isNotEmpty;

    var updatedGroup = widget.group.copyWith(
      name: _nameController.text.trim(),
      virtualIp: newVirtualIp,
      clearVirtualIp: _virtualIpController.text.trim().isEmpty,
      helloTimer: int.tryParse(_helloTimerController.text) ?? 3,
      holdTimer: int.tryParse(_holdTimerController.text) ?? 10,
      authenticationKey: _authKeyController.text.trim().isNotEmpty
          ? _authKeyController.text.trim()
          : null,
      version: _version,
      vlanId: _vlanId,
    );

    // If virtual IP changed and we have members, show preview and ask to update interface IPs
    if (virtualIpChanged && hasMembers && newVirtualIp != null) {
      final preview = _previewVirtualIpChange(newVirtualIp);

      if (preview.hasChanges) {
        final action = await _showVirtualIpChangeDialog(preview);

        if (action == 'update') {
          // Apply the interface IP changes to devices
          await _applyInterfaceIpChanges(preview);
          // Update group to use new interface names if they changed
          final updatedMembers = <HsrpMember>[];
          for (final member in updatedGroup.members) {
            final change = preview.memberChanges.firstWhere(
              (c) => c.member.deviceId == member.deviceId,
              orElse: () => _MemberChangePreview(member: member),
            );
            if (change.newInterfaceName != null) {
              updatedMembers.add(
                member.copyWith(interfaceName: change.newInterfaceName!),
              );
            } else {
              updatedMembers.add(member);
            }
          }
          updatedGroup = updatedGroup.copyWith(members: updatedMembers);
        }
      }
    }

    await _saveGroup(updatedGroup);
  }

  /// Preview what changes would happen when virtual IP changes
  _VirtualIpChangePreview _previewVirtualIpChange(String newVirtualIp) {
    final memberChanges = <_MemberChangePreview>[];

    for (final member in widget.group.members) {
      final device = widget.devices.firstWhere(
        (d) => d.id == member.deviceId,
        orElse: () => NetDevice(id: -1, projectId: -1, presetId: 1, config: {}),
      );
      if (device.id == -1) {
        memberChanges.add(
          _MemberChangePreview(
            member: member,
            errorMessage: 'Device not found',
          ),
        );
        continue;
      }

      final currentPort = device.interfaces.firstWhere(
        (p) => p.name == member.interfaceName,
        orElse: () => Port(name: ''),
      );

      // Check if current interface matches new virtual IP subnet
      if (currentPort.name.isNotEmpty && currentPort.ipAddress != null) {
        final ifaceIp = currentPort.ipAddress!;
        final prefix = IPv4.subnetMaskToPrefixLength(ifaceIp.subnetMask);
        final vipNum = _ipToInt(newVirtualIp);
        final ifaceNum = _ipToInt(ifaceIp.address);
        final mask = (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;

        if ((vipNum & mask) == (ifaceNum & mask)) {
          // Already in same subnet, no change needed
          memberChanges.add(_MemberChangePreview(member: member));
          continue;
        }
      }

      // Find an interface already in the new subnet
      final matchingPort = _findMatchingInterface(device, newVirtualIp);
      if (matchingPort != null) {
        // Can switch to a different interface
        memberChanges.add(
          _MemberChangePreview(
            member: member,
            newInterfaceName: matchingPort.name,
            changeDescription:
                'Switch to ${matchingPort.name} (${matchingPort.ipAddress?.address})',
          ),
        );
        continue;
      }

      // Need to change current interface IP or mark as invalid
      if (currentPort.name.isNotEmpty && currentPort.ipAddress != null) {
        // Calculate what the new IP would be (same host part, new network)
        final currentIp = currentPort.ipAddress!;
        final prefix = IPv4.subnetMaskToPrefixLength(currentIp.subnetMask);
        final hostMask = (1 << (32 - prefix)) - 1;
        final currentHostPart = _ipToInt(currentIp.address) & hostMask;
        final newNetworkPart = _ipToInt(newVirtualIp) & ~hostMask;
        final newIpInt = newNetworkPart | currentHostPart;
        final newIpAddr = _intToIp(newIpInt);

        memberChanges.add(
          _MemberChangePreview(
            member: member,
            currentInterfaceIp: currentIp.address,
            newInterfaceIp: newIpAddr,
            interfaceToUpdate: currentPort,
            changeDescription:
                '${currentPort.name}: ${currentIp.address} → $newIpAddr',
          ),
        );
      } else {
        memberChanges.add(
          _MemberChangePreview(
            member: member,
            errorMessage: 'Interface "${member.interfaceName}" has no IP',
          ),
        );
      }
    }

    return _VirtualIpChangePreview(
      oldVirtualIp: widget.group.virtualIp,
      newVirtualIp: newVirtualIp,
      memberChanges: memberChanges,
    );
  }

  String _intToIp(int ip) {
    return '${(ip >> 24) & 0xFF}.${(ip >> 16) & 0xFF}.${(ip >> 8) & 0xFF}.${ip & 0xFF}';
  }

  Future<String?> _showVirtualIpChangeDialog(_VirtualIpChangePreview preview) {
    final changesNeeded = preview.memberChanges
        .where((c) => c.hasChange || c.errorMessage != null)
        .toList();

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ContentDialog(
        title: const Text('Virtual IP Changed'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Virtual IP: ${preview.oldVirtualIp ?? "(none)"} → ${preview.newVirtualIp}',
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              const SizedBox(height: 16),
              if (changesNeeded.isEmpty)
                const Text(
                  'All member interfaces are already in the new subnet.',
                )
              else ...[
                const Text(
                  'The following changes will be made to member interfaces:',
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: changesNeeded.length,
                    itemBuilder: (context, index) {
                      final change = changesNeeded[index];
                      final deviceName = _getDeviceName(change.member.deviceId);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Expander(
                          header: Row(
                            children: [
                              Icon(
                                change.errorMessage != null
                                    ? FluentIcons.warning
                                    : FluentIcons.server,
                                size: 16,
                                color: change.errorMessage != null
                                    ? Colors.orange
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                deviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (change.errorMessage != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(${change.errorMessage})',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          content: change.changeDescription != null
                              ? Text('• ${change.changeDescription}')
                              : change.errorMessage != null
                              ? Text(
                                  'This member will be marked as invalid.',
                                  style: TextStyle(color: Colors.orange),
                                )
                              : const Text('No changes needed'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Do you want to update the interface IP addresses?',
                  style: FluentTheme.of(
                    context,
                  ).typography.body?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('No, Keep Current'),
          ),
          if (changesNeeded.any(
            (c) => c.newInterfaceIp != null || c.newInterfaceName != null,
          ))
            FilledButton(
              onPressed: () => Navigator.pop(context, 'update'),
              child: const Text('Yes, Update All'),
            ),
        ],
      ),
    );
  }

  Future<void> _applyInterfaceIpChanges(_VirtualIpChangePreview preview) async {
    for (final change in preview.memberChanges) {
      if (change.newInterfaceIp == null || change.interfaceToUpdate == null) {
        continue;
      }

      final device = widget.devices.firstWhere(
        (d) => d.id == change.member.deviceId,
        orElse: () => NetDevice(id: -1, projectId: -1, presetId: 1, config: {}),
      );
      if (device.id == -1) continue;

      // Find the interface index
      final interfaceIndex = device.interfaces.indexWhere(
        (p) => p.name == change.interfaceToUpdate!.name,
      );
      if (interfaceIndex == -1) continue;

      // Update the interface IP
      final currentIp = change.interfaceToUpdate!.ipAddress!;
      final newIp = IPv4(
        address: change.newInterfaceIp!,
        subnetMask: currentIp.subnetMask,
      );

      final updatedInterfaces = [...device.interfaces];
      updatedInterfaces[interfaceIndex] = updatedInterfaces[interfaceIndex]
          .copyWith(ipAddress: newIp);

      // Save to database - config uses 'ports' key for interfaces
      await Database.updateDeviceConfig(device.id, {
        'ports': updatedInterfaces.map((p) => p.toJson()).toList(),
      });
    }
  }

  /// Find the best matching interface for a device given the virtual IP
  Port? _findMatchingInterface(NetDevice device, String? virtualIp) {
    if (virtualIp == null || virtualIp.isEmpty) return null;

    // Parse the virtual IP to get network info
    final vipParts = virtualIp.split('.');
    if (vipParts.length != 4) return null;

    for (final port in device.interfaces) {
      if (port.ipAddress == null) continue;

      // Check if interface IP is in the same subnet as virtual IP
      final ifaceIp = port.ipAddress!;
      final prefix = IPv4.subnetMaskToPrefixLength(ifaceIp.subnetMask);

      // Calculate network addresses
      final vipNum = _ipToInt(virtualIp);
      final ifaceNum = _ipToInt(ifaceIp.address);
      final mask = (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;

      if ((vipNum & mask) == (ifaceNum & mask)) {
        return port;
      }
    }
    return null;
  }

  int _ipToInt(String ip) {
    // Strip CIDR notation if present (e.g., "192.168.1.1/24" -> "192.168.1.1")
    final ipOnly = ip.contains('/') ? ip.split('/')[0] : ip;
    final parts = ipOnly.split('.');
    if (parts.length != 4) return 0;
    return (int.parse(parts[0]) << 24) |
        (int.parse(parts[1]) << 16) |
        (int.parse(parts[2]) << 8) |
        int.parse(parts[3]);
  }

  /// Check if a member's interface still matches the virtual IP subnet
  /// Returns null if valid, or an error message if invalid
  String? _validateMember(HsrpMember member) {
    final device = widget.devices.firstWhere(
      (d) => d.id == member.deviceId,
      orElse: () => NetDevice(id: -1, projectId: -1, presetId: 1, config: {}),
    );
    if (device.id == -1) return 'Device not found';

    final port = device.interfaces.firstWhere(
      (p) => p.name == member.interfaceName,
      orElse: () => Port(name: ''),
    );
    if (port.name.isEmpty) {
      return 'Interface "${member.interfaceName}" not found';
    }
    if (port.ipAddress == null) return 'Interface has no IP address';

    // Check if interface is in same subnet as virtual IP
    final virtualIp = widget.group.virtualIp;
    if (virtualIp == null || virtualIp.isEmpty) {
      return null; // No virtual IP set, can't validate
    }

    final ifaceIp = port.ipAddress!;
    final prefix = IPv4.subnetMaskToPrefixLength(ifaceIp.subnetMask);
    final vipNum = _ipToInt(virtualIp);
    final ifaceNum = _ipToInt(ifaceIp.address);
    final mask = (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;

    if ((vipNum & mask) != (ifaceNum & mask)) {
      return 'IP ${ifaceIp.address} not in virtual IP subnet';
    }

    return null;
  }

  /// Get an alternative interface that matches the virtual IP subnet
  Port? _findAlternativeInterface(HsrpMember member) {
    final device = widget.devices.firstWhere(
      (d) => d.id == member.deviceId,
      orElse: () => NetDevice(id: -1, projectId: -1, presetId: 1, config: {}),
    );
    if (device.id == -1) return null;
    return _findMatchingInterface(device, widget.group.virtualIp);
  }

  /// Get available devices with their auto-detected interfaces
  List<_DeviceWithInterface> _getAvailableDevicesWithInterfaces() {
    final existingDeviceIds = widget.group.members
        .map((m) => m.deviceId)
        .toSet();
    final result = <_DeviceWithInterface>[];

    for (final device in widget.devices) {
      if (existingDeviceIds.contains(device.id)) continue;

      final matchingPort = _findMatchingInterface(
        device,
        widget.group.virtualIp,
      );
      if (matchingPort != null) {
        result.add(_DeviceWithInterface(device: device, port: matchingPort));
      }
    }
    return result;
  }

  /// Get the status message and available devices for the flyout
  (String?, List<_DeviceWithInterface>) _getFlyoutStatus() {
    if (widget.devices.isEmpty) {
      return ('No devices with HSRP capability in this project.', []);
    }

    if (widget.group.virtualIp == null || widget.group.virtualIp!.isEmpty) {
      return ('Set a Virtual IP first to auto-select interfaces.', []);
    }

    final availableDevices = _getAvailableDevicesWithInterfaces();

    if (availableDevices.isEmpty) {
      final existingDeviceIds = widget.group.members
          .map((m) => m.deviceId)
          .toSet();
      final nonMemberDevices = widget.devices
          .where((d) => !existingDeviceIds.contains(d.id))
          .toList();

      if (nonMemberDevices.isEmpty) {
        return ('All HSRP-capable devices are already members.', []);
      } else {
        return (
          'No devices have interfaces matching the Virtual IP subnet.',
          [],
        );
      }
    }

    return (null, availableDevices);
  }

  Future<void> _addSelectedMembers(
    List<_DeviceWithInterface> availableDevices,
  ) async {
    if (_selectedDevices.isEmpty) return;

    final newMembers = <HsrpMember>[];
    var currentCount = widget.group.members.length;

    for (final deviceId in _selectedDevices) {
      final item = availableDevices.firstWhere((d) => d.device.id == deviceId);
      final priority = 110 - (currentCount * 10);
      newMembers.add(
        HsrpMember(
          deviceId: deviceId,
          interfaceName: item.port.name,
          priority: priority.clamp(1, 255),
          preempt: true,
        ),
      );
      currentCount++;
    }

    final updatedGroup = widget.group.copyWith(
      members: [...widget.group.members, ...newMembers],
    );
    _selectedDevices.clear();
    _addMemberFlyoutController.close();
    await _saveGroup(updatedGroup);
  }

  Widget _buildAddMemberFlyout() {
    final (statusMessage, availableDevices) = _getFlyoutStatus();

    return StatefulBuilder(
      builder: (context, setFlyoutState) {
        if (statusMessage != null) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              statusMessage,
              style: FluentTheme.of(context).typography.caption,
            ),
          );
        }

        return SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Text(
                  'Add devices (interface auto-selected):',
                  style: FluentTheme.of(context).typography.caption,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: availableDevices.length,
                  itemBuilder: (context, index) {
                    final item = availableDevices[index];
                    final isSelected = _selectedDevices.contains(
                      item.device.id,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Checkbox(
                        checked: isSelected,
                        onChanged: (v) {
                          setFlyoutState(() {
                            if (v == true) {
                              _selectedDevices.add(item.device.id);
                            } else {
                              _selectedDevices.remove(item.device.id);
                            }
                          });
                        },
                        content: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.device.hostname,
                                style: FluentTheme.of(context).typography.body,
                              ),
                              Text(
                                '${item.port.name} (${item.port.ipAddress!.toCIDR()})',
                                style: FluentTheme.of(
                                  context,
                                ).typography.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Button(
                      onPressed: () {
                        _selectedDevices.clear();
                        _addMemberFlyoutController.close();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _selectedDevices.isNotEmpty
                          ? () => _addSelectedMembers(availableDevices)
                          : null,
                      child: Text(
                        'Add${_selectedDevices.isNotEmpty ? ' (${_selectedDevices.length})' : ''}',
                      ),
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

  Future<void> _fixMemberInterface(HsrpMember member) async {
    final altPort = _findAlternativeInterface(member);
    if (altPort == null) {
      // No valid interface found, ask user to remove
      final remove = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => ContentDialog(
          title: const Text('No Valid Interface'),
          content: Text(
            'No interface on ${_getDeviceName(member.deviceId)} matches the virtual IP subnet.\n\n'
            'Would you like to remove this device from the group?',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (remove == true) {
        await _removeMember(member);
      }
      return;
    }

    // Update member with new interface
    final updatedMembers = widget.group.members.map((m) {
      if (m.deviceId == member.deviceId &&
          m.interfaceName == member.interfaceName) {
        return m.copyWith(interfaceName: altPort.name);
      }
      return m;
    }).toList();

    final updatedGroup = widget.group.copyWith(members: updatedMembers);
    await _saveGroup(updatedGroup);
  }

  Future<void> _removeMember(HsrpMember member) async {
    final updatedGroup = widget.group.copyWith(
      members: widget.group.members
          .where(
            (m) =>
                m.deviceId != member.deviceId ||
                m.interfaceName != member.interfaceName,
          )
          .toList(),
    );
    await _saveGroup(updatedGroup);
  }

  Future<void> _reorderMembers(int oldIndex, int newIndex) async {
    final members = [...widget.group.members];
    if (newIndex > oldIndex) newIndex--;
    final member = members.removeAt(oldIndex);
    members.insert(newIndex, member);

    // Recalculate priorities based on order (first = highest priority)
    final updatedMembers = <HsrpMember>[];
    for (int i = 0; i < members.length; i++) {
      final priority = 110 - (i * 10); // 110, 100, 90, 80, ...
      updatedMembers.add(members[i].copyWith(priority: priority.clamp(1, 255)));
    }

    final updatedGroup = widget.group.copyWith(members: updatedMembers);
    await _saveGroup(updatedGroup);
  }

  Future<void> _saveGroup(HsrpGroup updatedGroup) async {
    final groups = widget.project.properties.hsrpGroups
        .map((g) => g.identifier == widget.group.identifier ? updatedGroup : g)
        .toList();
    await widget.project.updateProperties(
      widget.project.properties.copyWith(hsrpGroups: groups),
    );
    widget.onUpdated(updatedGroup);
  }

  String _getDeviceName(int deviceId) {
    final device = widget.devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => NetDevice(
        id: -1,
        projectId: -1,
        presetId: 1,
        config: {'hostname': 'Unknown'},
      ),
    );
    return device.hostname;
  }

  @override
  Widget build(BuildContext context) {
    return FluentWidgets.mica(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with save button
            Row(
              children: [
                Text(
                  widget.group.name,
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saveSettings,
                  child: const Text('Save Settings'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Settings section
            Expander(
              header: const Text('Group Settings'),
              initiallyExpanded: true,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Name'),
                            const SizedBox(height: 4),
                            TextBox(
                              controller: _nameController,
                              placeholder: 'Group name',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Virtual IP'),
                            const SizedBox(height: 4),
                            TextBox(
                              controller: _virtualIpController,
                              placeholder: 'e.g., 192.168.1.1',
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
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Version'),
                            const SizedBox(height: 4),
                            ComboBox<int>(
                              value: _version,
                              items: const [
                                ComboBoxItem(value: 1, child: Text('1')),
                                ComboBoxItem(value: 2, child: Text('2')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _version = v ?? 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('VLAN ID'),
                            const SizedBox(height: 4),
                            NumberBox<int>(
                              value: _vlanId,
                              onChanged: (v) =>
                                  setState(() => _vlanId = v ?? 1),
                              min: 1,
                              max: 4094,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hello Timer'),
                            const SizedBox(height: 4),
                            NumberBox<int>(
                              value:
                                  int.tryParse(_helloTimerController.text) ?? 3,
                              onChanged: (v) => _helloTimerController.text =
                                  v?.toString() ?? '3',
                              min: 1,
                              max: 255,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 120,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hold Timer'),
                            const SizedBox(height: 4),
                            NumberBox<int>(
                              value:
                                  int.tryParse(_holdTimerController.text) ?? 10,
                              onChanged: (v) => _holdTimerController.text =
                                  v?.toString() ?? '10',
                              min: 1,
                              max: 255,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 250,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Authentication Key (optional)'),
                        const SizedBox(height: 4),
                        PasswordBox(
                          controller: _authKeyController,
                          placeholder: 'Plain text key',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Members section
            Row(
              children: [
                Text(
                  'Members',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(width: 8),
                FlyoutTarget(
                  controller: _addMemberFlyoutController,
                  child: IconButton(
                    icon: const Icon(FluentIcons.add, size: 14),
                    onPressed: () {
                      _selectedDevices.clear();
                      _addMemberFlyoutController.showFlyout(
                        barrierDismissible: true,
                        dismissOnPointerMoveAway: false,
                        builder: (context) =>
                            FlyoutContent(child: _buildAddMemberFlyout()),
                      );
                    },
                  ),
                ),
                const Spacer(),
                Text(
                  'Drag to reorder (top = highest priority)',
                  style: FluentTheme.of(context).typography.caption,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.group.members.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('No members configured'),
                          const SizedBox(height: 8),
                          if (widget.devices.isEmpty)
                            Text(
                              'Add devices with HSRP capability to this project first',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: widget.group.members.length,
                      onReorder: _reorderMembers,
                      itemBuilder: (context, index) {
                        final member = widget.group.members[index];
                        final isActive = index == 0;
                        final validationError = _validateMember(member);
                        final isInvalid = validationError != null;
                        return ReorderableDragStartListener(
                          key: ValueKey(
                            '${member.deviceId}_${member.interfaceName}',
                          ),
                          index: index,
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            backgroundColor: isInvalid
                                ? Colors.red.withValues(alpha: 0.1)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    FluentIcons.global_nav_button,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _getDeviceName(member.deviceId),
                                              style: FluentTheme.of(
                                                context,
                                              ).typography.bodyStrong,
                                            ),
                                            if (isInvalid) ...[
                                              const SizedBox(width: 8),
                                              FluentWidgets.chip(
                                                text: 'Invalid',
                                                color: Colors.red,
                                              ),
                                            ] else if (isActive) ...[
                                              const SizedBox(width: 8),
                                              FluentWidgets.chip(
                                                text: 'Active',
                                                color: Colors.green,
                                              ),
                                            ] else ...[
                                              const SizedBox(width: 8),
                                              FluentWidgets.chip(
                                                text: 'Standby',
                                                color: Colors.orange,
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (isInvalid)
                                          Text(
                                            validationError,
                                            style: FluentTheme.of(context)
                                                .typography
                                                .caption
                                                ?.copyWith(color: Colors.red),
                                          )
                                        else
                                          Text(
                                            '${member.interfaceName} • Priority: ${member.priority}${member.preempt ? ' • Preempt' : ''}',
                                            style: FluentTheme.of(
                                              context,
                                            ).typography.caption,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isInvalid) ...[
                                    Tooltip(
                                      message: 'Fix: Find matching interface',
                                      child: GestureDetector(
                                        onTap: () =>
                                            _fixMemberInterface(member),
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            FluentIcons.refresh,
                                            size: 14,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  Tooltip(
                                    message: 'Remove from group',
                                    child: GestureDetector(
                                      onTap: () => _removeMember(member),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          FluentIcons.delete,
                                          size: 14,
                                          color: isInvalid ? Colors.red : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
