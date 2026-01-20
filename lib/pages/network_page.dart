// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/network/server.dart';
import 'package:http/http.dart' as http;

class NetworkPage extends StatefulWidget {
  const NetworkPage({super.key});

  @override
  State<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends State<NetworkPage> {
  Future<void> init() async {
    // Start server
    await NetServer.start();
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    // Stop server
    NetServer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FilledButton(
          child: Text("Test"),
          onPressed: () async {
            final response = await http.post(
              Uri.parse('http://127.0.0.1:8081/command'),
              body: jsonEncode({"device": '13', "command": 'version'}),
            );
            print('Response status: ${response.statusCode}');
            print('Response body: ${response.body}');
          },
        ),
      ],
    );
  }
}
