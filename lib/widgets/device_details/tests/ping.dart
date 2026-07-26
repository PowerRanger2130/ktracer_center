import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/utils/synced_controller.dart';
import 'package:ktracer_center/widgets/device_details/tests/current_device_card.dart';
import 'package:ktracer_center/widgets/ip_address_field.dart';

class PingTest extends StatefulWidget {
  const PingTest({required this.device, super.key});
  final NetDevice device;

  @override
  State<PingTest> createState() => _PingTestState();
}

class PingResult {
  PingResult(
    this.sequenceNumber,
    this.bytes,
    this.timeMs,
    this.ttl,
    this.sourceIp,
    this.destinationIp,
  );
  final int sequenceNumber;
  final int bytes;
  final int timeMs;
  final int ttl;
  final IPv4? sourceIp;
  final IPv4 destinationIp;
}

class _PingTestState extends State<PingTest> {
  final sourceIpController = SyncedController(
    onSave: (data) async {
      print(data); // IP String
    },
    adapter: StringAdapter(),
  );

  final destinationIpController = SyncedController(
    onSave: (data) async {
      print(data); // IP String
    },
    adapter: StringAdapter(),
  );

  final List<PingResult> results = [];

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: BoxConstraints(maxWidth: 450),
      title: TestDialogHeaderRow(title: 'Ping Test', device: widget.device),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IpAddressField(
            controller: sourceIpController,
            title: 'Source IP Address (Optional)',
            enableCidr: false,
            placeholder: '192.168.1.10',
          ),
          const SizedBox(height: 12),
          IpAddressField(
            controller: destinationIpController,
            title: 'Destination IP Address',
            enableCidr: false,
            placeholder: '192.168.1.1',
          ),
          if (results.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Results:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...results.map(
              (result) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                /*
                  Pinging 192.168.88.2 with 32 bytes of data:
                  Reply from 192.168.88.2: bytes=32 time=4ms TTL=255
                  Reply from 192.168.88.2: bytes=32 time=2ms TTL=255
                  Reply from 192.168.88.2: bytes=32 time=2ms TTL=255
                */
                child: Card(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text("SEQ ${result.sequenceNumber}"),
                      ),
                      SizedBox(
                        width: 130,
                        child: Text(
                          result.ttl == -1
                              ? "Request timed out"
                              : "Reply from\n${result.destinationIp}",
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          result.ttl == -1 ? "" : "${result.bytes} bytes",
                        ),
                      ),
                      SizedBox(
                        child: Text(
                          result.ttl == -1 ? "" : "${result.timeMs}ms",
                        ),
                      ),
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
          child: Text("Clear results"),
          onPressed: () {
            setState(() {
              results.clear();
            });
          },
        ),
        GestureDetector(
          onSecondaryTap: () async {
            final destinationValue = destinationIpController.value.trim();
            if (destinationValue.isEmpty) return;

            final sourceValue = sourceIpController.value.trim();
            final sourceIp = sourceValue.isEmpty
                ? null
                : _parseHostIp(sourceValue);
            final destinationIp = _parseHostIp(destinationValue);
            if (destinationIp == null) return;
            results.clear();
            for (int i = 0; i < 4; i++) {
              // Simulate failed ping
              final timeMs = 1000;
              final result = PingResult(
                i + 1,
                32,
                timeMs,
                -1,
                sourceIp,
                destinationIp,
              );
              await Future.delayed(Duration(milliseconds: timeMs));
              setState(() {
                results.add(result);
              });
            }
          },
          child: FilledButton(
            child: Text("Send"),
            onPressed: () async {
              print("Starting ping test...");
              final destinationValue = destinationIpController.value.trim();
              if (destinationValue.isNotEmpty) {
                final sourceValue = sourceIpController.value.trim();
                final sourceIp = sourceValue.isEmpty
                    ? null
                    : _parseHostIp(sourceValue);
                final destinationIp = _parseHostIp(destinationValue);
                if (destinationIp == null) return;
                results.clear();
                for (int i = 0; i < 4; i++) {
                  // Simulate ping
                  final timeMs = Random().nextInt(3) + 1;
                  final result = PingResult(
                    i + 1,
                    32,
                    timeMs,
                    255,
                    sourceIp,
                    destinationIp,
                  );
                  await Future.delayed(Duration(milliseconds: timeMs + 100));
                  setState(() {
                    results.add(result);
                  });
                }
              }
            },
          ),
        ),
      ],
    );
  }

  IPv4? _parseHostIp(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    final address = value.contains('/') ? value.split('/').first : value;
    if (!IPv4.isValidAddress(address)) return null;
    return IPv4.fromAddress(address);
  }
}
