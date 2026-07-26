import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/tests/current_device_card.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class OspfTest extends StatefulWidget {
  const OspfTest({required this.device, super.key});
  final NetDevice device;

  @override
  State<OspfTest> createState() => _OspfTestState();
}

class _OspfTestState extends State<OspfTest> {
  Widget _buildRouteTable() {
    // Device IP to name mapping
    const deviceMap = {
      '192.168.10.1': 'R1',
      '192.168.10.2': 'R2',
      '192.168.20.1': 'R1',
      '192.168.20.2': 'R3',
      '10.3.3.1': 'R1',
      '10.3.3.2': 'R2',
      '10.1.1.2': 'R2',
      '10.2.2.2': 'R3',
    };

    // Mocked 'show ip route' output with next hop and interface
    final routes = [
      {
        'type': 'O',
        'prefix': '10.1.1.0/24',
        'via': '192.168.10.2',
        'iface': 'FastEthernet0/0',
        'age': '00:00:12',
        'path': ['Net1', 'R1', 'R2'],
      },
      {
        'type': 'O',
        'prefix': '10.2.2.0/24',
        'via': '192.168.20.2',
        'iface': 'FastEthernet0/1',
        'age': '00:00:15',
        'path': ['Net2', 'R1', 'R3'],
      },
      {'type': 'C', 'prefix': '10.3.3.0/24', 'iface': 'FastEthernet0/2'},
      {'type': 'L', 'prefix': '10.3.3.1/32', 'iface': 'FastEthernet0/2'},
      {'type': 'C', 'prefix': '192.168.10.0/24', 'iface': 'FastEthernet0/0'},
      {'type': 'L', 'prefix': '192.168.10.1/32', 'iface': 'FastEthernet0/0'},
      {'type': 'C', 'prefix': '192.168.20.0/24', 'iface': 'FastEthernet0/1'},
      {'type': 'L', 'prefix': '192.168.20.1/32', 'iface': 'FastEthernet0/1'},
    ];

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gateway of last resort is not set',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          SizedBox(height: 8),
          ...routes.map((route) {
            final type = route['type'] as String;
            final prefix = route['prefix'] as String;
            final iface = route['iface'] as String;
            final via = route['via'] as String?;
            final age = route['age'] as String?;
            final path = route['path'] as List<String>?;
            String? nextHopName = via != null ? deviceMap[via] : null;
            final isOspf = type == 'O';
            final isDirect = type == 'C' || type == 'L';
            final displayPath = path != null
                ? path
                      .where((e) => e != 'R1' && !e.startsWith('Net'))
                      .join(' -> ')
                : null;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: Padding(
                padding: isDirect
                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                    : const EdgeInsets.all(8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        type,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isDirect ? 12 : 14,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 140,
                      child: Text(
                        prefix,
                        style: TextStyle(fontSize: isDirect ? 12 : 14),
                      ),
                    ),
                    if (via != null) ...[
                      SizedBox(width: 8),
                      Text(
                        'via ',
                        style: TextStyle(fontSize: isDirect ? 12 : 14),
                      ),
                      Text(
                        via,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: isDirect ? 12 : 14,
                        ),
                      ),
                      if (nextHopName != null) ...[
                        SizedBox(width: 6),
                        Icon(FluentIcons.contact, size: 14),
                        SizedBox(width: 2),
                        Text(
                          nextHopName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isDirect ? 12 : 14,
                          ),
                        ),
                      ],
                    ],
                    Spacer(),
                    Text(
                      '[$iface]',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: isDirect ? 12 : 14,
                      ),
                    ),
                    if (isDirect) ...[
                      SizedBox(width: 8),
                      FluentWidgets.chip(
                        child: const Text('Local'),
                        color: Colors.grey,
                      ),
                    ],
                    if (isOspf && age != null) ...[
                      SizedBox(width: 8),
                      Text(
                        age,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    if (isOspf &&
                        displayPath != null &&
                        displayPath.isNotEmpty) ...[
                      SizedBox(width: 8),
                      Text(
                        displayPath,
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: BoxConstraints(maxWidth: 700),
      title: TestDialogHeaderRow(title: 'OSPF Test', device: widget.device),
      content: ListView(shrinkWrap: true, children: [_buildRouteTable()]),
    );
  }
}
