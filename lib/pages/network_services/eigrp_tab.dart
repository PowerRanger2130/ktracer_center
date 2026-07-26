import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/models/project.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class EigrpTab extends StatefulWidget {
  const EigrpTab({super.key, required this.project, required this.devices});
  final Project project;
  final List<NetDevice> devices;

  @override
  State<EigrpTab> createState() => _EigrpTabState();
}

class _EigrpTabState extends State<EigrpTab> {
  EigrpDomain? _selectedDomain;

  Future<void> _addEigrpDomain() async {
    final asNumberController = TextEditingController(text: '1');
    bool namedMode = false;
    final nameController = TextEditingController();

    final result = await showDialog<EigrpDomain>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add EIGRP Domain'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AS Number'),
              const SizedBox(height: 4),
              SizedBox(
                width: 150,
                child: NumberBox<int>(
                  value: int.tryParse(asNumberController.text) ?? 1,
                  onChanged: (v) =>
                      asNumberController.text = v?.toString() ?? '1',
                  min: 1,
                  max: 65535,
                ),
              ),
              const SizedBox(height: 12),
              Checkbox(
                checked: namedMode,
                onChanged: (v) => setDialogState(() => namedMode = v ?? false),
                content: const Text('Named Mode'),
              ),
              if (namedMode) ...[
                const SizedBox(height: 8),
                const Text('Instance Name'),
                const SizedBox(height: 4),
                SizedBox(
                  width: 200,
                  child: TextBox(
                    controller: nameController,
                    placeholder: 'e.g., CORP',
                  ),
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
                final asNumber = int.tryParse(asNumberController.text) ?? 1;
                Navigator.pop(
                  context,
                  EigrpDomain(
                    asNumber: asNumber,
                    namedMode: namedMode,
                    namedInstanceName:
                        namedMode && nameController.text.isNotEmpty
                        ? nameController.text.trim()
                        : null,
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
        eigrpDomains: [...widget.project.properties.eigrpDomains, result],
      );
      await widget.project.updateProperties(updated);
      setState(() {});
    }
  }

  Future<void> _deleteEigrpDomain(EigrpDomain domain) async {
    final updated = widget.project.properties.copyWith(
      eigrpDomains: widget.project.properties.eigrpDomains
          .where((d) => d.identifier != domain.identifier)
          .toList(),
    );
    await widget.project.updateProperties(updated);
    if (_selectedDomain?.identifier == domain.identifier) {
      _selectedDomain = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final domains = widget.project.properties.eigrpDomains;

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
                    onPressed: _addEigrpDomain,
                  ),
                ],
              ),
              Expanded(
                child: domains.isEmpty
                    ? const Center(child: Text('No EIGRP domains configured'))
                    : ListView.builder(
                        itemCount: domains.length,
                        itemBuilder: (context, index) {
                          final domain = domains[index];
                          return ListTile.selectable(
                            title: Text('EIGRP AS ${domain.asNumber}'),
                            subtitle: Text(
                              '${domain.namedMode ? '(Named: ${domain.namedInstanceName ?? 'N/A'}) ' : ''}${domain.members.length} member(s)',
                            ),
                            selected:
                                _selectedDomain?.identifier ==
                                domain.identifier,
                            trailing: IconButton(
                              icon: const Icon(FluentIcons.delete, size: 14),
                              onPressed: () => _deleteEigrpDomain(domain),
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
              ? const Center(
                  child: Text('Select an EIGRP domain to view details'),
                )
              : _EigrpDomainDetails(
                  domain: _selectedDomain!,
                  devices: widget.devices,
                  project: widget.project,
                  onUpdated: () => setState(() {}),
                ),
        ),
      ],
    );
  }
}

class _EigrpDomainDetails extends StatelessWidget {
  const _EigrpDomainDetails({
    required this.domain,
    required this.devices,
    required this.project,
    required this.onUpdated,
  });
  final EigrpDomain domain;
  final List<NetDevice> devices;
  final Project project;
  final VoidCallback onUpdated;

  String _getDeviceName(int deviceId) {
    final device = devices.firstWhere(
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
            Text(
              'EIGRP AS ${domain.asNumber}',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            if (domain.namedMode)
              Text('Named Instance: ${domain.namedInstanceName ?? 'N/A'}'),
            const SizedBox(height: 16),
            Text(
              'Members',
              style: FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: domain.members.isEmpty
                  ? const Center(child: Text('No members configured'))
                  : ListView.builder(
                      itemCount: domain.members.length,
                      itemBuilder: (context, index) {
                        final member = domain.members[index];
                        return ListTile(
                          title: Text(_getDeviceName(member.deviceId)),
                          subtitle: Text(
                            'Router ID: ${member.routerId ?? 'auto'} - ${member.networks.length} network(s)',
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
