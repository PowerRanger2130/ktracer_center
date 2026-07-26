import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/interface_descriptor.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/models/project.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/widgets/interface_selector.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class OspfTab extends StatefulWidget {
  const OspfTab({super.key, required this.project, required this.devices});
  final Project project;
  final List<NetDevice> devices;

  @override
  State<OspfTab> createState() => _OspfTabState();
}

class _OspfTabState extends State<OspfTab> {
  OspfDomain? _selectedDomain;

  List<OspfDomain> get _domains => widget.project.properties.ospfDomains;

  Future<void> _addOspfDomain() async {
    final processIdController = TextEditingController(text: '1');
    final refBandwidthController = TextEditingController();

    final result = await showDialog<OspfDomain>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Add OSPF Domain'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Process ID'),
            const SizedBox(height: 4),
            SizedBox(
              width: 150,
              child: NumberBox<int>(
                value: int.tryParse(processIdController.text) ?? 1,
                onChanged: (v) =>
                    processIdController.text = v?.toString() ?? '1',
                min: 1,
                max: 65535,
              ),
            ),
            const SizedBox(height: 12),
            const Text('Reference Bandwidth (optional)'),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: NumberBox<int>(
                value: int.tryParse(refBandwidthController.text),
                onChanged: (v) =>
                    refBandwidthController.text = v?.toString() ?? '',
                min: 1,
                placeholder: 'Default: 100 Mbps',
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
              final processId = int.tryParse(processIdController.text) ?? 1;
              final refBw = int.tryParse(refBandwidthController.text);
              Navigator.pop(
                context,
                OspfDomain(
                  processId: processId,
                  referenceBandwidth: refBw,
                  areas: const [OspfArea(areaId: 0)], // Default backbone area
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updated = widget.project.properties.copyWith(
        ospfDomains: [..._domains, result],
      );
      await widget.project.updateProperties(updated);
      setState(() => _selectedDomain = result);
    }
  }

  Future<void> _deleteOspfDomain(OspfDomain domain) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete OSPF Domain'),
        content: Text(
          'Are you sure you want to delete OSPF process ${domain.processId}?',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.red),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = widget.project.properties.copyWith(
        ospfDomains: _domains
            .where((d) => d.identifier != domain.identifier)
            .toList(),
      );
      await widget.project.updateProperties(updated);
      if (_selectedDomain?.identifier == domain.identifier) {
        _selectedDomain = null;
      }
      setState(() {});
    }
  }

  Future<void> _toggleDomainEnabled(OspfDomain domain) async {
    final updatedDomain = domain.copyWith(enabled: !domain.enabled);
    final updatedDomains = _domains
        .map((d) => d.identifier == domain.identifier ? updatedDomain : d)
        .toList();
    await widget.project.updateProperties(
      widget.project.properties.copyWith(ospfDomains: updatedDomains),
    );
    if (_selectedDomain?.identifier == domain.identifier) {
      _selectedDomain = updatedDomain;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Column(
            children: [
              CommandBar(
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.add),
                    label: const Text('Add Process'),
                    onPressed: _addOspfDomain,
                  ),
                ],
              ),
              Expanded(
                child: _domains.isEmpty
                    ? const Center(child: Text('No OSPF processes configured'))
                    : ListView.builder(
                        itemCount: _domains.length,
                        itemBuilder: (context, index) {
                          final domain = _domains[index];
                          final isSelected =
                              _selectedDomain?.identifier == domain.identifier;
                          return ListTile.selectable(
                            leading: ToggleSwitch(
                              checked: domain.enabled,
                              onChanged: (_) => _toggleDomainEnabled(domain),
                            ),
                            title: Text(
                              'OSPF Process ${domain.processId}',
                              style: TextStyle(
                                color: domain.enabled ? null : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              '${domain.members.length} member(s), ${domain.areas.length} area(s)',
                            ),
                            selected: isSelected,
                            trailing: IconButton(
                              icon: const Icon(FluentIcons.delete, size: 14),
                              onPressed: () => _deleteOspfDomain(domain),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedDomain = isSelected ? null : domain;
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _selectedDomain == null
              ? const Center(
                  child: Text('Select an OSPF process to view details'),
                )
              : _OspfDomainDetails(
                  key: ValueKey(_selectedDomain!.identifier),
                  domain: _selectedDomain!,
                  devices: widget.devices,
                  project: widget.project,
                  onUpdated: (updated) {
                    _selectedDomain = updated;
                    setState(() {});
                  },
                ),
        ),
      ],
    );
  }
}

class _OspfDomainDetails extends StatefulWidget {
  const _OspfDomainDetails({
    super.key,
    required this.domain,
    required this.devices,
    required this.project,
    required this.onUpdated,
  });
  final OspfDomain domain;
  final List<NetDevice> devices;
  final Project project;
  final void Function(OspfDomain) onUpdated;

  @override
  State<_OspfDomainDetails> createState() => _OspfDomainDetailsState();
}

class _OspfDomainDetailsState extends State<_OspfDomainDetails> {
  int _selectedTab = 0;

  Future<void> _saveDomain(OspfDomain updatedDomain) async {
    final domains = widget.project.properties.ospfDomains
        .map(
          (d) => d.identifier == widget.domain.identifier ? updatedDomain : d,
        )
        .toList();
    await widget.project.updateProperties(
      widget.project.properties.copyWith(ospfDomains: domains),
    );
    widget.onUpdated(updatedDomain);
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

  NetDevice? _getDevice(int deviceId) {
    try {
      return widget.devices.firstWhere((d) => d.id == deviceId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FluentWidgets.mica(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'OSPF Process ${widget.domain.processId}',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(width: 8),
                if (!widget.domain.enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Disabled',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
              ],
            ),
            if (widget.domain.referenceBandwidth != null)
              Text(
                'Reference Bandwidth: ${widget.domain.referenceBandwidth} Mbps',
              ),
            const SizedBox(height: 16),
            Expanded(
              child: TabView(
                currentIndex: _selectedTab,
                onChanged: (i) => setState(() => _selectedTab = i),
                tabs: [
                  Tab(
                    text: const Text('Members'),
                    body: _MembersTab(
                      domain: widget.domain,
                      devices: widget.devices,
                      getDeviceName: _getDeviceName,
                      getDevice: _getDevice,
                      onSave: _saveDomain,
                    ),
                  ),
                  Tab(
                    text: const Text('Areas'),
                    body: _AreasTab(domain: widget.domain, onSave: _saveDomain),
                  ),
                  Tab(
                    text: const Text('Settings'),
                    body: _SettingsTab(
                      domain: widget.domain,
                      onSave: _saveDomain,
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

// Members Tab
class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.domain,
    required this.devices,
    required this.getDeviceName,
    required this.getDevice,
    required this.onSave,
  });

  final OspfDomain domain;
  final List<NetDevice> devices;
  final String Function(int) getDeviceName;
  final NetDevice? Function(int) getDevice;
  final Future<void> Function(OspfDomain) onSave;

  Future<void> _addMember(BuildContext context) async {
    if (devices.isEmpty) return;

    int? selectedDeviceId;
    final routerIdController = TextEditingController();

    final result = await showDialog<OspfMember>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add OSPF Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Device'),
              const SizedBox(height: 4),
              ComboBox<int>(
                value: selectedDeviceId,
                items: devices
                    .where(
                      (d) => !domain.members.any((m) => m.deviceId == d.id),
                    )
                    .map(
                      (d) => ComboBoxItem(value: d.id, child: Text(d.hostname)),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedDeviceId = v),
                placeholder: const Text('Select device'),
              ),
              const SizedBox(height: 12),
              const Text('Router ID (optional)'),
              const SizedBox(height: 4),
              SizedBox(
                width: 200,
                child: TextBox(
                  controller: routerIdController,
                  placeholder: 'e.g., 1.1.1.1 (auto if empty)',
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
                if (selectedDeviceId != null) {
                  Navigator.pop(
                    context,
                    OspfMember(
                      deviceId: selectedDeviceId!,
                      routerId: routerIdController.text.isNotEmpty
                          ? routerIdController.text.trim()
                          : null,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final updatedDomain = domain.copyWith(
        members: [...domain.members, result],
      );
      await onSave(updatedDomain);
    }
  }

  Future<void> _removeMember(BuildContext context, OspfMember member) async {
    final updatedDomain = domain.copyWith(
      members: domain.members
          .where((m) => m.deviceId != member.deviceId)
          .toList(),
    );
    await onSave(updatedDomain);
  }

  Future<void> _editMember(BuildContext context, OspfMember member) async {
    final device = getDevice(member.deviceId);
    if (device == null) return;

    await showDialog(
      context: context,
      builder: (context) => _MemberConfigDialog(
        member: member,
        device: device,
        domain: domain,
        onSave: onSave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CommandBar(
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('Add Member'),
              onPressed: () => _addMember(context),
            ),
          ],
        ),
        Expanded(
          child: domain.members.isEmpty
              ? const Center(child: Text('No members configured'))
              : ListView.builder(
                  itemCount: domain.members.length,
                  itemBuilder: (context, index) {
                    final member = domain.members[index];
                    final passiveCount = member.interfaceConfigs
                        .where((c) => c.passive)
                        .length;
                    return ListTile(
                      title: Text(getDeviceName(member.deviceId)),
                      subtitle: Text(
                        'Router ID: ${member.routerId ?? 'auto'} • '
                        '${member.networks.length} network(s) • '
                        '$passiveCount passive interface(s)',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(FluentIcons.settings, size: 14),
                            onPressed: () => _editMember(context, member),
                          ),
                          IconButton(
                            icon: const Icon(FluentIcons.delete, size: 14),
                            onPressed: () => _removeMember(context, member),
                          ),
                        ],
                      ),
                      onPressed: () => _editMember(context, member),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Member Configuration Dialog
class _MemberConfigDialog extends StatefulWidget {
  const _MemberConfigDialog({
    required this.member,
    required this.device,
    required this.domain,
    required this.onSave,
  });

  final OspfMember member;
  final NetDevice device;
  final OspfDomain domain;
  final Future<void> Function(OspfDomain) onSave;

  @override
  State<_MemberConfigDialog> createState() => _MemberConfigDialogState();
}

class _MemberConfigDialogState extends State<_MemberConfigDialog> {
  late OspfMember _editedMember;
  int _dialogTab = 0;

  @override
  void initState() {
    super.initState();
    _editedMember = widget.member;
  }

  Future<void> _save() async {
    final updatedDomain = widget.domain.copyWith(
      members: widget.domain.members
          .map((m) => m.deviceId == _editedMember.deviceId ? _editedMember : m)
          .toList(),
    );
    await widget.onSave(updatedDomain);
    if (mounted) Navigator.pop(context);
  }

  /// Convert subnet mask to wildcard mask
  String _subnetToWildcard(String subnetMask) {
    final parts = subnetMask.split('.');
    if (parts.length != 4) return '0.0.0.255';
    return parts
        .map((p) => (255 - (int.tryParse(p) ?? 0)).toString())
        .join('.');
  }

  /// Convert wildcard mask to prefix length
  int _wildcardToPrefix(String wildcard) {
    final parts = wildcard.split('.');
    if (parts.length != 4) return 24;
    // Convert wildcard to subnet mask, then to prefix
    final subnetParts = parts.map((p) => 255 - (int.tryParse(p) ?? 0)).toList();
    final subnetMask = subnetParts.join('.');
    return IPv4.subnetMaskToPrefixLength(subnetMask);
  }

  /// Get keys of interfaces whose networks are already added
  Set<String> _getUsedInterfaceKeys() {
    final usedKeys = <String>{};
    final addedNetworks = _editedMember.networks
        .map((n) => '${n.network}/${_wildcardToPrefix(n.wildcardMask)}')
        .toSet();

    // Check all interfaces (including tunnels) to find which ones match added networks
    final descriptors = InterfaceDescriptor.fromDevice(
      widget.device,
      includeTunnels: true,
    );
    for (final iface in descriptors) {
      if (iface.ipAddress != null) {
        final networkCidr = iface.ipAddress!.networkCIDR;
        if (addedNetworks.contains(networkCidr)) {
          usedKeys.add(iface.key);
        }
      }
    }
    return usedKeys;
  }

  Future<void> _addNetwork() async {
    final networkController = TextEditingController();
    final wildcardController = TextEditingController(text: '0.0.0.255');
    // Default to area 0 (backbone) if it exists, otherwise first area
    int areaId = widget.domain.areas.any((a) => a.areaId == 0)
        ? 0
        : (widget.domain.areas.isNotEmpty
              ? widget.domain.areas.first.areaId
              : 0);
    String? selectedInterfaceKey;

    final result = await showDialog<OspfNetwork>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final usedKeys = _getUsedInterfaceKeys();
          return ContentDialog(
            title: const Text('Add Network Statement'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Interface'),
                const SizedBox(height: 4),
                InterfaceSelector.layer3(
                  device: widget.device,
                  selectedKey: selectedInterfaceKey,
                  requireIpAddress: true,
                  includeTunnels: true,
                  excludeKeys: usedKeys,
                  placeholder: 'Select an interface',
                  onChanged: (iface) {
                    setDialogState(() {
                      selectedInterfaceKey = iface?.key;
                      if (iface?.ipAddress != null) {
                        // Calculate network address and wildcard mask
                        networkController.text =
                            iface!.ipAddress!.networkAddress;
                        wildcardController.text = _subnetToWildcard(
                          iface.ipAddress!.subnetMask,
                        );
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                const Text('Network'),
                const SizedBox(height: 4),
                TextBox(
                  controller: networkController,
                  placeholder: 'e.g., 192.168.1.0',
                ),
                const SizedBox(height: 12),
                const Text('Wildcard Mask'),
                const SizedBox(height: 4),
                TextBox(
                  controller: wildcardController,
                  placeholder: 'e.g., 0.0.0.255',
                ),
                const SizedBox(height: 12),
                const Text('Area ID'),
                const SizedBox(height: 4),
                ComboBox<int>(
                  value: areaId,
                  items: widget.domain.areas
                      .map(
                        (a) => ComboBoxItem(
                          value: a.areaId,
                          child: Text(
                            a.areaId == 0
                                ? 'Area 0 (Backbone)'
                                : 'Area ${a.areaId}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => areaId = v ?? 0),
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
                  if (networkController.text.isNotEmpty) {
                    Navigator.pop(
                      context,
                      OspfNetwork(
                        network: networkController.text.trim(),
                        wildcardMask: wildcardController.text.trim(),
                        areaId: areaId,
                      ),
                    );
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      setState(() {
        _editedMember = _editedMember.copyWith(
          networks: [..._editedMember.networks, result],
        );
      });
    }
  }

  void _removeNetwork(OspfNetwork network) {
    setState(() {
      _editedMember = _editedMember.copyWith(
        networks: _editedMember.networks.where((n) => n != network).toList(),
      );
    });
  }

  void _togglePassiveInterface(String interfaceName) {
    final existing = _editedMember.interfaceConfigs
        .where((c) => c.interfaceName == interfaceName)
        .firstOrNull;

    List<OspfInterfaceConfig> newConfigs;
    if (existing != null) {
      // Toggle passive state
      newConfigs = _editedMember.interfaceConfigs
          .map(
            (c) => c.interfaceName == interfaceName
                ? c.copyWith(passive: !c.passive)
                : c,
          )
          .toList();
    } else {
      // Add new config with passive = true
      newConfigs = [
        ..._editedMember.interfaceConfigs,
        OspfInterfaceConfig(interfaceName: interfaceName, passive: true),
      ];
    }

    setState(() {
      _editedMember = _editedMember.copyWith(interfaceConfigs: newConfigs);
    });
  }

  bool _isPassive(String interfaceName) {
    return _editedMember.interfaceConfigs.any(
      (c) => c.interfaceName == interfaceName && c.passive,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
      title: Text('Configure ${widget.device.hostname}'),
      content: SizedBox(
        height: 350,
        child: TabView(
          currentIndex: _dialogTab,
          onChanged: (i) => setState(() => _dialogTab = i),
          tabs: [
            Tab(text: const Text('Networks'), body: _buildNetworksTab()),
            Tab(
              text: const Text('Passive Interfaces'),
              body: _buildPassiveInterfacesTab(),
            ),
            Tab(text: const Text('Options'), body: _buildOptionsTab()),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _buildNetworksTab() {
    return Column(
      children: [
        CommandBar(
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('Add Network'),
              onPressed: _addNetwork,
            ),
          ],
        ),
        Expanded(
          child: _editedMember.networks.isEmpty
              ? const Center(child: Text('No networks configured'))
              : ListView.builder(
                  itemCount: _editedMember.networks.length,
                  itemBuilder: (context, index) {
                    final network = _editedMember.networks[index];
                    return ListTile(
                      title: Text('${network.network} ${network.wildcardMask}'),
                      subtitle: Text('Area ${network.areaId}'),
                      trailing: IconButton(
                        icon: const Icon(FluentIcons.delete, size: 14),
                        onPressed: () => _removeNetwork(network),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPassiveInterfacesTab() {
    final interfaces = widget.device.interfaces;
    return ListView.builder(
      itemCount: interfaces.length,
      itemBuilder: (context, index) {
        final iface = interfaces[index];
        final isPassive = _isPassive(iface.name);
        return ListTile(
          title: Text(iface.name),
          subtitle: Text(iface.description ?? ''),
          trailing: ToggleSwitch(
            checked: isPassive,
            onChanged: (_) => _togglePassiveInterface(iface.name),
          ),
        );
      },
    );
  }

  Widget _buildOptionsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            checked: _editedMember.defaultInformationOriginate,
            onChanged: (v) {
              setState(() {
                _editedMember = _editedMember.copyWith(
                  defaultInformationOriginate: v ?? false,
                );
              });
            },
            content: const Text('Default Information Originate'),
          ),
          const SizedBox(height: 8),
          Checkbox(
            checked: _editedMember.defaultInformationAlways,
            onChanged: _editedMember.defaultInformationOriginate
                ? (v) {
                    setState(() {
                      _editedMember = _editedMember.copyWith(
                        defaultInformationAlways: v ?? false,
                      );
                    });
                  }
                : null,
            content: const Text('Always (even without default route)'),
          ),
        ],
      ),
    );
  }
}

// Areas Tab
class _AreasTab extends StatelessWidget {
  const _AreasTab({required this.domain, required this.onSave});

  final OspfDomain domain;
  final Future<void> Function(OspfDomain) onSave;

  Future<void> _addArea(BuildContext context) async {
    final areaIdController = TextEditingController();
    OspfAreaType areaType = OspfAreaType.normal;
    bool noSummary = false;

    final result = await showDialog<OspfArea>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add OSPF Area'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Area ID'),
              const SizedBox(height: 4),
              SizedBox(
                width: 150,
                child: NumberBox<int>(
                  value: int.tryParse(areaIdController.text),
                  onChanged: (v) => areaIdController.text = v?.toString() ?? '',
                  min: 0,
                  placeholder: 'e.g., 0 for backbone',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Area Type'),
              const SizedBox(height: 4),
              ComboBox<OspfAreaType>(
                value: areaType,
                items: OspfAreaType.values
                    .map(
                      (t) =>
                          ComboBoxItem(value: t, child: Text(_areaTypeName(t))),
                    )
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => areaType = v ?? OspfAreaType.normal),
              ),
              if (areaType == OspfAreaType.stub ||
                  areaType == OspfAreaType.nssa) ...[
                const SizedBox(height: 8),
                Checkbox(
                  checked: noSummary,
                  onChanged: (v) =>
                      setDialogState(() => noSummary = v ?? false),
                  content: const Text('No Summary (Totally Stubby/NSSA)'),
                ),
              ],
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final areaId = int.tryParse(areaIdController.text) ?? 0;
                // Convert to totally stub/nssa if no summary is checked
                OspfAreaType finalType = areaType;
                if (noSummary) {
                  if (areaType == OspfAreaType.stub) {
                    finalType = OspfAreaType.totallyStub;
                  } else if (areaType == OspfAreaType.nssa) {
                    finalType = OspfAreaType.totallyNssa;
                  }
                }
                Navigator.pop(
                  context,
                  OspfArea(
                    areaId: areaId,
                    type: finalType,
                    noSummary: noSummary,
                  ),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final updatedDomain = domain.copyWith(areas: [...domain.areas, result]);
      await onSave(updatedDomain);
    }
  }

  Future<void> _removeArea(OspfArea area) async {
    final updatedDomain = domain.copyWith(
      areas: domain.areas.where((a) => a.areaId != area.areaId).toList(),
    );
    await onSave(updatedDomain);
  }

  static String _areaTypeName(OspfAreaType type) {
    switch (type) {
      case OspfAreaType.normal:
        return 'Normal';
      case OspfAreaType.stub:
        return 'Stub';
      case OspfAreaType.totallyStub:
        return 'Totally Stubby';
      case OspfAreaType.nssa:
        return 'NSSA';
      case OspfAreaType.totallyNssa:
        return 'Totally NSSA';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CommandBar(
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('Add Area'),
              onPressed: () => _addArea(context),
            ),
          ],
        ),
        Expanded(
          child: domain.areas.isEmpty
              ? const Center(child: Text('No areas configured'))
              : ListView.builder(
                  itemCount: domain.areas.length,
                  itemBuilder: (context, index) {
                    final area = domain.areas[index];
                    return ListTile(
                      title: Text(
                        area.areaId == 0
                            ? 'Area 0 (Backbone)'
                            : 'Area ${area.areaId}',
                      ),
                      subtitle: Text(_areaTypeName(area.type)),
                      trailing: area.areaId == 0
                          ? null
                          : IconButton(
                              icon: const Icon(FluentIcons.delete, size: 14),
                              onPressed: () => _removeArea(area),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Settings Tab
class _SettingsTab extends StatefulWidget {
  const _SettingsTab({required this.domain, required this.onSave});

  final OspfDomain domain;
  final Future<void> Function(OspfDomain) onSave;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  late TextEditingController _refBandwidthController;

  @override
  void initState() {
    super.initState();
    _refBandwidthController = TextEditingController(
      text: widget.domain.referenceBandwidth?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _refBandwidthController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final refBw = int.tryParse(_refBandwidthController.text);
    final updatedDomain = widget.domain.copyWith(referenceBandwidth: refBw);
    await widget.onSave(updatedDomain);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reference Bandwidth (Mbps)'),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 200,
                child: NumberBox<int>(
                  value: int.tryParse(_refBandwidthController.text),
                  onChanged: (v) {
                    _refBandwidthController.text = v?.toString() ?? '';
                  },
                  min: 1,
                  placeholder: 'Default: 100',
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _saveSettings, child: const Text('Save')),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Higher values allow better cost differentiation for high-speed links',
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      ),
    );
  }
}
