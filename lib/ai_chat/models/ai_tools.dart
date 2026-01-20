/// Definition of tools available to the AI assistant
class AiToolDefinition {
  final String name;
  final String description;
  final Map<String, AiToolParameter> parameters;
  final List<String> required;

  const AiToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    this.required = const [],
  });

  Map<String, dynamic> toJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': {
          for (final entry in parameters.entries)
            entry.key: entry.value.toJson(),
        },
        'required': required,
      },
    },
  };
}

class AiToolParameter {
  final String type;
  final String description;
  final List<String>? enumValues;

  const AiToolParameter({
    required this.type,
    required this.description,
    this.enumValues,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'description': description,
    if (enumValues != null) 'enum': enumValues,
  };
}

/// All tools available to the AI assistant
class AiTools {
  static const listDevices = AiToolDefinition(
    name: 'list_devices',
    description:
        'List all devices in the current project with their basic info (id, hostname, category, group)',
    parameters: {},
  );

  static const listAvailablePresets = AiToolDefinition(
    name: 'list_available_presets',
    description:
        'List all available device presets that can be added to the project (those with remaining slots)',
    parameters: {},
  );

  static const listGroups = AiToolDefinition(
    name: 'list_groups',
    description: 'List all device groups in the current project',
    parameters: {},
  );

  static const getDeviceSettings = AiToolDefinition(
    name: 'get_device_settings',
    description:
        'Get the full configuration of a specific device including hostname, interfaces, VLANs, routing, etc.',
    parameters: {
      'device_id': AiToolParameter(
        type: 'integer',
        description: 'The ID of the device to get settings for',
      ),
    },
    required: ['device_id'],
  );

  static const getProjectSettings = AiToolDefinition(
    name: 'get_project_settings',
    description:
        'Get the project-level settings including network services configuration (OSPF, EIGRP, HSRP, etc.)',
    parameters: {},
  );

  static const proposeDeviceChange = AiToolDefinition(
    name: 'propose_device_change',
    description:
        'Propose a change to a device configuration. Changes will be shown to the user for approval.',
    parameters: {
      'device_id': AiToolParameter(
        type: 'integer',
        description: 'The ID of the device to modify',
      ),
      'path': AiToolParameter(
        type: 'string',
        description:
            'The JSON path to modify (e.g., "hostname", "config.vlans", "config.static_routes")',
      ),
      'new_value': AiToolParameter(
        type: 'string',
        description: 'The new value as a JSON string',
      ),
      'description': AiToolParameter(
        type: 'string',
        description: 'A brief description of what this change does',
      ),
    },
    required: ['device_id', 'path', 'new_value', 'description'],
  );

  static const proposeProjectChange = AiToolDefinition(
    name: 'propose_project_change',
    description:
        'Propose a change to project-level settings (network services). Changes will be shown to the user for approval.',
    parameters: {
      'path': AiToolParameter(
        type: 'string',
        description:
            'The JSON path to modify (e.g., "properties.ospf", "properties.eigrp")',
      ),
      'new_value': AiToolParameter(
        type: 'string',
        description: 'The new value as a JSON string',
      ),
      'description': AiToolParameter(
        type: 'string',
        description: 'A brief description of what this change does',
      ),
    },
    required: ['path', 'new_value', 'description'],
  );

  static const addDevice = AiToolDefinition(
    name: 'add_device',
    description: 'Add a new device to the project from an available preset',
    parameters: {
      'preset_id': AiToolParameter(
        type: 'integer',
        description: 'The preset ID of the device type to add',
      ),
      'hostname': AiToolParameter(
        type: 'string',
        description: 'Optional custom hostname for the new device',
      ),
    },
    required: ['preset_id'],
  );

  static const moveDeviceToGroup = AiToolDefinition(
    name: 'move_device_to_group',
    description: 'Move a device to a different group (or remove from group)',
    parameters: {
      'device_id': AiToolParameter(
        type: 'integer',
        description: 'The ID of the device to move',
      ),
      'group_name': AiToolParameter(
        type: 'string',
        description:
            'The name of the group to move to (empty string to remove from group)',
      ),
    },
    required: ['device_id', 'group_name'],
  );

  static List<AiToolDefinition> get all => [
    listDevices,
    listAvailablePresets,
    listGroups,
    getDeviceSettings,
    getProjectSettings,
    proposeDeviceChange,
    proposeProjectChange,
    addDevice,
    moveDeviceToGroup,
  ];

  static List<Map<String, dynamic>> toJsonList() =>
      all.map((t) => t.toJson()).toList();
}
