import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/models/project.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class BgpTab extends StatefulWidget {
  const BgpTab({super.key, required this.project, required this.devices});
  final Project project;
  final List<NetDevice> devices;

  @override
  State<BgpTab> createState() => _BgpTabState();
}

class _BgpTabState extends State<BgpTab> {
  BgpDomain? _selectedDomain;

  List<BgpDomain> get _domains => widget.project.properties.bgpDomains;

  List<NetDevice> get _bgpCapableDevices {
    return widget.devices.where((d) {
      final caps = d.preset.capabilities;
      return caps.contains('bgp');
    }).toList();
  }

  Future<void> _addBgpDomain() async {
    final asNumberController = TextEditingController(text: '65000');
    bool logNeighborChanges = true;

    final result = await showDialog<BgpDomain>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add BGP Domain'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AS Number'),
              const SizedBox(height: 4),
              SizedBox(
                width: 200,
                child: NumberBox<int>(
                  value: int.tryParse(asNumberController.text) ?? 65000,
                  onChanged: (v) =>
                      asNumberController.text = v?.toString() ?? '65000',
                  min: 1,
                  max: 65535,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Private AS range: 64512-65534',
                style: FluentTheme.of(context).typography.caption,
              ),
              const SizedBox(height: 12),
              Checkbox(
                checked: logNeighborChanges,
                onChanged: (v) =>
                    setDialogState(() => logNeighborChanges = v ?? true),
                content: const Text('Log Neighbor Changes'),
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
                final asNumber = int.tryParse(asNumberController.text) ?? 65000;
                Navigator.pop(
                  context,
                  BgpDomain(
                    asNumber: asNumber,
                    logNeighborChanges: logNeighborChanges,
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
      final updated = widget.project.properties.copyWith(
        bgpDomains: [..._domains, result],
      );
      await widget.project.updateProperties(updated);
      setState(() => _selectedDomain = result);
    }
  }

  Future<void> _deleteBgpDomain(BgpDomain domain) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete BGP Domain'),
        content: Text(
          'Are you sure you want to delete BGP AS ${domain.asNumber}?',
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
        bgpDomains: _domains
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

  Future<void> _toggleDomainEnabled(BgpDomain domain) async {
    final updatedDomain = domain.copyWith(enabled: !domain.enabled);
    final updatedDomains = _domains
        .map((d) => d.identifier == domain.identifier ? updatedDomain : d)
        .toList();
    await widget.project.updateProperties(
      widget.project.properties.copyWith(bgpDomains: updatedDomains),
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
                    label: const Text('Add AS'),
                    onPressed: _addBgpDomain,
                  ),
                ],
              ),
              Expanded(
                child: _domains.isEmpty
                    ? const Center(child: Text('No BGP domains configured'))
                    : ListView.builder(
                        itemCount: _domains.length,
                        itemBuilder: (context, index) {
                          final domain = _domains[index];
                          return ListTile.selectable(
                            leading: Icon(
                              domain.enabled
                                  ? FluentIcons.check_mark
                                  : FluentIcons.cancel,
                              size: 12,
                              color: domain.enabled ? Colors.green : Colors.red,
                            ),
                            title: Text('BGP AS ${domain.asNumber}'),
                            subtitle: Text(
                              '${domain.members.length} member(s)',
                            ),
                            selected:
                                _selectedDomain?.identifier ==
                                domain.identifier,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ToggleSwitch(
                                  checked: domain.enabled,
                                  onChanged: (_) =>
                                      _toggleDomainEnabled(domain),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    FluentIcons.delete,
                                    size: 14,
                                  ),
                                  onPressed: () => _deleteBgpDomain(domain),
                                ),
                              ],
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedDomain =
                                    _selectedDomain?.identifier ==
                                        domain.identifier
                                    ? null
                                    : domain;
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
              ? const Center(child: Text('Select a BGP domain to view details'))
              : _BgpDomainDetails(
                  domain: _selectedDomain!,
                  devices: _bgpCapableDevices,
                  project: widget.project,
                  onUpdated: (updated) {
                    setState(() => _selectedDomain = updated);
                  },
                ),
        ),
      ],
    );
  }
}

class _BgpDomainDetails extends StatefulWidget {
  const _BgpDomainDetails({
    required this.domain,
    required this.devices,
    required this.project,
    required this.onUpdated,
  });
  final BgpDomain domain;
  final List<NetDevice> devices;
  final Project project;
  final void Function(BgpDomain) onUpdated;

  @override
  State<_BgpDomainDetails> createState() => _BgpDomainDetailsState();
}

class _BgpDomainDetailsState extends State<_BgpDomainDetails> {
  BgpMember? _selectedMember;

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

  Future<void> _updateDomain(BgpDomain updated) async {
    final domains = widget.project.properties.bgpDomains
        .map((d) => d.identifier == widget.domain.identifier ? updated : d)
        .toList();
    await widget.project.updateProperties(
      widget.project.properties.copyWith(bgpDomains: domains),
    );
    widget.onUpdated(updated);
  }

  Future<void> _addMember() async {
    final availableDevices = widget.devices
        .where((d) => !widget.domain.members.any((m) => m.deviceId == d.id))
        .toList();

    if (availableDevices.isEmpty) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('No available devices'),
          content: const Text(
            'All BGP-capable devices are already members of this domain.',
          ),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return;
    }

    NetDevice? selectedDevice = availableDevices.first;
    final routerIdController = TextEditingController();

    final result = await showDialog<BgpMember>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add BGP Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Device'),
              const SizedBox(height: 4),
              ComboBox<NetDevice>(
                value: selectedDevice,
                items: availableDevices
                    .map((d) => ComboBoxItem(value: d, child: Text(d.hostname)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedDevice = v),
              ),
              const SizedBox(height: 12),
              const Text('Router ID (optional)'),
              const SizedBox(height: 4),
              SizedBox(
                width: 200,
                child: TextBox(
                  controller: routerIdController,
                  placeholder: 'e.g., 1.1.1.1',
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
                if (selectedDevice == null) return;
                final routerId = routerIdController.text.trim();
                Navigator.pop(
                  context,
                  BgpMember(
                    deviceId: selectedDevice!.id,
                    routerId: routerId.isNotEmpty ? routerId : null,
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
      final updated = widget.domain.copyWith(
        members: [...widget.domain.members, result],
      );
      await _updateDomain(updated);
    }
  }

  Future<void> _removeMember(BgpMember member) async {
    final updated = widget.domain.copyWith(
      members: widget.domain.members
          .where((m) => m.deviceId != member.deviceId)
          .toList(),
    );
    if (_selectedMember?.deviceId == member.deviceId) {
      _selectedMember = null;
    }
    await _updateDomain(updated);
    setState(() {});
  }

  Future<void> _addNeighborToMember(BgpMember member) async {
    final ipController = TextEditingController();
    final remoteAsController = TextEditingController();
    final descController = TextEditingController();
    final updateSourceController = TextEditingController();
    bool ebgpMultihop = false;
    int multihopTtl = 2;
    bool nextHopSelf = false;

    final result = await showDialog<BgpNeighbor>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add BGP Neighbor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Neighbor IP Address'),
                const SizedBox(height: 4),
                SizedBox(
                  width: 200,
                  child: TextBox(
                    controller: ipController,
                    placeholder: 'e.g., 10.0.0.2',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Remote AS Number'),
                const SizedBox(height: 4),
                SizedBox(
                  width: 150,
                  child: NumberBox<int>(
                    value: int.tryParse(remoteAsController.text),
                    onChanged: (v) =>
                        remoteAsController.text = v?.toString() ?? '',
                    min: 1,
                    max: 65535,
                    placeholder: 'AS number',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Description (optional)'),
                const SizedBox(height: 4),
                SizedBox(
                  width: 300,
                  child: TextBox(
                    controller: descController,
                    placeholder: 'e.g., Peer to ISP',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Update Source (optional)'),
                const SizedBox(height: 4),
                SizedBox(
                  width: 200,
                  child: TextBox(
                    controller: updateSourceController,
                    placeholder: 'e.g., Loopback0',
                  ),
                ),
                const SizedBox(height: 12),
                Checkbox(
                  checked: ebgpMultihop,
                  onChanged: (v) =>
                      setDialogState(() => ebgpMultihop = v ?? false),
                  content: const Text('eBGP Multihop'),
                ),
                if (ebgpMultihop) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('TTL: '),
                      SizedBox(
                        width: 80,
                        child: NumberBox<int>(
                          value: multihopTtl,
                          onChanged: (v) =>
                              setDialogState(() => multihopTtl = v ?? 2),
                          min: 2,
                          max: 255,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Checkbox(
                  checked: nextHopSelf,
                  onChanged: (v) =>
                      setDialogState(() => nextHopSelf = v ?? false),
                  content: const Text('Next-Hop-Self'),
                ),
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final ip = ipController.text.trim();
                final remoteAs = int.tryParse(remoteAsController.text);
                if (ip.isEmpty || remoteAs == null) return;
                Navigator.pop(
                  context,
                  BgpNeighbor(
                    neighborAddress: ip,
                    remoteAs: remoteAs,
                    description: descController.text.trim().isNotEmpty
                        ? descController.text.trim()
                        : null,
                    updateSource: updateSourceController.text.trim().isNotEmpty
                        ? updateSourceController.text.trim()
                        : null,
                    ebgpMultihop: ebgpMultihop,
                    ebgpMultihopTtl: ebgpMultihop ? multihopTtl : null,
                    nextHopSelf: nextHopSelf,
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
      final updatedMember = member.copyWith(
        neighbors: [...member.neighbors, result],
      );
      final updatedMembers = widget.domain.members
          .map((m) => m.deviceId == member.deviceId ? updatedMember : m)
          .toList();
      final updated = widget.domain.copyWith(members: updatedMembers);
      await _updateDomain(updated);
      setState(() => _selectedMember = updatedMember);
    }
  }

  Future<void> _addNetworkToMember(BgpMember member) async {
    final networkController = TextEditingController();
    final maskController = TextEditingController();

    final result = await showDialog<BgpNetwork>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Advertise Network'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Network Address'),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: TextBox(
                controller: networkController,
                placeholder: 'e.g., 192.168.1.0',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Subnet Mask'),
            const SizedBox(height: 4),
            SizedBox(
              width: 200,
              child: TextBox(
                controller: maskController,
                placeholder: 'e.g., 255.255.255.0',
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
              final network = networkController.text.trim();
              final mask = maskController.text.trim();
              if (network.isEmpty || mask.isEmpty) return;
              Navigator.pop(context, BgpNetwork(network: network, mask: mask));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updatedMember = member.copyWith(
        networks: [...member.networks, result],
      );
      final updatedMembers = widget.domain.members
          .map((m) => m.deviceId == member.deviceId ? updatedMember : m)
          .toList();
      final updated = widget.domain.copyWith(members: updatedMembers);
      await _updateDomain(updated);
      setState(() => _selectedMember = updatedMember);
    }
  }

  @override
  Widget build(BuildContext context) {
    final domain = widget.domain;

    return FluentWidgets.mica(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BGP AS ${domain.asNumber}',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Members list
                  SizedBox(
                    width: 250,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CommandBar(
                          primaryItems: [
                            CommandBarButton(
                              icon: const Icon(FluentIcons.add),
                              label: const Text('Add Member'),
                              onPressed: _addMember,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Members',
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: domain.members.isEmpty
                              ? const Center(
                                  child: Text('No members configured'),
                                )
                              : ListView.builder(
                                  itemCount: domain.members.length,
                                  itemBuilder: (context, index) {
                                    final member = domain.members[index];
                                    return ListTile.selectable(
                                      title: Text(
                                        _getDeviceName(member.deviceId),
                                      ),
                                      subtitle: Text(
                                        'Router ID: ${member.routerId ?? 'auto'}\n'
                                        '${member.neighbors.length} neighbor(s), '
                                        '${member.networks.length} network(s)',
                                      ),
                                      selected:
                                          _selectedMember?.deviceId ==
                                          member.deviceId,
                                      trailing: IconButton(
                                        icon: const Icon(
                                          FluentIcons.delete,
                                          size: 14,
                                        ),
                                        onPressed: () => _removeMember(member),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedMember =
                                              _selectedMember?.deviceId ==
                                                  member.deviceId
                                              ? null
                                              : member;
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Member details
                  Expanded(
                    child: _selectedMember == null
                        ? const Center(
                            child: Text('Select a member to view details'),
                          )
                        : _buildMemberDetails(_selectedMember!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberDetails(BgpMember member) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getDeviceName(member.deviceId),
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 16),
        // Neighbors
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Neighbors'),
                  Button(
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('Add'),
                      ],
                    ),
                    onPressed: () => _addNeighborToMember(member),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: member.neighbors.isEmpty
                    ? const Center(child: Text('No neighbors'))
                    : ListView.builder(
                        itemCount: member.neighbors.length,
                        itemBuilder: (context, index) {
                          final neighbor = member.neighbors[index];
                          return ListTile(
                            title: Text(neighbor.neighborAddress),
                            subtitle: Text(
                              'Remote AS: ${neighbor.remoteAs}'
                              '${neighbor.description != null ? ' - ${neighbor.description}' : ''}',
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Networks
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Networks'),
                  Button(
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('Add'),
                      ],
                    ),
                    onPressed: () => _addNetworkToMember(member),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: member.networks.isEmpty
                    ? const Center(child: Text('No networks'))
                    : ListView.builder(
                        itemCount: member.networks.length,
                        itemBuilder: (context, index) {
                          final network = member.networks[index];
                          return ListTile(
                            title: Text(network.network),
                            subtitle: Text('Mask: ${network.mask}'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
