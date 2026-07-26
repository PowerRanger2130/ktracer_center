import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/utils/synced_controller.dart';
import 'package:ktracer_center/widgets/device_details/tests/current_device_card.dart';
import 'package:ktracer_center/widgets/ip_address_field.dart';

class TracerouteHop {
  TracerouteHop(this.hopNumber, this.hopIp, this.probesMs);
  final int hopNumber;
  final IPv4? hopIp; // null means no response (*)
  final List<int?> probesMs; // null means timeout for that probe
}

class TracerouteTest extends StatefulWidget {
  const TracerouteTest({required this.device, super.key});
  final NetDevice device;

  @override
  State<TracerouteTest> createState() => _TracerouteTestState();
}

class _TracerouteTestState extends State<TracerouteTest> {
  static const Map<String, List<Map<String, Object?>>> _tracerouteFixtures = {
    '192.168.82.1': [
      {
        'ip': '10.0.1.2',
        'constant': 5,
        'min': 0,
        'max': 2,
        'timeoutRate': 0.34,
      },
    ],
    '192.168.83.1': [
      {
        'ip': '10.0.2.2',
        'constant': 5,
        'min': 0,
        'max': 2,
        'timeoutRate': 0.34,
      },
    ],
    '192.168.88.2': [
      {'ip': '10.0.1.2', 'constant': 2, 'min': 0, 'max': 1},
      {'ip': '10.0.0.1', 'constant': 1, 'min': 0, 'max': 1},
      {'ip': '192.168.88.2', 'constant': 2, 'min': 0, 'max': 2},
    ],
    '1.1.1.1': [
      {'ip': '10.0.1.2', 'constant': 2, 'min': 0, 'max': 1},
      {'ip': '10.0.0.1', 'constant': 4, 'min': 0, 'max': 2},
      {'ip': '172.16.0.1', 'constant': 7, 'min': 0, 'max': 2},
      {'ip': '1.1.1.1', 'constant': 13, 'min': 0, 'max': 2},
      {'ip': '8.8.8.8', 'constant': 15, 'min': 0, 'max': 2},
    ],
  };

  final destinationIpController = SyncedController(
    onSave: (data) async {},
    adapter: StringAdapter(),
  );

  final List<TracerouteHop> hops = [];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    destinationIpController.addListener(_onDestinationChanged);
  }

  void _onDestinationChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    destinationIpController.removeListener(_onDestinationChanged);
    destinationIpController.dispose();
    super.dispose();
  }

  String _probeText(int? ms) => ms == null ? '*' : '${ms}ms';

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: BoxConstraints(maxWidth: 450),
      title: TestDialogHeaderRow(
        title: 'Traceroute Test',
        device: widget.device,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IpAddressField(
            controller: destinationIpController,
            title: 'Destination IP Address',
            enableCidr: false,
            placeholder: '192.168.82.1',
          ),
          if (hops.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Results:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...hops.map(
              (hop) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Card(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${hop.hopNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(hop.hopIp?.address ?? '*'),
                      ),
                      Text(hop.probesMs.map(_probeText).join('  ')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        Button(
          child: const Text("Clear"),
          onPressed: _running ? null : () => setState(() => hops.clear()),
        ),
        FilledButton(
          onPressed: _running ? null : _runTrace,
          child: const Text("Trace"),
        ),
      ],
    );
  }

  Future<void> _runTrace() async {
    final destinationValue = destinationIpController.value.trim();
    if (destinationValue.isEmpty) return;
    final destinationAddress = _extractAddress(destinationValue);
    if (!IPv4.isValidAddress(destinationAddress)) return;

    setState(() {
      hops.clear();
      _running = true;
    });

    final rng = Random();

    final mappedHops =
        _tracerouteFixtures[destinationAddress] ??
        [
          {'ip': '10.0.1.2', 'constant': 2, 'min': 0, 'max': 1},
          {'ip': '10.0.0.1', 'constant': 5, 'min': 0, 'max': 2},
          {'ip': destinationAddress, 'constant': 8, 'min': 0, 'max': 2},
        ];

    for (int i = 0; i < mappedHops.length; i++) {
      final hopData = mappedHops[i];
      await Future.delayed(const Duration(milliseconds: 300));
      final hopIp = _parseHopIp(hopData['ip']);
      final probes = _buildProbeLatencies(
        rng: rng,
        min: _toInt(hopData['min'], defaultValue: 0),
        max: _toInt(hopData['max'], defaultValue: 0),
        constant: _toInt(hopData['constant'], defaultValue: 1),
        timeoutRate: _toDouble(hopData['timeoutRate'], defaultValue: 0),
      );
      setState(() {
        hops.add(TracerouteHop(i + 1, hopIp, probes));
      });
    }

    setState(() => _running = false);
  }

  String _extractAddress(String value) {
    final trimmed = value.trim();
    final address = trimmed.contains('/') ? trimmed.split('/').first : trimmed;
    return address.trim();
  }

  IPv4? _parseHopIp(Object? rawIp) {
    if (rawIp == null) return null;
    final ip = rawIp.toString().trim();
    if (ip.isEmpty || ip == '*') return null;
    if (!IPv4.isValidAddress(ip)) return null;
    return IPv4.fromAddress(ip);
  }

  List<int?> _buildProbeLatencies({
    required Random rng,
    required int min,
    required int max,
    required int constant,
    required double timeoutRate,
  }) {
    final low = min <= max ? min : max;
    final high = min <= max ? max : min;
    final span = (high - low) + 1;
    return List<int?>.generate(3, (_) {
      if (timeoutRate > 0 && rng.nextDouble() < timeoutRate) {
        return null;
      }
      final offset = low + rng.nextInt(span);
      return constant + offset;
    }, growable: false);
  }

  int _toInt(Object? value, {required int defaultValue}) {
    if (value is int) return value;
    return defaultValue;
  }

  double _toDouble(Object? value, {required double defaultValue}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return defaultValue;
  }
}
