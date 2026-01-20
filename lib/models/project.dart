import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Project {
  final int id;
  final String name;
  final String? description;
  final DateTime createdAt;

  /// Project-level network services configuration (HSRP, OSPF, etc.)
  ProjectProperties properties;

  Project({
    required this.id,
    required this.name,
    this.description,
    DateTime? createdAt,
    ProjectProperties? properties,
  }) : createdAt = createdAt ?? DateTime.now(),
       properties = properties ?? const ProjectProperties();

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      properties: ProjectProperties.fromJson(
        json['properties'] as Map<String, dynamic>?,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'properties': properties.toJson(),
    };
  }

  /// Create a new project
  static Future<Project> create(String name, {String? description}) async {
    final response = await Supabase.instance.client
        .from('projects_v2')
        .insert({'name': name, 'description': description})
        .select()
        .single();

    return Project.fromJson(response);
  }

  /// Save/update project details
  Future<void> save() async {
    await Supabase.instance.client
        .from('projects_v2')
        .update({'name': name, 'description': description})
        .eq('id', id);
  }

  /// Save only the properties (network services) to the database
  Future<void> saveProperties() async {
    await Supabase.instance.client
        .from('projects_v2')
        .update({'properties': properties.toJson()})
        .eq('id', id);
  }

  /// Update properties with a new value and save to database
  Future<void> updateProperties(ProjectProperties newProperties) async {
    properties = newProperties;
    await saveProperties();
  }

  /// Merge partial properties update and save
  Future<void> mergeProperties(ProjectProperties partial) async {
    properties = properties.merge(partial);
    await saveProperties();
  }

  /// Delete the project
  Future<void> delete() async {
    await Supabase.instance.client.from('projects_v2').delete().eq('id', id);
  }

  /// Add user to project team (alias for addToTeam)
  Future<void> addUser(String userId, {String role = 'member'}) async {
    await addToTeam(userId, role: role);
  }

  /// Remove user from project team (alias for removeFromTeam)
  Future<void> removeUser(String userId) async {
    await removeFromTeam(userId);
  }

  /// Add current user to project team
  Future<void> addToTeam(String userId, {String role = 'member'}) async {
    await Supabase.instance.client.from('teams').insert({
      'project_id': id,
      'user_id': userId,
      'role': role,
    });
  }

  /// Remove user from project team
  Future<void> removeFromTeam(String userId) async {
    await Supabase.instance.client.from('teams').delete().match({
      'project_id': id,
      'user_id': userId,
    });
  }

  /// Get team members
  Future<List<TeamMember>> getTeamMembers() async {
    final response = await Supabase.instance.client
        .from('teams')
        .select('user_id, role, users(id, name, shortName, email)')
        .eq('project_id', id);

    return response.map<TeamMember>((item) {
      final userData = item['users'];
      return TeamMember(
        userId: item['user_id'],
        role: item['role'],
        name: userData?['name'],
        shortName: userData?['shortName'],
        email: userData?['email'],
      );
    }).toList();
  }

  /// Get devices for this project
  Future<List<NetDevice>> getDevices() async {
    final response = await Supabase.instance.client
        .from('net_devices')
        .select()
        .eq('project_id', id);

    return response.map<NetDevice>((item) => NetDevice.fromJson(item)).toList();
  }

  /// Add a device to the project by preset
  Future<NetDevice> addDevice(
    int presetId, {
    Map<String, dynamic>? config,
  }) async {
    final device = NetDevice(
      id: -1,
      projectId: id,
      presetId: presetId,
      config: config,
    );

    final response = await Supabase.instance.client
        .from('net_devices')
        .insert(device.toInsertJson())
        .select()
        .single();

    return NetDevice.fromJson(response);
  }

  // TODO: Device locking feature - not yet implemented
  // These methods will be used when implementing device locking:
  // - checkDeviceAvailability: Check if physical devices are available
  // - allocateDevices: Lock physical devices to this project
  // - releaseDevices: Release locked physical devices
  //
  // When implemented, this will use a separate locking mechanism
  // (e.g., a device_locks table) rather than storing real_id in net_devices
}

class TeamMember {
  final String userId;
  final String role;
  final String? name;
  final String? shortName;
  final String? email;

  TeamMember({
    required this.userId,
    required this.role,
    this.name,
    this.shortName,
    this.email,
  });
}
