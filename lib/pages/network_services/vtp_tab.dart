import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/models/project.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class VtpTab extends StatefulWidget {
  const VtpTab({super.key, required this.project, required this.devices});
  final Project project;
  final List<NetDevice> devices;

  @override
  State<VtpTab> createState() => _VtpTabState();
}

class _VtpTabState extends State<VtpTab> {
  Future<void> _enableVtp() async {
    final domainNameController = TextEditingController();
    VtpVersion version = VtpVersion.v2;
    final passwordController = TextEditingController();

    final result = await showDialog<VtpDomain>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Configure VTP'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Domain Name'),
              const SizedBox(height: 4),
              SizedBox(
                width: 200,
                child: TextBox(
                  controller: domainNameController,
                  placeholder: 'e.g., CORP',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Version'),
              const SizedBox(height: 4),
              ComboBox<VtpVersion>(
                value: version,
                items: VtpVersion.values
                    .map((v) => ComboBoxItem(value: v, child: Text(v.name)))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => version = v ?? VtpVersion.v2),
              ),
              const SizedBox(height: 12),
              const Text('Password (optional)'),
              const SizedBox(height: 4),
              SizedBox(
                width: 200,
                child: PasswordBox(
                  controller: passwordController,
                  placeholder: 'VTP password',
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
                if (domainNameController.text.isNotEmpty) {
                  Navigator.pop(
                    context,
                    VtpDomain(
                      domainName: domainNameController.text.trim(),
                      version: version,
                      password: passwordController.text.isNotEmpty
                          ? passwordController.text
                          : null,
                    ),
                  );
                }
              },
              child: const Text('Enable'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final updated = widget.project.properties.copyWith(vtpDomain: result);
      await widget.project.updateProperties(updated);
      setState(() {});
    }
  }

  Future<void> _disableVtp() async {
    final updated = ProjectProperties(
      hsrpGroups: widget.project.properties.hsrpGroups,
      ospfDomains: widget.project.properties.ospfDomains,
      eigrpDomains: widget.project.properties.eigrpDomains,
      staticRoutes: widget.project.properties.staticRoutes,
      spanningTree: widget.project.properties.spanningTree,
      vtpDomain: null,
    );
    await widget.project.updateProperties(updated);
    setState(() {});
  }

  Future<void> _addMember() async {
    if (widget.devices.isEmpty) return;

    int? selectedDeviceId;
    VtpMode mode = VtpMode.client;
    bool pruning = false;

    final result = await showDialog<VtpMember>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add VTP Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Device'),
              const SizedBox(height: 4),
              ComboBox<int>(
                value: selectedDeviceId,
                items: widget.devices
                    .map(
                      (d) => ComboBoxItem(value: d.id, child: Text(d.hostname)),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedDeviceId = v),
                placeholder: const Text('Select device'),
              ),
              const SizedBox(height: 12),
              const Text('Mode'),
              const SizedBox(height: 4),
              ComboBox<VtpMode>(
                value: mode,
                items: VtpMode.values
                    .map((m) => ComboBoxItem(value: m, child: Text(m.name)))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => mode = v ?? VtpMode.client),
              ),
              const SizedBox(height: 12),
              Checkbox(
                checked: pruning,
                onChanged: (v) => setDialogState(() => pruning = v ?? false),
                content: const Text('Enable Pruning'),
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
                    VtpMember(
                      deviceId: selectedDeviceId!,
                      mode: mode,
                      pruning: pruning,
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
      final vtp = widget.project.properties.vtpDomain!;
      final updated = widget.project.properties.copyWith(
        vtpDomain: vtp.copyWith(members: [...vtp.members, result]),
      );
      await widget.project.updateProperties(updated);
      setState(() {});
    }
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
    final vtp = widget.project.properties.vtpDomain;

    if (vtp == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('VTP is not configured'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _enableVtp,
              child: const Text('Enable VTP'),
            ),
          ],
        ),
      );
    }

    return FluentWidgets.mica(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'VTP Domain: ${vtp.domainName}',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const Spacer(),
                Button(onPressed: _disableVtp, child: const Text('Disable')),
              ],
            ),
            const SizedBox(height: 8),
            Text('Version: ${vtp.version.name}'),
            if (vtp.password != null) const Text('Password: ********'),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Members',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(FluentIcons.add, size: 14),
                  onPressed: _addMember,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: vtp.members.isEmpty
                  ? const Center(child: Text('No members configured'))
                  : ListView.builder(
                      itemCount: vtp.members.length,
                      itemBuilder: (context, index) {
                        final member = vtp.members[index];
                        return ListTile(
                          title: Text(_getDeviceName(member.deviceId)),
                          subtitle: Text(
                            'Mode: ${member.mode.name}${member.pruning ? ' (pruning enabled)' : ''}',
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
