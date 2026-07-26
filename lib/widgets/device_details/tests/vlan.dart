import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/tests/current_device_card.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class VlanEntry {
  const VlanEntry({
    required this.id,
    required this.name,
    required this.status,
    this.ports = const [],
  });

  final int id;
  final String name;
  final String status;
  final List<String> ports;
}

class _ParsedPort {
  const _ParsedPort({
    required this.family,
    required this.path,
    required this.number,
  });

  final String family;
  final String path;
  final int number;
}

const _vlans = <VlanEntry>[
  VlanEntry(
    id: 1,
    name: 'default',
    status: 'active',
    ports: ['Gi1/0/25', 'Gi1/0/26', 'Gi1/0/27', 'Gi1/0/28'],
  ),
  VlanEntry(
    id: 10,
    name: 'Emelet1',
    status: 'active',
    ports: [
      'Gi1/0/2',
      'Gi1/0/3',
      'Gi1/0/4',
      'Gi1/0/5',
      'Gi1/0/6',
      'Gi1/0/7',
      'Gi1/0/8',
      'Gi1/0/9',
      'Gi1/0/10',
      'Gi1/0/13',
      'Gi1/0/14',
      'Gi1/0/15',
      'Gi1/0/16',
      'Gi1/0/17',
      'Gi1/0/18',
      'Gi1/0/19',
      'Gi1/0/20',
    ],
  ),
  VlanEntry(id: 20, name: 'Emelet2', status: 'active'),
  VlanEntry(id: 81, name: 'Management', status: 'active', ports: ['Gi1/0/13']),
  VlanEntry(id: 99, name: 'Server', status: 'active', ports: ['Gi1/0/24']),
  VlanEntry(id: 1002, name: 'fddi-default', status: 'act/unsup'),
  VlanEntry(id: 1003, name: 'token-ring-default', status: 'act/unsup'),
  VlanEntry(id: 1004, name: 'fddinet-default', status: 'act/unsup'),
  VlanEntry(id: 1005, name: 'trnet-default', status: 'act/unsup'),
];

_ParsedPort? _parsePort(String port) {
  final match = RegExp(
    r'^([A-Za-z]+)(\d+(?:/\d+)*/)(\d+)$',
  ).firstMatch(port.trim());
  if (match == null) return null;
  return _ParsedPort(
    family: match.group(1)!,
    path: match.group(2)!,
    number: int.parse(match.group(3)!),
  );
}

String _formatPortRange(_ParsedPort start, _ParsedPort end) {
  final prefix = '${start.family} ${start.path}';
  if (start.number == end.number) {
    return '$prefix${start.number}';
  }
  return '$prefix${start.number} - ${end.number}';
}

List<String> _groupPorts(List<String> ports) {
  if (ports.isEmpty) return const [];

  final grouped = <String>[];
  var index = 0;

  while (index < ports.length) {
    final currentPort = ports[index];
    final parsed = _parsePort(currentPort);
    if (parsed == null) {
      grouped.add(currentPort);
      index++;
      continue;
    }

    var end = parsed;
    var nextIndex = index + 1;

    while (nextIndex < ports.length) {
      final nextParsed = _parsePort(ports[nextIndex]);
      if (nextParsed == null ||
          nextParsed.family != parsed.family ||
          nextParsed.path != parsed.path ||
          nextParsed.number != end.number + 1) {
        break;
      }
      end = nextParsed;
      nextIndex++;
    }

    grouped.add(_formatPortRange(parsed, end));
    index = nextIndex;
  }

  return grouped;
}

Color _statusColor(String status) {
  return switch (status) {
    'active' => const Color(0xff107c10),
    'act/unsup' => const Color(0xffa88800),
    _ => const Color(0xff616161),
  };
}

class VlanTest extends StatelessWidget {
  const VlanTest({required this.device, super.key});

  final NetDevice device;

  @override
  Widget build(BuildContext context) {
    final activeCount = _vlans.where((vlan) => vlan.status == 'active').length;
    final assignedPortCount = _vlans.fold<int>(
      0,
      (sum, vlan) => sum + vlan.ports.length,
    );

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 860),
      title: TestDialogHeaderRow(title: 'VLAN Brief', device: device),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FluentWidgets.chip(
                child: Text('${_vlans.length} VLANs'),
                color: const Color(0xff0078d4),
              ),
              FluentWidgets.chip(
                child: Text('$activeCount active'),
                color: const Color(0xff107c10),
              ),
              FluentWidgets.chip(
                child: Text('$assignedPortCount access ports assigned'),
                color: const Color(0xff8764b8),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 1000),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _vlans
                    .map(
                      (vlan) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _VlanCard(vlan: vlan),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VlanCard extends StatelessWidget {
  const _VlanCard({required this.vlan});

  final VlanEntry vlan;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(vlan.status);
    final groupedPorts = _groupPorts(vlan.ports);
    final subtitleStyle = TextStyle(fontSize: 12, color: Colors.grey[100]);

    return Card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: .35)),
            ),
            child: Text(
              '${vlan.id}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vlan.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FluentWidgets.chip(
                      child: Text(vlan.status),
                      color: statusColor,
                    ),
                    FluentWidgets.chip(
                      child: Text(
                        groupedPorts.isEmpty
                            ? 'No ports'
                            : '${vlan.ports.length} ports',
                      ),
                      color: groupedPorts.isEmpty
                          ? const Color(0xff616161)
                          : const Color(0xff0078d4),
                    ),
                    if (groupedPorts.length > 1)
                      FluentWidgets.chip(
                        child: Text('${groupedPorts.length} groups'),
                        color: const Color(0xff744da9),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (groupedPorts.isEmpty)
                  Text(
                    'No access ports assigned',
                    style: subtitleStyle,
                    textAlign: TextAlign.right,
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 6,
                    children: groupedPorts
                        .map(
                          (portGroup) => FluentWidgets.chip(
                            child: Text(
                              portGroup,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                            color: statusColor.withValues(alpha: .82),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
