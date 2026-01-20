// ignore_for_file: avoid_print

import 'dart:io';

import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/project.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Database {
  static SupabaseClient get _client => Supabase.instance.client;

  // ==================== Projects ====================

  /// Load all projects for the current user
  static Future<List<Project>> loadProjects() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      print("Loading projects for user: $userId");

      // Get projects where user is a team member
      final response = await _client
          .from('teams')
          .select('project_id, projects_v2(*)')
          .eq('user_id', userId);

      print("Teams response: $response");

      if (response.isEmpty) {
        print("No teams found for user");
        return [];
      }

      final projects = response
          .where((item) => item['projects_v2'] != null)
          .map((item) => Project.fromJson(item['projects_v2']))
          .toList();

      print("Loaded ${projects.length} projects");
      return projects;
    } catch (e) {
      print("Error loading projects: $e");
      rethrow;
    }
  }

  /// Create a new project and add creator to team as owner
  static Future<Project> createProject(
    String name, {
    String? description,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    print("Creating project '$name' for user $userId");
    final project = await Project.create(name, description: description);
    print("Project created with id ${project.id}");

    await project.addToTeam(userId, role: 'owner');
    print("User added to team as owner");

    return project;
  }

  /// Delete a project
  static Future<void> deleteProject(int projectId) async {
    await _client.from('projects_v2').delete().eq('id', projectId);
  }

  // ==================== Devices ====================

  /// Get all devices for a project
  static Future<List<NetDevice>> getDevicesForProject(int projectId) async {
    try {
      final response = await _client
          .from('net_devices')
          .select()
          .eq('project_id', projectId);

      return response
          .map<NetDevice>((item) => NetDevice.fromJson(item))
          .toList();
    } catch (e) {
      print("Error fetching devices: $e");
      rethrow;
    }
  }

  /// Stream devices for a project (real-time updates)
  static Stream<List<NetDevice>> getDevicesStream(int projectId) {
    return _client
        .from('net_devices')
        .stream(primaryKey: ['id'])
        .eq('project_id', projectId)
        .map((data) => data.map((item) => NetDevice.fromJson(item)).toList());
  }

  /// Save a device (insert or update)
  static Future<NetDevice> saveDevice(NetDevice device) async {
    try {
      if (device.id == -1) {
        // Insert new device
        final response = await _client
            .from('net_devices')
            .insert(device.toInsertJson())
            .select()
            .single();
        return NetDevice.fromJson(response);
      } else {
        // Update existing device
        final response = await _client
            .from('net_devices')
            .update({
              'preset_id': device.presetId,
              // realId is not stored in DB - will be assigned during device locking
              'config': device.config,
            })
            .eq('id', device.id)
            .select()
            .single();
        return NetDevice.fromJson(response);
      }
    } catch (e) {
      print("Error saving device: $e");
      rethrow;
    }
  }

  /// Update device config (partial update)
  static Future<void> updateDeviceConfig(
    int deviceId,
    Map<String, dynamic> configUpdates,
  ) async {
    try {
      // Fetch current config
      final current = await _client
          .from('net_devices')
          .select('config')
          .eq('id', deviceId)
          .single();

      final currentConfig = current['config'] as Map<String, dynamic>? ?? {};
      final newConfig = {...currentConfig, ...configUpdates};

      await _client
          .from('net_devices')
          .update({'config': newConfig})
          .eq('id', deviceId);
    } catch (e) {
      print("Error updating device config: $e");
      rethrow;
    }
  }

  /// Get the current device config
  static Future<Map<String, dynamic>?> getDeviceConfig(int deviceId) async {
    try {
      final response = await _client
          .from('net_devices')
          .select('config')
          .eq('id', deviceId)
          .single();
      return response['config'] as Map<String, dynamic>?;
    } catch (e) {
      print("Error fetching device config: $e");
      return null;
    }
  }

  /// Delete a device
  static Future<void> deleteDevice(int deviceId) async {
    await _client.from('net_devices').delete().eq('id', deviceId);
  }

  // ==================== Users ====================

  /// Get current user info
  static Future<KtUser?> getCurrentUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return KtUser.fromJson(response);
    } catch (e) {
      print("Error loading user: $e");
      return null;
    }
  }

  /// Search users by name or email
  static Future<List<KtUser>> searchUsers(String query) async {
    try {
      final cleanQuery = query.trim();
      final response = await _client
          .from('users')
          .select()
          .or('name.ilike.%$cleanQuery%,email.ilike.%$cleanQuery%')
          .limit(10);

      return response.map<KtUser>((item) => KtUser.fromJson(item)).toList();
    } catch (e) {
      print("Error searching users: $e");
      return [];
    }
  }

  /// Get users for a project (team members)
  static Future<List<KtUser>> getProjectUsers(int projectId) async {
    try {
      final response = await _client
          .from('teams')
          .select('users(id, name, shortName, email)')
          .eq('project_id', projectId);

      final List<KtUser> users = [];
      for (var item in response) {
        if (item['users'] != null) {
          users.add(KtUser.fromJson(item['users']));
        }
      }
      return users;
    } catch (e) {
      print("Error loading project users: $e");
      return [];
    }
  }
}

class KtUser {
  final String id;
  final String name;
  final String? shortName;
  final String email;

  KtUser({
    required this.id,
    required this.name,
    this.shortName,
    required this.email,
  });

  factory KtUser.fromJson(Map<String, dynamic> json) {
    return KtUser(
      id: json['id'],
      name: json['name'],
      shortName: json['shortName'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'shortName': shortName, 'email': email};
  }

  static Future<void> _createUser() async {
    print("Creating new user record...");
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) {
      return;
    }

    final metadata = supabaseUser.userMetadata;
    final String name =
        metadata?['full_name'] ?? metadata?['name'] ?? 'New User';

    String shortName = 'NU';
    if (name != 'New User') {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        shortName = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
        shortName = parts[0]
            .substring(0, parts[0].length > 1 ? 2 : 1)
            .toUpperCase();
      }
    }

    await Supabase.instance.client.from('users').insert({
      'id': supabaseUser.id,
      'name': name,
      'shortName': shortName,
      'email': supabaseUser.email,
    });
  }

  static Future<KtUser?> _ensureUserExists() async {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) {
      return null;
    }

    try {
      final existingUser = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', supabaseUser.id)
          .limit(1)
          .maybeSingle();

      if (existingUser == null) {
        await _createUser();
        return null;
      } else {
        // Load user into app state
        return KtUser(
          id: existingUser['id'] as String,
          name: existingUser['name'] as String,
          shortName: existingUser['shortName'] as String,
          email: existingUser['email'] as String,
        );
      }
    } catch (e) {
      print("Error checking/creating user: $e");
      return null;
    }
  }

  static final allowedDomains = ['kkszki.hu', 'gmail.com'];

  /// Sign in with Google OAuth
  static Future<void> oauthLogin() async {
    // Use InternetAddress.loopbackIPv4 (127.0.0.1) to avoid Windows Firewall prompts
    // Binding to loopback is local-only and doesn't require network access permissions
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);

    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'http://127.0.0.1:3000',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );

    await for (final request in server) {
      final uri = request.uri;
      final code = uri.queryParameters['code'];

      if (code != null) {
        try {
          await Supabase.instance.client.auth.exchangeCodeForSession(code);
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write(
              '<html><body><h1>Login successful! You can close this tab.</h1><script>window.close();</script></body></html>',
            );
          await request.response.close();
          final email =
              Supabase.instance.client.auth.currentUser?.email ?? "Unknown";

          final domain = email.split('@').last;
          if (!allowedDomains.contains(domain)) {
            print("Unauthorized domain: $domain");
            await Supabase.instance.client.auth.signOut();
            return;
          }
          await _ensureUserExists();
        } catch (e) {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Login failed: $e');
          await request.response.close();
        }
        await server.close();
        break;
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found');
        await request.response.close();
      }
    }
  }
}
