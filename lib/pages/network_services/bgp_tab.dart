import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/interface_descriptor.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/models/project.dart';
import 'package:ktracer_center/widgets/interface_selector.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class _BgpNetworkCandidate {
  const _BgpNetworkCandidate({required this.network, required this.mask});

  final String network;
  final String mask;

  String get key => '$network/$mask';
}

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
    return widget.devices.where((device) {
      final caps = device.preset.capabilities;
      return caps.contains('bgp');
    }).toList();
  }

  Future<void> _addBgpDomain() async {
    final asNumberController = TextEditingController(text: '65000');
    bool logNeighborChanges = true;

    final result = await showDialog<BgpDomain>(
      barrierDismissible: true,
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
                  onChanged: (value) =>
                      asNumberController.text = value?.toString() ?? '65000',
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
                onChanged: (value) =>
                    setDialogState(() => logNeighborChanges = value ?? true),
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
      barrierDismissible: true,
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
            .where((item) => item.identifier != domain.identifier)
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
    final updatedDomains = _domains.map((item) {
      return item.identifier == domain.identifier ? updatedDomain : item;
    }).toList();
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
                              '${domain.members.length} router(s)',
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
                  key: ValueKey(_selectedDomain!.identifier),
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
    super.key,
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

  InterfaceFilter get _neighborInterfaceFilter => const InterfaceFilter(
    requireIpAddress: true,
    includeTypes: {
      InterfaceType.physicalPort,
      InterfaceType.subinterface,
      InterfaceType.vlanSvi,
      InterfaceType.loopback,
      InterfaceType.tunnel,
    },
  );

  @override
  void didUpdateWidget(covariant _BgpDomainDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedMember != null) {
      _selectedMember = widget.domain.getMember(_selectedMember!.deviceId);
    }
  }

  NetDevice? _getDevice(int deviceId) {
    for (final device in widget.devices) {
      if (device.id == deviceId) {
        return device;
      }
    }
    return null;
  }

  String _getDeviceName(int deviceId) {
    return _getDevice(deviceId)?.hostname ?? 'Unknown';
  }

  List<InterfaceDescriptor> _getDeviceInterfaces(
    NetDevice device, {
    bool includeTunnels = false,
  }) {
    final interfaces = InterfaceDescriptor.fromDevice(
      device,
      includeTunnels: includeTunnels,
    );
    interfaces.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return interfaces;
  }

  InterfaceDescriptor? _findInterfaceByKey(
    List<InterfaceDescriptor> interfaces,
    String? key,
  ) {
    if (key == null) return null;
    for (final interface_ in interfaces) {
      if (interface_.key == key) {
        return interface_;
      }
    }
    return null;
  }

  InterfaceDescriptor? _findInterfaceByAddress(
    List<InterfaceDescriptor> interfaces,
    String address,
  ) {
    for (final interface_ in interfaces) {
      if (interface_.ipAddress?.address == address) {
        return interface_;
      }
    }
    return null;
  }

  List<InterfaceDescriptor> _getNeighborInterfaces(NetDevice device) {
    return _neighborInterfaceFilter.apply(
      _getDeviceInterfaces(device, includeTunnels: true),
    );
  }

  List<InterfaceDescriptor> _getAdvertisableInterfaces(NetDevice device) {
    return _getDeviceInterfaces(device, includeTunnels: true).where((iface) {
      if (!iface.isLayer3) return false;
      return iface.type == InterfaceType.physicalPort ||
          iface.type == InterfaceType.subinterface ||
          iface.type == InterfaceType.vlanSvi ||
          iface.type == InterfaceType.tunnel;
    }).toList();
  }

  List<_BgpNetworkCandidate> _getAdvertisableNetworkCandidates(
    BgpMember member,
  ) {
    final device = _getDevice(member.deviceId);
    if (device == null) return const [];

    final seen = <String>{};
    final candidates = <_BgpNetworkCandidate>[];

    for (final interface_ in _getAdvertisableInterfaces(device)) {
      if (interface_.usesDhcpForIpv4) continue;
      final ipAddress = interface_.ipAddress;
      if (ipAddress == null) continue;

      final candidate = _BgpNetworkCandidate(
        network: ipAddress.networkAddress,
        mask: ipAddress.subnetMask,
      );

      if (_networkExists(member, candidate.network, candidate.mask)) continue;
      if (seen.add(candidate.key)) {
        candidates.add(candidate);
      }
    }

    return candidates;
  }

  int _getDhcpLayer3InterfaceCount(BgpMember member) {
    final device = _getDevice(member.deviceId);
    if (device == null) return 0;
    return _getAdvertisableInterfaces(
      device,
    ).where((interface_) => interface_.usesDhcpForIpv4).length;
  }

  bool _networkExists(
    BgpMember member,
    String network,
    String mask, {
    BgpNetwork? exclude,
  }) {
    return member.networks.any((item) {
      if (exclude != null && item == exclude) {
        return false;
      }
      return item.network == network && item.mask == mask;
    });
  }

  List<BgpDomain> _getDomainsForDevice(int deviceId) {
    final matches = widget.project.properties.bgpDomains
        .where(
          (domain) =>
              domain.members.any((member) => member.deviceId == deviceId),
        )
        .toList();
    matches.sort((a, b) => a.asNumber.compareTo(b.asNumber));
    return matches;
  }

  Future<void> _ensurePeerDeviceHasBgpAs({
    required int? peerDeviceId,
    required int remoteAs,
  }) async {
    if (peerDeviceId == null) return;
    if (_getDomainsForDevice(peerDeviceId).isNotEmpty) {
      return;
    }

    final domains = [...widget.project.properties.bgpDomains];
    final domainIndex = domains.indexWhere(
      (domain) => domain.asNumber == remoteAs,
    );

    if (domainIndex >= 0) {
      final domain = domains[domainIndex];
      final alreadyMember = domain.members.any(
        (member) => member.deviceId == peerDeviceId,
      );
      if (!alreadyMember) {
        domains[domainIndex] = domain.copyWith(
          members: [
            ...domain.members,
            BgpMember(deviceId: peerDeviceId),
          ],
        );
      }
    } else {
      domains.add(
        BgpDomain(
          asNumber: remoteAs,
          members: [BgpMember(deviceId: peerDeviceId)],
        ),
      );
    }

    await widget.project.updateProperties(
      widget.project.properties.copyWith(bgpDomains: domains),
    );
  }

  NetDevice? _getNeighborDevice(BgpNeighbor neighbor) {
    if (neighbor.neighborDeviceId != null) {
      return _getDevice(neighbor.neighborDeviceId!);
    }

    final matches = <NetDevice>[];
    for (final device in widget.devices) {
      final hasMatchingAddress = _getNeighborInterfaces(device).any(
        (interface_) =>
            interface_.ipAddress?.address == neighbor.neighborAddress,
      );
      if (hasMatchingAddress) {
        matches.add(device);
      }
    }

    return matches.length == 1 ? matches.first : null;
  }

  InterfaceDescriptor? _getNeighborInterface(BgpNeighbor neighbor) {
    final device = _getNeighborDevice(neighbor);
    if (device == null) return null;

    final interfaces = _getNeighborInterfaces(device);
    return _findInterfaceByKey(interfaces, neighbor.neighborInterfaceKey) ??
        _findInterfaceByAddress(interfaces, neighbor.neighborAddress);
  }

  String _getNeighborTitle(BgpNeighbor neighbor) {
    final device = _getNeighborDevice(neighbor);
    final interface_ = _getNeighborInterface(neighbor);

    if (device != null && interface_ != null) {
      return '${device.hostname} • ${interface_.displayName}';
    }
    if (device != null) {
      return device.hostname;
    }
    return neighbor.neighborAddress;
  }

  String _getNeighborSubtitle(BgpNeighbor neighbor) {
    final interface_ = _getNeighborInterface(neighbor);
    final details = <String>['Remote AS: ${neighbor.remoteAs}'];
    details.add(interface_?.ipAddress?.address ?? neighbor.neighborAddress);
    if (neighbor.description?.trim().isNotEmpty ?? false) {
      details.add(neighbor.description!.trim());
    }
    return details.join(' • ');
  }

  Future<void> _updateDomain(BgpDomain updated) async {
    final domains = widget.project.properties.bgpDomains.map((domain) {
      return domain.identifier == widget.domain.identifier ? updated : domain;
    }).toList();
    await widget.project.updateProperties(
      widget.project.properties.copyWith(bgpDomains: domains),
    );
    widget.onUpdated(updated);
  }

  BgpDomain _getCurrentDomain() {
    for (final domain in widget.project.properties.bgpDomains) {
      if (domain.identifier == widget.domain.identifier) {
        return domain;
      }
    }
    return widget.domain;
  }

  Future<void> _replaceMember(BgpMember updatedMember) async {
    final currentDomain = _getCurrentDomain();
    final updatedMembers = currentDomain.members.map((member) {
      return member.deviceId == updatedMember.deviceId ? updatedMember : member;
    }).toList();
    await _updateDomain(currentDomain.copyWith(members: updatedMembers));
    setState(() => _selectedMember = updatedMember);
  }

  Future<void> _addMember() async {
    final availableDevices =
        widget.devices
            .where(
              (device) =>
                  !widget.domain.members.any((m) => m.deviceId == device.id),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.hostname.toLowerCase().compareTo(b.hostname.toLowerCase()),
          );

    if (availableDevices.isEmpty) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('No available devices'),
          content: const Text(
            'All BGP-capable devices are already participating in this AS.',
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
      barrierDismissible: true,
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add Router to AS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Router'),
              const SizedBox(height: 4),
              ComboBox<NetDevice>(
                value: selectedDevice,
                items: availableDevices
                    .map(
                      (device) => ComboBoxItem(
                        value: device,
                        child: Text(device.hostname),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => selectedDevice = value),
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
      await _updateDomain(
        widget.domain.copyWith(members: [...widget.domain.members, result]),
      );
      setState(() => _selectedMember = result);
    }
  }

  Future<void> _removeMember(BgpMember member) async {
    final updated = widget.domain.copyWith(
      members: widget.domain.members
          .where((item) => item.deviceId != member.deviceId)
          .toList(),
    );
    if (_selectedMember?.deviceId == member.deviceId) {
      _selectedMember = null;
    }
    await _updateDomain(updated);
    setState(() {});
  }

  Future<BgpNeighbor?> _showNeighborDialog(
    BgpMember member, {
    BgpNeighbor? initial,
  }) async {
    final availableDevices =
        widget.devices.where((device) => device.id != member.deviceId).toList()
          ..sort(
            (a, b) =>
                a.hostname.toLowerCase().compareTo(b.hostname.toLowerCase()),
          );

    if (availableDevices.isEmpty) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('No peer devices available'),
          content: const Text(
            'Add another BGP-capable device to the project before creating a neighbor.',
          ),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return null;
    }

    int? selectedDeviceId = initial?.neighborDeviceId;
    String? selectedInterfaceKey = initial?.neighborInterfaceKey;

    if (initial != null && selectedDeviceId == null) {
      selectedDeviceId = _getNeighborDevice(initial)?.id;
      selectedInterfaceKey = _getNeighborInterface(initial)?.key;
    }

    int? selectedRemoteAs = initial?.remoteAs;
    final descController = TextEditingController(
      text: initial?.description ?? '',
    );
    final updateSourceController = TextEditingController(
      text: initial?.updateSource ?? '',
    );
    bool ebgpMultihop = initial?.ebgpMultihop ?? false;
    int multihopTtl = initial?.ebgpMultihopTtl ?? 2;
    bool nextHopSelf = initial?.nextHopSelf ?? false;

    final result = await showDialog<BgpNeighbor>(
      barrierDismissible: true,
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          NetDevice? selectedDevice;
          for (final device in availableDevices) {
            if (device.id == selectedDeviceId) {
              selectedDevice = device;
              break;
            }
          }

          final selectableInterfaces = selectedDevice == null
              ? const <InterfaceDescriptor>[]
              : _getNeighborInterfaces(selectedDevice);
          final selectedInterface = _findInterfaceByKey(
            selectableInterfaces,
            selectedInterfaceKey,
          );
          final selectedDeviceDomains = selectedDeviceId == null
              ? const <BgpDomain>[]
              : _getDomainsForDevice(selectedDeviceId!);
          final selectableAsNumbers =
              selectedDeviceDomains
                  .map((domain) => domain.asNumber)
                  .toSet()
                  .toList()
                ..sort();
          final hasDetectedAses = selectableAsNumbers.isNotEmpty;

          if (hasDetectedAses) {
            if (selectedRemoteAs == null ||
                !selectableAsNumbers.contains(selectedRemoteAs)) {
              selectedRemoteAs = selectableAsNumbers.first;
            }
          }

          return ContentDialog(
            title: Text(
              initial == null ? 'Add BGP Neighbor' : 'Edit BGP Neighbor',
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Neighbor Device'),
                    const SizedBox(height: 4),
                    ComboBox<int>(
                      value: selectedDeviceId,
                      isExpanded: true,
                      popupColor: FluentTheme.of(context).menuColor,
                      placeholder: const Text('Select a device'),
                      items: availableDevices
                          .map(
                            (device) => ComboBoxItem<int>(
                              value: device.id,
                              child: Text(
                                '${device.hostname} (${device.name})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        final detectedDomains = value == null
                            ? const <BgpDomain>[]
                            : _getDomainsForDevice(value);
                        final detectedAsNumbers =
                            detectedDomains
                                .map((domain) => domain.asNumber)
                                .toSet()
                                .toList()
                              ..sort();

                        setDialogState(() {
                          selectedDeviceId = value;
                          selectedInterfaceKey = null;
                          if (detectedAsNumbers.isEmpty) {
                            selectedRemoteAs = null;
                          } else {
                            selectedRemoteAs = detectedAsNumbers.first;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Neighbor Interface'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 220,
                      child: selectedDevice == null
                          ? const InfoBar(
                              title: Text(
                                'Select a device to choose its peering interface.',
                              ),
                              severity: InfoBarSeverity.info,
                            )
                          : InterfaceSelector(
                              device: selectedDevice,
                              selectedKey: selectedInterfaceKey,
                              mode: InterfaceSelectorMode.list,
                              includeTunnels: true,
                              filter: _neighborInterfaceFilter,
                              emptyMessage:
                                  'No routed IPv4 interfaces are available on this device.',
                              onChanged: (interface_) {
                                setDialogState(
                                  () => selectedInterfaceKey = interface_?.key,
                                );
                              },
                            ),
                    ),
                    if (selectedInterface?.ipAddress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Resolved neighbor IP: ${selectedInterface!.ipAddress!.address}',
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (hasDetectedAses) ...[
                      const Text('Remote AS (from selected device)'),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 220,
                        child: ComboBox<int>(
                          value: selectableAsNumbers.contains(selectedRemoteAs)
                              ? selectedRemoteAs
                              : null,
                          isExpanded: true,
                          placeholder: const Text('Select AS'),
                          items: selectableAsNumbers
                              .map(
                                (asNumber) => ComboBoxItem<int>(
                                  value: asNumber,
                                  child: Text('AS $asNumber'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedRemoteAs = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Detected from project BGP memberships for this device.',
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ] else ...[
                      const Text('Remote AS Number'),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 150,
                        child: NumberBox<int>(
                          value: selectedRemoteAs,
                          onChanged: (value) {
                            setDialogState(() => selectedRemoteAs = value);
                          },
                          min: 1,
                          max: 65535,
                          placeholder: 'AS number',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This device has no BGP AS membership yet. Saving will create/add it under the AS you enter.',
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
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
                      onChanged: (value) =>
                          setDialogState(() => ebgpMultihop = value ?? false),
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
                              onChanged: (value) => setDialogState(
                                () => multihopTtl = value ?? 2,
                              ),
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
                      onChanged: (value) =>
                          setDialogState(() => nextHopSelf = value ?? false),
                      content: const Text('Next-Hop-Self'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final neighborInterface = selectedInterface;
                  final remoteAs = selectedRemoteAs;
                  if (selectedDevice == null || remoteAs == null) {
                    return;
                  }
                  if (neighborInterface == null ||
                      neighborInterface.ipAddress == null) {
                    return;
                  }

                  final neighborIp = neighborInterface.ipAddress!.address;

                  Navigator.pop(
                    context,
                    BgpNeighbor(
                      neighborAddress: neighborIp,
                      neighborDeviceId: selectedDevice.id,
                      neighborInterfaceKey: neighborInterface.key,
                      remoteAs: remoteAs,
                      description: descController.text.trim().isNotEmpty
                          ? descController.text.trim()
                          : null,
                      updateSource:
                          updateSourceController.text.trim().isNotEmpty
                          ? updateSourceController.text.trim()
                          : null,
                      ebgpMultihop: ebgpMultihop,
                      ebgpMultihopTtl: ebgpMultihop ? multihopTtl : null,
                      nextHopSelf: nextHopSelf,
                    ),
                  );
                },
                child: Text(initial == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  Future<void> _addNeighborToMember(BgpMember member) async {
    final result = await _showNeighborDialog(member);

    if (result != null) {
      await _ensurePeerDeviceHasBgpAs(
        peerDeviceId: result.neighborDeviceId,
        remoteAs: result.remoteAs,
      );
      await _replaceMember(
        member.copyWith(neighbors: [...member.neighbors, result]),
      );
    }
  }

  Future<void> _editNeighborForMember(
    BgpMember member,
    int index,
    BgpNeighbor neighbor,
  ) async {
    final result = await _showNeighborDialog(member, initial: neighbor);
    if (result == null) return;

    await _ensurePeerDeviceHasBgpAs(
      peerDeviceId: result.neighborDeviceId,
      remoteAs: result.remoteAs,
    );

    final updatedNeighbors = [...member.neighbors];
    updatedNeighbors[index] = result;
    await _replaceMember(member.copyWith(neighbors: updatedNeighbors));
  }

  Future<void> _removeNeighborFromMember(
    BgpMember member,
    BgpNeighbor neighbor,
  ) async {
    await _replaceMember(
      member.copyWith(
        neighbors: member.neighbors.where((item) => item != neighbor).toList(),
      ),
    );
  }

  Future<BgpNetwork?> _showNetworkDialog(
    BgpMember member, {
    BgpNetwork? initial,
  }) async {
    final networkController = TextEditingController(
      text: initial?.network ?? '',
    );
    final maskController = TextEditingController(text: initial?.mask ?? '');
    final candidates = _getAdvertisableNetworkCandidates(member);
    final dhcpInterfaceCount = _getDhcpLayer3InterfaceCount(member);
    String? selectedCandidateKey;
    String? validationMessage;

    final result = await showDialog<BgpNetwork>(
      barrierDismissible: true,
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: Text(
            initial == null
                ? 'Add Advertised Network'
                : 'Edit Advertised Network',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dhcpInterfaceCount > 0)
                    InfoBar(
                      title: const Text('DHCP interfaces are excluded'),
                      content: const Text(
                        'BGP network statements should be deterministic. DHCP-assigned interfaces are not listed as candidates.',
                      ),
                      severity: InfoBarSeverity.info,
                    ),
                  if (candidates.isNotEmpty) ...[
                    const Text('Candidate Networks (IP + Mask)'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          final isSelected =
                              selectedCandidateKey == candidate.key;
                          return ListTile.selectable(
                            title: Text(candidate.network),
                            subtitle: Text('Mask: ${candidate.mask}'),
                            selected: isSelected,
                            onPressed: () {
                              setDialogState(() {
                                selectedCandidateKey = candidate.key;
                                networkController.text = candidate.network;
                                maskController.text = candidate.mask;
                                validationMessage = null;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Network Address'),
                  const SizedBox(height: 4),
                  TextBox(
                    controller: networkController,
                    placeholder: 'e.g., 10.10.10.0',
                    onChanged: (_) =>
                        setDialogState(() => validationMessage = null),
                  ),
                  const SizedBox(height: 12),
                  const Text('Subnet Mask'),
                  const SizedBox(height: 4),
                  TextBox(
                    controller: maskController,
                    placeholder: 'e.g., 255.255.255.0',
                    onChanged: (_) =>
                        setDialogState(() => validationMessage = null),
                  ),
                  if (validationMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      validationMessage!,
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
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
                if (network.isEmpty || mask.isEmpty) {
                  setDialogState(
                    () => validationMessage =
                        'Both network and mask are required.',
                  );
                  return;
                }
                if (_networkExists(member, network, mask, exclude: initial)) {
                  setDialogState(
                    () => validationMessage =
                        'This network/mask is already being advertised.',
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  BgpNetwork(network: network, mask: mask),
                );
              },
              child: Text(initial == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    return result;
  }

  Future<void> _addNetworkToMember(BgpMember member) async {
    final result = await _showNetworkDialog(member);
    if (result == null) return;
    await _replaceMember(
      member.copyWith(networks: [...member.networks, result]),
    );
  }

  Future<void> _editNetworkForMember(
    BgpMember member,
    int index,
    BgpNetwork network,
  ) async {
    final result = await _showNetworkDialog(member, initial: network);
    if (result == null) return;

    final updatedNetworks = [...member.networks];
    updatedNetworks[index] = result;
    await _replaceMember(member.copyWith(networks: updatedNetworks));
  }

  Future<void> _removeNetworkFromMember(
    BgpMember member,
    BgpNetwork network,
  ) async {
    await _replaceMember(
      member.copyWith(
        networks: member.networks.where((item) => item != network).toList(),
      ),
    );
  }

  Widget _buildAdvertisedNetworks(BgpMember member) {
    if (member.networks.isEmpty) {
      return const Center(child: Text('No advertised networks configured'));
    }

    return ListView.builder(
      itemCount: member.networks.length,
      itemBuilder: (context, index) {
        final network = member.networks[index];
        return ListTile(
          title: Text(network.network),
          subtitle: Text(
            'Mask: ${network.mask ?? 'classful'}'
            '${network.routeMap != null ? ' • Route-map: ${network.routeMap}' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(FluentIcons.edit, size: 14),
                onPressed: () => _editNetworkForMember(member, index, network),
              ),
              IconButton(
                icon: const Icon(FluentIcons.delete, size: 14),
                onPressed: () => _removeNetworkFromMember(member, network),
              ),
            ],
          ),
        );
      },
    );
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
                  SizedBox(
                    width: 250,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CommandBar(
                          primaryItems: [
                            CommandBarButton(
                              icon: const Icon(FluentIcons.add),
                              label: const Text('Add Router'),
                              onPressed: _addMember,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Routers in this AS',
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: domain.members.isEmpty
                              ? const Center(
                                  child: Text('No routers configured'),
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
                  Expanded(
                    child: FluentWidgets.mica(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _selectedMember == null
                            ? const Center(
                                child: Text('Select a router to view details'),
                              )
                            : _buildMemberDetails(_selectedMember!),
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

  Widget _buildMemberDetails(BgpMember member) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getDeviceName(member.deviceId),
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 16),
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
                            title: Text(_getNeighborTitle(neighbor)),
                            subtitle: Text(_getNeighborSubtitle(neighbor)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(FluentIcons.edit, size: 14),
                                  onPressed: () => _editNeighborForMember(
                                    member,
                                    index,
                                    neighbor,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    FluentIcons.delete,
                                    size: 14,
                                  ),
                                  onPressed: () => _removeNeighborFromMember(
                                    member,
                                    neighbor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Advertised Networks'),
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
              Expanded(child: _buildAdvertisedNetworks(member)),
            ],
          ),
        ),
      ],
    );
  }
}
