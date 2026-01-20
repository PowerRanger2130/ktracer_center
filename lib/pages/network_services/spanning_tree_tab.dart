import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/models/project.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class SpanningTreeTab extends StatefulWidget {
  const SpanningTreeTab({
    super.key,
    required this.project,
    required this.devices,
  });
  final Project project;
  final List<NetDevice> devices;

  @override
  State<SpanningTreeTab> createState() => _SpanningTreeTabState();
}

class _SpanningTreeTabState extends State<SpanningTreeTab> {
  Future<void> _enableSpanningTree() async {
    SpanningTreeMode mode = SpanningTreeMode.rapidPvst;

    final result = await showDialog<SpanningTreeDomain>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Configure Spanning Tree'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mode'),
              const SizedBox(height: 4),
              ComboBox<SpanningTreeMode>(
                value: mode,
                items: SpanningTreeMode.values
                    .map((m) => ComboBoxItem(value: m, child: Text(m.name)))
                    .toList(),
                onChanged: (v) => setDialogState(
                  () => mode = v ?? SpanningTreeMode.rapidPvst,
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
                Navigator.pop(context, SpanningTreeDomain(mode: mode));
              },
              child: const Text('Enable'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final updated = widget.project.properties.copyWith(spanningTree: result);
      await widget.project.updateProperties(updated);
      setState(() {});
    }
  }

  Future<void> _disableSpanningTree() async {
    final updated = ProjectProperties(
      hsrpGroups: widget.project.properties.hsrpGroups,
      ospfDomains: widget.project.properties.ospfDomains,
      eigrpDomains: widget.project.properties.eigrpDomains,
      staticRoutes: widget.project.properties.staticRoutes,
      spanningTree: null,
      vtpDomain: widget.project.properties.vtpDomain,
    );
    await widget.project.updateProperties(updated);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stp = widget.project.properties.spanningTree;

    if (stp == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Spanning Tree is not configured'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _enableSpanningTree,
              child: const Text('Enable Spanning Tree'),
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
                  'Spanning Tree Configuration',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const Spacer(),
                Button(
                  onPressed: _disableSpanningTree,
                  child: const Text('Disable'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Mode: ${stp.mode.name}'),
            Text('Members: ${stp.members.length}'),
            Text('VLAN Configs: ${stp.vlanConfigs.length}'),
            const SizedBox(height: 16),
            Text(
              'VLAN Priority Configuration',
              style: FluentTheme.of(context).typography.bodyStrong,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: stp.vlanConfigs.isEmpty
                  ? const Center(child: Text('No per-VLAN configuration'))
                  : ListView.builder(
                      itemCount: stp.vlanConfigs.length,
                      itemBuilder: (context, index) {
                        final config = stp.vlanConfigs[index];
                        return ListTile(
                          title: Text('VLAN ${config.vlanId}'),
                          subtitle: Text(
                            'Priority: ${config.priority ?? 'default'}',
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
