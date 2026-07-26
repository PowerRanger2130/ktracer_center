import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/devices/device_preset.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/tests/current_device_card.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class BgpNeighbor {
  const BgpNeighbor({
    required this.ip,
    required this.name,
    required this.routerId,
    required this.version,
    required this.remoteAs,
    required this.preset,
  });

  final String ip;
  final String name;
  final String routerId;
  final int version;
  final int remoteAs;
  final DevicePreset preset;
}

class BgpSnapshot {
  const BgpSnapshot({
    required this.router,
    required this.routerId,
    required this.preset,
    required this.localAs,
    required this.tableVersion,
    required this.mainRoutingTableVersion,
    required this.neighbors,
  });

  final String router;
  final String routerId;
  final DevicePreset preset;
  final int localAs;
  final int tableVersion;
  final int mainRoutingTableVersion;
  final List<BgpNeighbor> neighbors;
}

class BgpTest extends StatefulWidget {
  const BgpTest({required this.device, required this.localAs, super.key});
  final NetDevice device;
  final int localAs;

  @override
  State<BgpTest> createState() => _BgpTestState();
}

class _BgpTestState extends State<BgpTest> {
  late final int _selectedAs;

  @override
  void initState() {
    super.initState();
    _selectedAs = widget.localAs;
  }

  static final Map<int, BgpSnapshot> _bgpSummaries = {
    65001: BgpSnapshot(
      router: 'S1R1',
      routerId: '192.168.99.2',
      localAs: 65001,
      tableVersion: 31,
      mainRoutingTableVersion: 31,
      preset: DevicePresets.i4221,
      neighbors: [
        BgpNeighbor(
          ip: '10.0.1.2',
          name: 'S2R1',
          routerId: '192.168.199.1',
          version: 4,
          remoteAs: 65002,
          preset: DevicePresets.i4221,
        ),
        BgpNeighbor(
          ip: '10.0.2.2',
          routerId: '192.168.83.1',
          name: 'S3R1',
          version: 4,
          remoteAs: 65003,
          preset: DevicePresets.c8200l,
        ),
      ],
    ),
    65002: BgpSnapshot(
      router: 'S2R1',
      routerId: '192.168.199.1',
      localAs: 65002,
      tableVersion: 29,
      mainRoutingTableVersion: 29,
      preset: DevicePresets.i4221,
      neighbors: [
        BgpNeighbor(
          ip: '10.0.1.1',
          name: 'S1R1',
          routerId: '192.168.99.2',
          version: 4,
          remoteAs: 65001,
          preset: DevicePresets.i4221,
        ),
      ],
    ),
    65003: BgpSnapshot(
      router: 'S3R1',
      routerId: '192.168.83.1',
      localAs: 65003,
      tableVersion: 27,
      mainRoutingTableVersion: 27,
      preset: DevicePresets.c8200l,
      neighbors: [
        BgpNeighbor(
          ip: '10.0.2.1',
          routerId: '192.168.99.2',
          name: 'S1R1',
          version: 4,
          remoteAs: 65001,
          preset: DevicePresets.i4221,
        ),
      ],
    ),
  };

  Widget _peerSummaryCard({
    required String name,
    required int as,
    required String rid,
    required DevicePreset preset,
    required String ip,
    Color asColor = const Color(0xff0078d4),
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(FluentIcons.branch_fork2),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FluentWidgets.chip(child: Text('AS $as'), color: asColor),
                  const SizedBox(width: 8),
                  FluentWidgets.chip(
                    child: Text('Router ID: $rid'),
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(ip, style: TextStyle(color: Colors.grey[100])),
            ],
          ),
          FluentWidgets.chip(
            child: Text(preset.sku),
            color: preset.color ?? Colors.grey,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _bgpSummaries[_selectedAs];
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500),
      title: TestDialogHeaderRow(title: 'BGP Test', device: widget.device),
      content: snapshot == null
          ? const Text('No BGP data available.')
          : SizedBox(
              width: 860,
              child: ListView(
                shrinkWrap: true,
                children: [
                  _peerSummaryCard(
                    name: snapshot.router,
                    as: snapshot.localAs,
                    rid: snapshot.routerId,
                    preset: snapshot.preset,
                    ip: 'Table v${snapshot.tableVersion} • Main table v${snapshot.mainRoutingTableVersion}',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Neighbors',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...snapshot.neighbors.map(
                    (neighbor) => _peerSummaryCard(
                      name: neighbor.name,
                      as: neighbor.remoteAs,
                      rid: neighbor.routerId,
                      preset: neighbor.preset,
                      ip: "IP: ${neighbor.ip}",
                      asColor: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
