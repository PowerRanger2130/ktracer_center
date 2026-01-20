// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

class NetServer {
  static HttpServer? _server;

  static Future<void> start({int port = 8080}) async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print('Server listening on port ${_server!.port}');

      await for (HttpRequest request in _server!) {
        _handleRequest(request);
      }
    } catch (e) {
      print('Error starting server: $e');
    }
  }

  static Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  static void _handleRequest(HttpRequest request) {
    if (request.method == 'GET') {
      _handleGet(request);
    } else if (request.method == 'POST') {
      _handlePost(request);
    } else {
      request.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..write(
          jsonEncode({'message': 'Unsupported method: ${request.method}'}),
        )
        ..close();
    }
  }

  static void _handleGet(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.ok
      ..write('Received GET request')
      ..close();
  }

  static Future<void> _handlePost(HttpRequest request) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..write(jsonEncode({'message': 'Received POST request'}))
      ..close();
  }
}
