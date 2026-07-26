import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ktracer_center/ai_chat/models/chat_message.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:uuid/uuid.dart';

/// Available Gemini models
enum GeminiModel {
  flash('gemini-3-flash-preview', 'Flash', 'Fast responses'),
  pro('gemini-3-pro-preview', 'Pro', 'Higher quality');

  const GeminiModel(this.modelId, this.displayName, this.description);
  final String modelId;
  final String displayName;
  final String description;
}

/// State management for AI chat functionality using Gemini REST API
class AiChatState extends ChangeNotifier {
  static const _apiKey = 'AIzaSyBPfR-zJfiR6x5LeTjVhFdiJaXxRwJ1JsA';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  final AppState _appState;
  final List<ChatMessage> _messages = [];
  final List<Map<String, dynamic>> _conversationHistory = [];
  bool _isOpen = false;
  bool _isProcessing = false;
  GeminiModel _selectedModel = GeminiModel.flash;

  AiChatState(this._appState);

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isOpen => _isOpen;
  bool get isProcessing => _isProcessing;
  GeminiModel get selectedModel => _selectedModel;

  void setModel(GeminiModel model) {
    _selectedModel = model;
    notifyListeners();
  }

  void toggleOpen() {
    _isOpen = !_isOpen;
    notifyListeners();
  }

  void open() {
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    _isOpen = false;
    notifyListeners();
  }

  String get _systemPrompt =>
      '''You are an AI assistant for KTracer Center, a network device configuration management application.
Your role is to help users manage their network devices (routers, switches) and project settings.

=== LAB ENVIRONMENT ===
This is a networking lab with approximately 30 devices:
- Management VLAN: 80 on subnet 192.168.88.0/24
- Switches have FastEthernet0/24 connected to a central management switch
- Switches have FastEthernet0/1 connected to their paired router
- Routers use subinterface FastEthernet0/1.80 for management
- Device pairing: Switch 2 ↔ Router 20, Switch 3 ↔ Router 21, ..., Switch 10 ↔ Router 28

CRITICAL - Management Network Protection:
- NEVER include management interfaces (f0/1.80, VLAN 80, 192.168.88.x) in OSPF/EIGRP/BGP
- NEVER include management subnet in NAT rules
- Management traffic must remain isolated from production routing

CRITICAL - Device IDs Change:
Due to device locking in the lab, device IDs change every session. ALWAYS use list_devices to get current device IDs before making changes. Never hardcode or assume device IDs.

=== AVAILABLE TOOLS ===
- list_devices: List devices in the current project (use FIRST to get device IDs)
- list_available_presets: List device presets that can be added
- list_groups: List device groups
- get_device_settings: Get device config (ALWAYS call before propose_device_change)
- get_project_settings: Get project config (ALWAYS call before propose_project_change)
- get_config_schema: Get schema/examples for a device type
- validate_config: Validate proposed config changes
- propose_device_change: Propose changes to device config
- propose_project_change: Propose changes to project settings
- add_device: Add a new device from a preset
- move_device_to_group: Move device to a group (or remove from group with empty name)
- create_group: Create a new group with devices (groups are implicit, need devices)
- rename_group: Rename an existing group
- delete_group: Delete a group (devices become ungrouped)
- set_device_order: Set sort order of a device within its group
- move_device_up: Move device up one position in its group
- move_device_down: Move device down one position in its group

=== NETWORK SERVICES (Project-Level) ===
Services involving multiple devices are stored at PROJECT level, NOT per device:
- HSRP groups: define which devices participate and their roles
- OSPF/EIGRP/BGP domains: routing across multiple devices
- VRF configs: project-level
Use propose_project_change for these. Path examples: "properties.hsrp_groups", "properties.ospf_domains"

=== DEVICE CONFIG STRUCTURE ===
Top-level keys for propose_device_change:
- "hostname" - Device hostname (string)
- "vlans" - Array: [{"vlan_id": 10, "name": "VLAN10"}]
- "ports" - Array of port/interface configs (use this, NOT "interfaces")
- "channel_groups" - Array of port-channel configs
- "static_routes" - Array of static routes
- "dhcp_pools" - Array of DHCP pool configs
- "nat_rules" - Array of NAT rules
- "acls" - Array of ACL configs
- "tunnels" - Array of tunnel configs

=== DEVICE CAPABILITIES ===
- L2 Switches (2950/2960): VLANs, EtherChannel, STP - NO routing, NO subinterfaces
- L3 Switches (3550/3560X): VLANs + routing (OSPF, EIGRP, HSRP, subinterfaces)
- Routers (2811/2800/4431): Full routing, NAT, DHCP, VPN, subinterfaces

=== CRITICAL - WORKFLOW BEFORE CHANGES ===
**MANDATORY STEPS - NEVER SKIP:**
1. ALWAYS call get_device_settings or get_project_settings FIRST to see the ACTUAL current data
2. LOOK at the data structure returned - arrays must be arrays, not objects/maps
3. NEVER assume, guess, or invent data - use ONLY what the tools return
4. When modifying arrays, include ALL existing items plus your changes
5. Validate with validate_config before proposing

**DATA TYPE REQUIREMENTS:**
- "vlans", "ports", "nat_rules", "acls", "static_routes", "dhcp_pools" = ARRAYS []
- "hostname" = STRING
- Never send an object {} when an array [] is expected

=== EXAMPLES - CORRECT USAGE ===

**PAT (Port Address Translation) - CORRECT:**
First call get_device_settings, then propose:
```
nat_rules: [
  {
    "type": "pat",
    "name": "PAT_INTERNET",
    "inside_interfaces": ["FastEthernet0/0"],
    "outside_interface": "Serial0/0/0",
    "overload": true,
    "source": "10.0.0.0/24"
  }
]
acls: [
  {
    "name": "NAT_ACL",
    "type": "standard",
    "entries": [
      {"sequence": 10, "action": "permit", "source": "10.0.0.0", "wildcard": "0.0.0.255"}
    ]
  }
]
```

**PAT - WRONG (do NOT do this):**
```
nat_rules: [
  {"type": "static", "inside_local": "", "inside_global": ""},
  {"type": "static", "inside_local": "", "inside_global": ""},
  {"type": "static", "inside_local": "", "inside_global": ""}
]
acls: [
  {
    "entries": [
      {"sequence": 10, "action": "permit", "source": "10.0.0.0"},
      {"sequence": 10, "action": "permit", "source": "10.0.1.0"},
      {"sequence": 10, "action": "permit", "source": "10.0.2.0"}
    ]
  }
]
```
Problems: Static NAT instead of PAT, empty values, duplicate sequence numbers.

**OSPF - CORRECT:**
First call get_project_settings, then propose_project_change:
```
path: "properties.ospf_domains"
new_value: [
  {
    "name": "OSPF_PRODUCTION",
    "process_id": 1,
    "router_id_source": "loopback",
    "participants": [
      {
        "device_id": "actual-id-from-list_devices",
        "networks": [
          {"network": "10.0.0.0", "wildcard": "0.0.0.255", "area": 0}
        ]
      }
    ]
  }
]
```
Note: Do NOT include 192.168.88.0/24 (management) in OSPF networks!

**Adding Interface to Device - CORRECT:**
First call get_device_settings to get current ports array, then:
```
path: "ports"
new_value: [
  ...existing ports from get_device_settings...,
  {
    "port_number": 5,
    "name": "FastEthernet0/5",
    "description": "New Link",
    "mode": "access",
    "access_vlan": 10
  }
]
```

**VLAN Configuration - CORRECT:**
```
path: "vlans"
new_value: [
  {"vlan_id": 10, "name": "DATA"},
  {"vlan_id": 20, "name": "VOICE"},
  {"vlan_id": 80, "name": "MANAGEMENT"}
]
```

=== FORMAT RULES ===
- Use simple paths like "hostname", "vlans" - NOT JSONPath queries
- new_value should be the ENTIRE new value for that path
- Do NOT use bracket notation like [?(@.name=="x")]

Be concise and helpful. Use markdown formatting.''';

  List<Map<String, dynamic>> get _toolDeclarations => [
    {
      'name': 'list_devices',
      'description':
          'List all devices in the current project with their basic info (id, hostname, category, group)',
      'parameters': {'type': 'object', 'properties': {}},
    },
    {
      'name': 'list_available_presets',
      'description':
          'List all available device presets that can be added to the project (those with remaining slots)',
      'parameters': {'type': 'object', 'properties': {}},
    },
    {
      'name': 'list_groups',
      'description': 'List all device groups in the current project',
      'parameters': {'type': 'object', 'properties': {}},
    },
    {
      'name': 'get_device_settings',
      'description':
          'Get the full configuration of a specific device including hostname, interfaces, VLANs, routing, etc.',
      'parameters': {
        'type': 'object',
        'properties': {
          'device_id': {
            'type': 'integer',
            'description': 'The ID of the device to get settings for',
          },
        },
        'required': ['device_id'],
      },
    },
    {
      'name': 'get_project_settings',
      'description':
          'Get the project-level settings including network services configuration (OSPF, EIGRP, HSRP, etc.)',
      'parameters': {'type': 'object', 'properties': {}},
    },
    {
      'name': 'propose_device_change',
      'description':
          'Propose a change to a device configuration. IMPORTANT: You MUST call get_device_settings first to see the ACTUAL current data. Never invent or assume values.',
      'parameters': {
        'type': 'object',
        'properties': {
          'device_id': {
            'type': 'integer',
            'description': 'The ID of the device to modify',
          },
          'path': {
            'type': 'string',
            'description':
                'Simple path to the config key. Valid: "hostname", "vlans", "ports", "channel_groups", "static_routes", "dhcp_pools", "nat_rules", "acls", "tunnels". Do NOT use JSONPath. Note: use "ports" not "interfaces".',
          },
          'new_value': {
            'type': 'string',
            'description':
                'The COMPLETE new value as JSON. Must be based on actual data from get_device_settings. Include ALL existing items plus your modifications.',
          },
          'description': {
            'type': 'string',
            'description': 'A brief description of what this change does',
          },
        },
        'required': ['device_id', 'path', 'new_value', 'description'],
      },
    },
    {
      'name': 'propose_project_change',
      'description':
          'Propose a change to project-level settings (network services like HSRP, OSPF). IMPORTANT: You MUST call get_project_settings first to get the current values. Your new_value should include all existing items plus changes.',
      'parameters': {
        'type': 'object',
        'properties': {
          'path': {
            'type': 'string',
            'description':
                'The JSON path to modify (e.g., "properties.hsrp_groups", "properties.ospf_domains")',
          },
          'new_value': {
            'type': 'string',
            'description':
                'The COMPLETE new value as a JSON string. Must be based on actual data from get_project_settings. Include ALL existing items plus your modifications.',
          },
          'description': {
            'type': 'string',
            'description': 'A brief description of what this change does',
          },
        },
        'required': ['path', 'new_value', 'description'],
      },
    },
    {
      'name': 'add_device',
      'description': 'Add a new device to the project from an available preset',
      'parameters': {
        'type': 'object',
        'properties': {
          'preset_id': {
            'type': 'integer',
            'description': 'The preset ID of the device type to add',
          },
          'hostname': {
            'type': 'string',
            'description': 'Optional custom hostname for the new device',
          },
        },
        'required': ['preset_id'],
      },
    },
    {
      'name': 'move_device_to_group',
      'description':
          'Move a device to a different group (or remove from group)',
      'parameters': {
        'type': 'object',
        'properties': {
          'device_id': {
            'type': 'integer',
            'description': 'The ID of the device to move',
          },
          'group_name': {
            'type': 'string',
            'description':
                'The name of the group to move to (empty string or null to remove from group)',
          },
        },
        'required': ['device_id'],
      },
    },
    {
      'name': 'get_config_schema',
      'description':
          'Get example JSON schemas and valid values for a specific config type. Use this to understand the correct structure before proposing changes.',
      'parameters': {
        'type': 'object',
        'properties': {
          'config_type': {
            'type': 'string',
            'description':
                'The type of config to get schema for: "channel_groups", "vlans", "static_routes", "dhcp_pools", "nat_rules", "acls", "hsrp_groups", "ospf_domains", "eigrp_domains"',
          },
          'device_id': {
            'type': 'integer',
            'description':
                'Optional device ID to check capabilities. If provided, will show what features this device supports.',
          },
        },
        'required': ['config_type'],
      },
    },
    {
      'name': 'validate_config',
      'description':
          'Validate a proposed config value before proposing it to the user. Returns validation errors or confirms the config is valid.',
      'parameters': {
        'type': 'object',
        'properties': {
          'config_type': {
            'type': 'string',
            'description':
                'The type of config: "channel_groups", "vlans", "static_routes", "dhcp_pools", "hostname", etc.',
          },
          'value': {
            'type': 'string',
            'description': 'The JSON value to validate',
          },
          'device_id': {
            'type': 'integer',
            'description':
                'Optional device ID to validate against device capabilities',
          },
        },
        'required': ['config_type', 'value'],
      },
    },
    {
      'name': 'create_group',
      'description':
          'Create a new device group by assigning devices to it. Groups are created implicitly when devices are assigned to them.',
      'parameters': {
        'type': 'object',
        'properties': {
          'group_name': {
            'type': 'string',
            'description': 'The name of the new group to create',
          },
          'device_ids': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description':
                'Optional array of device IDs to add to this group initially',
          },
        },
        'required': ['group_name'],
      },
    },
    {
      'name': 'rename_group',
      'description': 'Rename an existing device group',
      'parameters': {
        'type': 'object',
        'properties': {
          'old_name': {
            'type': 'string',
            'description': 'The current name of the group',
          },
          'new_name': {
            'type': 'string',
            'description': 'The new name for the group',
          },
        },
        'required': ['old_name', 'new_name'],
      },
    },
    {
      'name': 'delete_group',
      'description':
          'Delete a device group. Devices in the group will become ungrouped.',
      'parameters': {
        'type': 'object',
        'properties': {
          'group_name': {
            'type': 'string',
            'description': 'The name of the group to delete',
          },
        },
        'required': ['group_name'],
      },
    },
    {
      'name': 'set_device_order',
      'description':
          'Set the sort order of a device within its group. Lower numbers appear first.',
      'parameters': {
        'type': 'object',
        'properties': {
          'device_id': {
            'type': 'integer',
            'description': 'The ID of the device to reorder',
          },
          'sort_order': {
            'type': 'integer',
            'description':
                'The new sort order (lower numbers appear first, 0 is top)',
          },
        },
        'required': ['device_id', 'sort_order'],
      },
    },
    {
      'name': 'move_device_up',
      'description':
          'Move a device up one position in its group (decrease sort order)',
      'parameters': {
        'type': 'object',
        'properties': {
          'device_id': {
            'type': 'integer',
            'description': 'The ID of the device to move up',
          },
        },
        'required': ['device_id'],
      },
    },
    {
      'name': 'move_device_down',
      'description':
          'Move a device down one position in its group (increase sort order)',
      'parameters': {
        'type': 'object',
        'properties': {
          'device_id': {
            'type': 'integer',
            'description': 'The ID of the device to move down',
          },
        },
        'required': ['device_id'],
      },
    },
  ];

  /// Send a message from the user
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _isProcessing) return;

    // Add user message
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.user,
      content: content.trim(),
    );
    _messages.add(userMessage);

    // Add to conversation history
    _conversationHistory.add({
      'role': 'user',
      'parts': [
        {'text': content.trim()},
      ],
    });

    notifyListeners();

    // Process with AI
    await _processMessage();
  }

  /// Process the conversation and generate AI response
  Future<void> _processMessage() async {
    _isProcessing = true;
    notifyListeners();

    // Add a pending assistant message
    final assistantMessageId = const Uuid().v4();
    _messages.add(
      ChatMessage(
        id: assistantMessageId,
        role: ChatRole.assistant,
        content: '',
        status: MessageStatus.pending,
      ),
    );
    notifyListeners();

    try {
      List<ToolCall> toolCalls = [];
      List<JsonChange> proposedChanges = [];

      // Call Gemini API
      var response = await _callGeminiApi();

      // Handle function calls in a loop
      while (_hasFunctionCalls(response)) {
        final functionCalls = _extractFunctionCalls(response);
        final functionResponses = <Map<String, dynamic>>[];

        for (final functionCall in functionCalls) {
          final name = functionCall['name'] as String;
          final args = functionCall['args'] as Map<String, dynamic>? ?? {};

          debugPrint('Function call: $name with args: $args');

          // Execute the function and collect result
          final result = await _executeFunction(
            name,
            args,
            toolCalls,
            proposedChanges,
          );

          functionResponses.add({'name': name, 'response': result});

          // Update message immediately to show tool call progress
          final index = _messages.indexWhere((m) => m.id == assistantMessageId);
          if (index >= 0) {
            _messages[index] = ChatMessage(
              id: assistantMessageId,
              role: ChatRole.assistant,
              content: 'Processing...',
              status: MessageStatus.pending,
              toolCalls: toolCalls.isNotEmpty ? List.from(toolCalls) : null,
              proposedChanges: proposedChanges.isNotEmpty
                  ? List.from(proposedChanges)
                  : null,
            );
            notifyListeners();
          }
        }

        // Add model response to history (with thought signature if present)
        final modelContent = _extractModelContent(response);
        _conversationHistory.add(modelContent);

        // Add function responses to history
        // Note: Gemini expects role "function" for function responses
        _conversationHistory.add({
          'role': 'function',
          'parts': functionResponses
              .map(
                (fr) => {
                  'functionResponse': {
                    'name': fr['name'],
                    'response': fr['response'],
                  },
                },
              )
              .toList(),
        });

        // Call API again with function responses
        response = await _callGeminiApi();
      }

      // Get the final text response
      final responseText = _extractTextResponse(response);

      // Add final model response to history
      final finalModelContent = _extractModelContent(response);
      _conversationHistory.add(finalModelContent);

      // Update the assistant message
      final index = _messages.indexWhere((m) => m.id == assistantMessageId);
      if (index >= 0) {
        _messages[index] = ChatMessage(
          id: assistantMessageId,
          role: ChatRole.assistant,
          content: responseText,
          status: MessageStatus.complete,
          toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
          proposedChanges: proposedChanges.isNotEmpty ? proposedChanges : null,
        );
      }
    } catch (e) {
      debugPrint('Error in AI processing: $e');
      // Update with error message
      final index = _messages.indexWhere((m) => m.id == assistantMessageId);
      if (index >= 0) {
        _messages[index] = ChatMessage(
          id: assistantMessageId,
          role: ChatRole.assistant,
          content: 'Sorry, an error occurred: $e',
          status: MessageStatus.error,
        );
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Call the Gemini REST API
  Future<Map<String, dynamic>> _callGeminiApi() async {
    final url = Uri.parse(
      '$_baseUrl/${_selectedModel.modelId}:generateContent?key=$_apiKey',
    );

    final body = {
      'contents': _conversationHistory,
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt},
        ],
      },
      'tools': [
        {'functionDeclarations': _toolDeclarations},
      ],
      'generationConfig': {'temperature': 1.0},
      'toolConfig': {
        'functionCallingConfig': {'mode': 'AUTO'},
      },
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  bool _hasFunctionCalls(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return false;

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    if (content == null) return false;

    final parts = content['parts'] as List?;
    if (parts == null) return false;

    return parts.any((part) => part['functionCall'] != null);
  }

  List<Map<String, dynamic>> _extractFunctionCalls(
    Map<String, dynamic> response,
  ) {
    final candidates = response['candidates'] as List;
    final content = candidates[0]['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List;

    return parts
        .where((part) => part['functionCall'] != null)
        .map((part) => part['functionCall'] as Map<String, dynamic>)
        .toList();
  }

  Map<String, dynamic> _extractModelContent(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List;
    final content = candidates[0]['content'] as Map<String, dynamic>;
    return Map<String, dynamic>.from(content);
  }

  String _extractTextResponse(Map<String, dynamic> response) {
    final candidates = response['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      debugPrint('No candidates in response: $response');
      return 'No response received from AI.';
    }

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    if (content == null) {
      debugPrint('No content in candidate: ${candidates[0]}');
      return 'No content in AI response.';
    }

    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      debugPrint('No parts in content: $content');
      return 'Empty response from AI.';
    }

    final textParts = parts.where((part) => part['text'] != null);
    if (textParts.isEmpty) {
      // Check if there are only function calls (shouldn't happen after loop exits)
      final hasFunctionCalls = parts.any(
        (part) => part['functionCall'] != null,
      );
      if (hasFunctionCalls) {
        debugPrint('Response only contains function calls, no text');
        return 'Processing complete.';
      }
      debugPrint('No text parts in response: $parts');
      return 'No text in AI response.';
    }

    return textParts.map((part) => part['text'] as String).join('\n');
  }

  /// Execute a function call and return the result
  Future<Map<String, dynamic>> _executeFunction(
    String name,
    Map<String, dynamic> args,
    List<ToolCall> toolCalls,
    List<JsonChange> proposedChanges,
  ) async {
    try {
      switch (name) {
        case 'list_devices':
          final result = await _executeListDevices();
          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: result,
            ),
          );
          return {'success': true, 'data': result};

        case 'list_available_presets':
          final result = await _executeListAvailablePresets();
          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: result,
            ),
          );
          return {'success': true, 'data': result};

        case 'list_groups':
          final result = await _executeListGroups();
          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: result,
            ),
          );
          return {'success': true, 'data': result};

        case 'get_device_settings':
          final deviceId = args['device_id'] as int;
          final result = await _executeGetDeviceSettings(deviceId);
          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: result,
            ),
          );
          return {'success': true, 'data': result};

        case 'get_project_settings':
          final result = await _executeGetProjectSettings();
          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: result,
            ),
          );
          return {'success': true, 'data': result};

        case 'propose_device_change':
          final deviceId = args['device_id'] as int;
          final path = args['path'] as String;
          final newValueStr = args['new_value'] as String;
          final description = args['description'] as String;

          final device = _appState.devices.firstWhere(
            (d) => d.id == deviceId,
            orElse: () => throw Exception('Device with ID $deviceId not found'),
          );

          // Parse new value - try JSON first, then use as string
          dynamic newValue;
          try {
            newValue = jsonDecode(newValueStr);
          } catch (_) {
            newValue = newValueStr;
          }

          // Validate the proposed change structure
          final validationError = _validateDeviceChange(device, path, newValue);
          if (validationError != null) {
            toolCalls.add(
              ToolCall(
                id: const Uuid().v4(),
                name: name,
                arguments: args,
                status: ToolCallStatus.error,
                error: validationError,
              ),
            );
            return {'success': false, 'error': validationError};
          }

          // Get original value
          dynamic originalValue;
          if (path == 'hostname') {
            originalValue = device.hostname;
          } else if (path.startsWith('config.')) {
            final configPath = path.substring(7);
            originalValue = _getNestedValue(device.config, configPath);
          } else {
            originalValue = device.config[path];
          }

          proposedChanges.add(
            JsonChange(
              id: const Uuid().v4(),
              targetType: 'device',
              deviceId: deviceId,
              deviceName: device.hostname,
              path: path,
              description: description,
              originalValue: originalValue,
              newValue: newValue,
            ),
          );

          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: 'Change proposed for user approval',
            ),
          );
          return {
            'success': true,
            'message': 'Change proposed and awaiting user approval',
          };

        case 'propose_project_change':
          final path = args['path'] as String;
          final newValueStr = args['new_value'] as String;
          final description = args['description'] as String;

          final project = _appState.selectedProject;
          if (project == null) {
            return {'success': false, 'error': 'No project selected'};
          }

          dynamic newValue;
          try {
            newValue = jsonDecode(newValueStr);
          } catch (_) {
            newValue = newValueStr;
          }

          // Validate the proposed change structure
          final validationError = _validateProjectChange(path, newValue);
          if (validationError != null) {
            toolCalls.add(
              ToolCall(
                id: const Uuid().v4(),
                name: name,
                arguments: args,
                status: ToolCallStatus.error,
                error: validationError,
              ),
            );
            return {'success': false, 'error': validationError};
          }

          dynamic originalValue;
          if (path.startsWith('properties.')) {
            final propsPath = path.substring(11);
            originalValue = _getNestedValue(
              project.properties.toJson(),
              propsPath,
            );
          }

          proposedChanges.add(
            JsonChange(
              id: const Uuid().v4(),
              targetType: 'project',
              path: path,
              description: description,
              originalValue: originalValue,
              newValue: newValue,
            ),
          );

          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: 'Change proposed for user approval',
            ),
          );
          return {
            'success': true,
            'message': 'Change proposed and awaiting user approval',
          };

        case 'add_device':
          final presetId = args['preset_id'] as int;
          final hostname = args['hostname'] as String?;

          if (!_appState.isPresetAvailable(presetId)) {
            return {
              'success': false,
              'error': 'This preset is not available. All slots are in use.',
            };
          }

          final device = await _appState.addDevice(
            presetId,
            hostname: hostname,
          );
          if (device != null) {
            toolCalls.add(
              ToolCall(
                id: const Uuid().v4(),
                name: name,
                arguments: args,
                status: ToolCallStatus.success,
                result: 'Device ${device.hostname} added',
              ),
            );
            return {
              'success': true,
              'message': 'Device "${device.hostname}" added successfully',
              'device_id': device.id,
              'hostname': device.hostname,
            };
          } else {
            return {'success': false, 'error': 'Failed to add device'};
          }

        case 'move_device_to_group':
          final deviceId = args['device_id'] as int;
          final groupName = args['group_name'] as String?;

          await _appState.updateDeviceGroup(deviceId, groupName);
          final device = _appState.devices.firstWhere((d) => d.id == deviceId);

          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: 'Device moved',
            ),
          );

          if (groupName == null || groupName.isEmpty) {
            return {
              'success': true,
              'message': 'Device "${device.hostname}" removed from its group',
            };
          }
          return {
            'success': true,
            'message':
                'Device "${device.hostname}" moved to group "$groupName"',
          };

        case 'get_config_schema':
          final configType = args['config_type'] as String;
          final deviceId = args['device_id'] as int?;
          final result = _executeGetConfigSchema(configType, deviceId);
          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: result,
            ),
          );
          return {'success': true, 'data': result};

        case 'validate_config':
          final configType = args['config_type'] as String;
          final valueStr = args['value'] as String;
          final deviceId = args['device_id'] as int?;

          dynamic value;
          try {
            value = jsonDecode(valueStr);
          } catch (e) {
            toolCalls.add(
              ToolCall(
                id: const Uuid().v4(),
                name: name,
                arguments: args,
                status: ToolCallStatus.error,
                error: 'Invalid JSON: $e',
              ),
            );
            return {'success': false, 'error': 'Invalid JSON: $e'};
          }

          final validation = _executeValidateConfig(
            configType,
            value,
            deviceId,
          );
          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: validation['valid'] == true
                  ? ToolCallStatus.success
                  : ToolCallStatus.error,
              result: validation['message'] as String?,
              error: validation['valid'] != true
                  ? validation['error'] as String?
                  : null,
            ),
          );
          return validation;

        case 'create_group':
          final groupName = args['group_name'] as String;
          final deviceIds = args['device_ids'] as List?;

          if (groupName.trim().isEmpty) {
            return {'success': false, 'error': 'Group name cannot be empty'};
          }

          // Check if group already exists
          if (_appState.deviceGroups.contains(groupName)) {
            return {
              'success': false,
              'error': 'Group "$groupName" already exists',
            };
          }

          // If device IDs provided, move them to the group
          if (deviceIds != null && deviceIds.isNotEmpty) {
            for (final id in deviceIds) {
              await _appState.updateDeviceGroup(id as int, groupName);
            }
          } else {
            // Create an empty group - need at least one device to create a group
            return {
              'success': false,
              'error':
                  'Groups are created implicitly when devices are assigned. Please provide device_ids to create a group.',
            };
          }

          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: 'Group created with ${deviceIds.length} device(s)',
            ),
          );
          return {
            'success': true,
            'message':
                'Group "$groupName" created with ${deviceIds.length} device(s)',
          };

        case 'rename_group':
          final oldName = args['old_name'] as String;
          final newName = args['new_name'] as String;

          if (!_appState.deviceGroups.contains(oldName)) {
            return {'success': false, 'error': 'Group "$oldName" not found'};
          }

          if (newName.trim().isEmpty) {
            return {
              'success': false,
              'error': 'New group name cannot be empty',
            };
          }

          if (_appState.deviceGroups.contains(newName)) {
            return {
              'success': false,
              'error': 'Group "$newName" already exists',
            };
          }

          await _appState.renameDeviceGroup(oldName, newName);

          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: 'Group renamed',
            ),
          );
          return {
            'success': true,
            'message': 'Group "$oldName" renamed to "$newName"',
          };

        case 'delete_group':
          final groupName = args['group_name'] as String;

          if (!_appState.deviceGroups.contains(groupName)) {
            return {'success': false, 'error': 'Group "$groupName" not found'};
          }

          // Get devices in this group
          final devicesInGroup = _appState.devices
              .where((d) => d.deviceGroup == groupName)
              .toList();

          // Remove all devices from the group
          for (final device in devicesInGroup) {
            await _appState.updateDeviceGroup(device.id, null);
          }

          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result:
                  'Group deleted, ${devicesInGroup.length} device(s) ungrouped',
            ),
          );
          return {
            'success': true,
            'message':
                'Group "$groupName" deleted. ${devicesInGroup.length} device(s) are now ungrouped.',
          };

        case 'set_device_order':
          final deviceId = args['device_id'] as int;
          final sortOrder = args['sort_order'] as int;

          final device = _appState.devices.firstWhere(
            (d) => d.id == deviceId,
            orElse: () => throw Exception('Device with ID $deviceId not found'),
          );

          await _appState.updateDeviceSortOrder(deviceId, sortOrder);

          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: 'Sort order updated',
            ),
          );
          return {
            'success': true,
            'message':
                'Device "${device.hostname}" sort order set to $sortOrder',
          };

        case 'move_device_up':
          final deviceId = args['device_id'] as int;

          final device = _appState.devices.firstWhere(
            (d) => d.id == deviceId,
            orElse: () => throw Exception('Device with ID $deviceId not found'),
          );

          await _appState.moveDeviceUp(deviceId);

          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: 'Device moved up',
            ),
          );
          return {
            'success': true,
            'message': 'Device "${device.hostname}" moved up in its group',
          };

        case 'move_device_down':
          final deviceId = args['device_id'] as int;

          final device = _appState.devices.firstWhere(
            (d) => d.id == deviceId,
            orElse: () => throw Exception('Device with ID $deviceId not found'),
          );

          await _appState.moveDeviceDown(deviceId);

          toolCalls.add(
            ToolCall(
              id: const Uuid().v4(),
              name: name,
              arguments: args,
              status: ToolCallStatus.success,
              result: 'Device moved down',
            ),
          );
          return {
            'success': true,
            'message': 'Device "${device.hostname}" moved down in its group',
          };

        default:
          return {'success': false, 'error': 'Unknown function: $name'};
      }
    } catch (e) {
      toolCalls.add(
        ToolCall(
          id: const Uuid().v4(),
          name: name,
          arguments: args,
          status: ToolCallStatus.error,
          error: e.toString(),
        ),
      );
      return {'success': false, 'error': e.toString()};
    }
  }

  dynamic _getNestedValue(Map<String, dynamic> map, String path) {
    final parts = path.split('.');
    dynamic current = map;
    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  // Tool execution methods

  Future<String> _executeListDevices() async {
    final devices = _appState.devices;
    if (devices.isEmpty) {
      return 'No devices in the current project.';
    }

    final buffer = StringBuffer();
    final groupedDevices = _appState.devicesByGroup;

    // Ungrouped devices first
    final ungrouped = groupedDevices[null] ?? [];
    if (ungrouped.isNotEmpty) {
      buffer.writeln('**Ungrouped:**');
      for (final device in ungrouped) {
        buffer.writeln(
          '• ${device.hostname} (${device.category.name}, ID: ${device.id})',
        );
      }
    }

    // Grouped devices
    final sortedGroups = groupedDevices.keys.where((g) => g != null).toList()
      ..sort();
    for (final group in sortedGroups) {
      buffer.writeln('\n**$group:**');
      for (final device in groupedDevices[group]!) {
        buffer.writeln(
          '• ${device.hostname} (${device.category.name}, ID: ${device.id})',
        );
      }
    }

    return buffer.toString().trim();
  }

  Future<String> _executeListGroups() async {
    final groups = _appState.deviceGroups;
    if (groups.isEmpty) {
      return 'No device groups defined. Devices can be organized into groups.';
    }
    return groups.map((g) => '• $g').join('\n');
  }

  Future<String> _executeListAvailablePresets() async {
    final presets = _appState.availablePresetsByCategory;
    if (presets.isEmpty) {
      return 'No device presets available (all slots in use).';
    }

    final buffer = StringBuffer();
    for (final entry in presets.entries) {
      buffer.writeln('**${entry.key}:**');
      for (final preset in entry.value) {
        final remaining = _appState.getAvailableSlots(preset.id);
        buffer.writeln(
          '• ${preset.name} (${preset.sku}) - $remaining available [ID: ${preset.id}]',
        );
      }
    }
    return buffer.toString().trim();
  }

  Future<String> _executeGetDeviceSettings(int deviceId) async {
    final device = _appState.devices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw Exception('Device not found'),
    );

    final settings = {
      'id': device.id,
      'hostname': device.hostname,
      'category': device.category.name,
      'sku': device.sku,
      'group': device.deviceGroup,
      'config': device.config,
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(settings);
  }

  Future<String> _executeGetProjectSettings() async {
    final project = _appState.selectedProject;
    if (project == null) {
      return '{"error": "No project selected"}';
    }

    final settings = {
      'id': project.id,
      'name': project.name,
      'description': project.description,
      'properties': project.properties.toJson(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(settings);
  }

  /// Get config schema examples for a specific config type
  String _executeGetConfigSchema(String configType, int? deviceId) {
    final buffer = StringBuffer();

    // Check device capabilities if device ID provided
    List<String>? capabilities;
    if (deviceId != null) {
      try {
        final device = _appState.devices.firstWhere((d) => d.id == deviceId);
        capabilities = device.preset.capabilities;
        buffer.writeln(
          '**Device: ${device.hostname} (${device.preset.name})**',
        );
        buffer.writeln('Capabilities: ${capabilities.join(", ")}');
        buffer.writeln('');
      } catch (_) {
        buffer.writeln('Note: Device ID $deviceId not found.');
        buffer.writeln('');
      }
    }

    switch (configType) {
      case 'channel_groups':
        buffer.writeln('**Channel Groups Schema:**');
        buffer.writeln('```json');
        buffer.writeln('[');
        buffer.writeln('  {');
        buffer.writeln('    "group_number": 1,');
        buffer.writeln('    "name": "Port-channel1",');
        buffer.writeln(
          '    "mode": "desirable",  // "on", "active", "passive", "desirable", "auto"',
        );
        buffer.writeln(
          '    "port_indices": [9, 10],  // 0-based indices into ports array',
        );
        buffer.writeln('    "native_vlan": 1,');
        buffer.writeln(
          '    "allowed_vlans": "all"  // or "1,10,20" or "1,10-20"',
        );
        buffer.writeln('  }');
        buffer.writeln(']');
        buffer.writeln('```');
        buffer.writeln('');
        buffer.writeln('**Mode values:**');
        buffer.writeln('- "on" - Static EtherChannel, no negotiation');
        buffer.writeln('- "active" - LACP active mode');
        buffer.writeln('- "passive" - LACP passive mode');
        buffer.writeln('- "desirable" - PAgP desirable mode');
        buffer.writeln('- "auto" - PAgP auto mode');
        if (capabilities != null && !capabilities.contains('etherchannel')) {
          buffer.writeln('');
          buffer.writeln(
            '⚠️ WARNING: This device does NOT support EtherChannel!',
          );
        }
        break;

      case 'vlans':
        buffer.writeln('**VLANs Schema:**');
        buffer.writeln('```json');
        buffer.writeln('[');
        buffer.writeln('  {"vlan_id": 1, "name": "Default"},');
        buffer.writeln('  {"vlan_id": 10, "name": "Management"},');
        buffer.writeln('  {"vlan_id": 20, "name": "Users"}');
        buffer.writeln(']');
        buffer.writeln('```');
        buffer.writeln('');
        buffer.writeln(
          '**Note:** Use "vlan_id" (not "id") for the VLAN number.',
        );
        buffer.writeln('**Reserved VLANs (cannot modify):** 1, 1002-1005');
        if (capabilities != null && !capabilities.contains('vlan')) {
          buffer.writeln('');
          buffer.writeln('⚠️ WARNING: This device does NOT support VLANs!');
        }
        break;

      case 'static_routes':
        buffer.writeln('**Static Routes Schema:**');
        buffer.writeln('```json');
        buffer.writeln('[');
        buffer.writeln('  {');
        buffer.writeln('    "network": "10.0.0.0/8",');
        buffer.writeln('    "next_hop": "192.168.1.1",');
        buffer.writeln('    "administrative_distance": 1');
        buffer.writeln('  },');
        buffer.writeln('  {');
        buffer.writeln('    "network": "0.0.0.0/0",');
        buffer.writeln('    "exit_interface": "GigabitEthernet 0/0"');
        buffer.writeln('  }');
        buffer.writeln(']');
        buffer.writeln('```');
        if (capabilities != null && !capabilities.contains('static-routing')) {
          buffer.writeln('');
          buffer.writeln(
            '⚠️ WARNING: This device does NOT support static routing!',
          );
        }
        break;

      case 'dhcp_pools':
        buffer.writeln('**DHCP Pools Schema:**');
        buffer.writeln('```json');
        buffer.writeln('[');
        buffer.writeln('  {');
        buffer.writeln('    "name": "POOL1",');
        buffer.writeln('    "network": "192.168.1.0/24",');
        buffer.writeln('    "default_router": "192.168.1.1",');
        buffer.writeln('    "dns_servers": ["8.8.8.8", "8.8.4.4"],');
        buffer.writeln(
          '    "excluded_addresses": ["192.168.1.1", "192.168.1.254"]',
        );
        buffer.writeln('  }');
        buffer.writeln(']');
        buffer.writeln('```');
        if (capabilities != null && !capabilities.contains('dhcp-server')) {
          buffer.writeln('');
          buffer.writeln(
            '⚠️ WARNING: This device does NOT support DHCP server!',
          );
        }
        break;

      case 'nat_rules':
        buffer.writeln('**NAT Rules Schema:**');
        buffer.writeln('```json');
        buffer.writeln('[');
        buffer.writeln('  {');
        buffer.writeln(
          '    "type": "overload",  // "static", "dynamic", "overload"',
        );
        buffer.writeln('    "inside_interface": "GigabitEthernet 0/0",');
        buffer.writeln('    "outside_interface": "GigabitEthernet 0/1",');
        buffer.writeln('    "acl": "1"');
        buffer.writeln('  }');
        buffer.writeln(']');
        buffer.writeln('```');
        if (capabilities != null && !capabilities.contains('nat')) {
          buffer.writeln('');
          buffer.writeln('⚠️ WARNING: This device does NOT support NAT!');
        }
        break;

      case 'hsrp_groups':
        buffer.writeln('**HSRP Groups Schema (PROJECT-LEVEL):**');
        buffer.writeln('⚠️ HSRP is stored at PROJECT level, not per device!');
        buffer.writeln(
          'Use propose_project_change with path "properties.hsrp_groups"',
        );
        buffer.writeln('');
        buffer.writeln('```json');
        buffer.writeln('[');
        buffer.writeln('  {');
        buffer.writeln('    "name": "HSRP-VLAN10",');
        buffer.writeln('    "group_number": 10,');
        buffer.writeln('    "vlan_id": 10,');
        buffer.writeln('    "virtual_ip": "192.168.10.1/24",');
        buffer.writeln('    "version": 2,  // 1 or 2');
        buffer.writeln('    "enabled": true,');
        buffer.writeln('    "hello_timer": 3,');
        buffer.writeln('    "hold_timer": 10,');
        buffer.writeln('    "members": [');
        buffer.writeln('      {');
        buffer.writeln('        "device_id": 54,');
        buffer.writeln('        "interface_name": "FastEthernet 0/0",');
        buffer.writeln('        "priority": 110,  // Higher = active');
        buffer.writeln('        "preempt": true');
        buffer.writeln('      },');
        buffer.writeln('      {');
        buffer.writeln('        "device_id": 55,');
        buffer.writeln('        "interface_name": "FastEthernet 0/0",');
        buffer.writeln('        "priority": 100,');
        buffer.writeln('        "preempt": true');
        buffer.writeln('      }');
        buffer.writeln('    ]');
        buffer.writeln('  }');
        buffer.writeln(']');
        buffer.writeln('```');
        break;

      case 'ospf_domains':
        buffer.writeln('**OSPF Domains Schema (PROJECT-LEVEL):**');
        buffer.writeln('⚠️ OSPF is stored at PROJECT level, not per device!');
        buffer.writeln(
          'Use propose_project_change with path "properties.ospf_domains"',
        );
        buffer.writeln('');
        buffer.writeln('```json');
        buffer.writeln('[');
        buffer.writeln('  {');
        buffer.writeln('    "name": "OSPF-Area0",');
        buffer.writeln('    "process_id": 1,');
        buffer.writeln('    "router_id": "1.1.1.1",');
        buffer.writeln('    "areas": [');
        buffer.writeln('      {');
        buffer.writeln('        "area_id": "0",');
        buffer.writeln('        "type": "normal"  // "normal", "stub", "nssa"');
        buffer.writeln('      }');
        buffer.writeln('    ],');
        buffer.writeln('    "networks": [');
        buffer.writeln('      {');
        buffer.writeln('        "network": "10.0.0.0",');
        buffer.writeln('        "wildcard": "0.0.0.255",');
        buffer.writeln('        "area": "0"');
        buffer.writeln('      }');
        buffer.writeln('    ]');
        buffer.writeln('  }');
        buffer.writeln(']');
        buffer.writeln('```');
        break;

      case 'eigrp_domains':
        buffer.writeln('**EIGRP Domains Schema (PROJECT-LEVEL):**');
        buffer.writeln('⚠️ EIGRP is stored at PROJECT level, not per device!');
        buffer.writeln(
          'Use propose_project_change with path "properties.eigrp_domains"',
        );
        buffer.writeln('');
        buffer.writeln('```json');
        buffer.writeln('[');
        buffer.writeln('  {');
        buffer.writeln('    "name": "EIGRP-AS100",');
        buffer.writeln('    "as_number": 100,');
        buffer.writeln('    "networks": ["10.0.0.0/8", "192.168.0.0/16"],');
        buffer.writeln('    "auto_summary": false');
        buffer.writeln('  }');
        buffer.writeln(']');
        buffer.writeln('```');
        break;

      case 'acls':
        buffer.writeln('**ACLs Schema:**');
        buffer.writeln('```json');
        buffer.writeln('[');
        buffer.writeln('  {');
        buffer.writeln('    "number": 1,  // 1-99 standard, 100-199 extended');
        buffer.writeln('    "name": "BLOCK-RFC1918",');
        buffer.writeln('    "type": "standard",  // "standard" or "extended"');
        buffer.writeln('    "entries": [');
        buffer.writeln('      {');
        buffer.writeln('        "action": "deny",');
        buffer.writeln('        "source": "10.0.0.0",');
        buffer.writeln('        "source_wildcard": "0.255.255.255"');
        buffer.writeln('      },');
        buffer.writeln('      {');
        buffer.writeln('        "action": "permit",');
        buffer.writeln('        "source": "any"');
        buffer.writeln('      }');
        buffer.writeln('    ]');
        buffer.writeln('  }');
        buffer.writeln(']');
        buffer.writeln('```');
        break;

      default:
        buffer.writeln('Unknown config type: $configType');
        buffer.writeln('');
        buffer.writeln('**Available types:**');
        buffer.writeln(
          '- Device configs: channel_groups, vlans, static_routes, dhcp_pools, nat_rules, acls',
        );
        buffer.writeln(
          '- Project configs: hsrp_groups, ospf_domains, eigrp_domains',
        );
    }

    return buffer.toString().trim();
  }

  /// Validate a proposed config value
  Map<String, dynamic> _executeValidateConfig(
    String configType,
    dynamic value,
    int? deviceId,
  ) {
    // Check device capabilities if provided
    List<String>? capabilities;
    if (deviceId != null) {
      try {
        final device = _appState.devices.firstWhere((d) => d.id == deviceId);
        capabilities = device.preset.capabilities;
      } catch (_) {
        return {'valid': false, 'error': 'Device with ID $deviceId not found'};
      }
    }

    switch (configType) {
      case 'hostname':
        if (value is! String || value.isEmpty) {
          return {
            'valid': false,
            'error': 'Hostname must be a non-empty string',
          };
        }
        if (value.contains(' ')) {
          return {'valid': false, 'error': 'Hostname cannot contain spaces'};
        }
        return {'valid': true, 'message': 'Valid hostname'};

      case 'channel_groups':
        if (capabilities != null && !capabilities.contains('etherchannel')) {
          return {
            'valid': false,
            'error': 'This device does not support EtherChannel',
          };
        }
        if (value is! List) {
          return {'valid': false, 'error': 'channel_groups must be an array'};
        }
        for (int i = 0; i < value.length; i++) {
          final group = value[i];
          if (group is! Map) {
            return {'valid': false, 'error': 'Item $i must be an object'};
          }
          if (group['group_number'] is! int) {
            return {
              'valid': false,
              'error': 'Item $i: group_number must be an integer',
            };
          }
          if (group['name'] is! String) {
            return {'valid': false, 'error': 'Item $i: name must be a string'};
          }
          if (group['mode'] is! String) {
            return {'valid': false, 'error': 'Item $i: mode must be a string'};
          }
          final validModes = ['on', 'active', 'passive', 'desirable', 'auto'];
          if (!validModes.contains(group['mode'])) {
            return {
              'valid': false,
              'error': 'Item $i: mode must be one of: ${validModes.join(", ")}',
            };
          }
          if (group['port_indices'] is! List) {
            return {
              'valid': false,
              'error': 'Item $i: port_indices must be an array of integers',
            };
          }
        }
        return {'valid': true, 'message': 'Valid channel_groups configuration'};

      case 'vlans':
        if (capabilities != null && !capabilities.contains('vlan')) {
          return {
            'valid': false,
            'error': 'This device does not support VLANs',
          };
        }
        if (value is! List) {
          return {'valid': false, 'error': 'vlans must be an array'};
        }
        for (int i = 0; i < value.length; i++) {
          final vlan = value[i];
          if (vlan is! Map) {
            return {'valid': false, 'error': 'Item $i must be an object'};
          }
          // Accept both 'vlan_id' (preferred) and 'id'
          final hasVlanId = vlan['vlan_id'] is int;
          final hasId = vlan['id'] is int;
          if (!hasVlanId && !hasId) {
            return {
              'valid': false,
              'error': 'Item $i: vlan_id must be an integer',
            };
          }
          if (vlan['name'] is! String) {
            return {'valid': false, 'error': 'Item $i: name must be a string'};
          }
        }
        return {'valid': true, 'message': 'Valid vlans configuration'};

      case 'static_routes':
        if (capabilities != null && !capabilities.contains('static-routing')) {
          return {
            'valid': false,
            'error': 'This device does not support static routing',
          };
        }
        if (value is! List) {
          return {'valid': false, 'error': 'static_routes must be an array'};
        }
        for (int i = 0; i < value.length; i++) {
          final route = value[i];
          if (route is! Map) {
            return {'valid': false, 'error': 'Item $i must be an object'};
          }
          if (route['network'] is! String) {
            return {
              'valid': false,
              'error': 'Item $i: network must be a string (CIDR format)',
            };
          }
          if (route['next_hop'] == null && route['exit_interface'] == null) {
            return {
              'valid': false,
              'error': 'Item $i: must have next_hop or exit_interface',
            };
          }
        }
        return {'valid': true, 'message': 'Valid static_routes configuration'};

      case 'dhcp_pools':
        if (capabilities != null && !capabilities.contains('dhcp-server')) {
          return {
            'valid': false,
            'error': 'This device does not support DHCP server',
          };
        }
        if (value is! List) {
          return {'valid': false, 'error': 'dhcp_pools must be an array'};
        }
        for (int i = 0; i < value.length; i++) {
          final pool = value[i];
          if (pool is! Map) {
            return {'valid': false, 'error': 'Item $i must be an object'};
          }
          if (pool['name'] is! String) {
            return {'valid': false, 'error': 'Item $i: name must be a string'};
          }
          if (pool['network'] is! String) {
            return {
              'valid': false,
              'error': 'Item $i: network must be a string (CIDR format)',
            };
          }
        }
        return {'valid': true, 'message': 'Valid dhcp_pools configuration'};

      default:
        return {
          'valid': true,
          'message': 'Config type "$configType" has no specific validation',
        };
    }
  }

  /// Accept a proposed change
  Future<void> acceptChange(String changeId) async {
    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message.proposedChanges == null) continue;

      final changeIndex = message.proposedChanges!.indexWhere(
        (c) => c.id == changeId,
      );
      if (changeIndex >= 0) {
        final change = message.proposedChanges![changeIndex];

        try {
          // Apply the change
          if (change.targetType == 'device' && change.deviceId != null) {
            await _applyDeviceChange(change);
          } else if (change.targetType == 'project') {
            await _applyProjectChange(change);
          }

          // Update change status
          final updatedChanges = List<JsonChange>.from(
            message.proposedChanges!,
          );
          updatedChanges[changeIndex] = change.copyWith(
            status: JsonChangeStatus.accepted,
          );
          _messages[i] = message.copyWith(proposedChanges: updatedChanges);
          notifyListeners();
        } catch (e) {
          debugPrint('Error applying change: $e');
        }
        break;
      }
    }
  }

  /// Decline a proposed change
  void declineChange(String changeId) {
    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message.proposedChanges == null) continue;

      final changeIndex = message.proposedChanges!.indexWhere(
        (c) => c.id == changeId,
      );
      if (changeIndex >= 0) {
        final updatedChanges = List<JsonChange>.from(message.proposedChanges!);
        updatedChanges[changeIndex] = message.proposedChanges![changeIndex]
            .copyWith(status: JsonChangeStatus.declined);
        _messages[i] = message.copyWith(proposedChanges: updatedChanges);
        notifyListeners();
        break;
      }
    }
  }

  Future<void> _applyDeviceChange(JsonChange change) async {
    final device = _appState.devices.firstWhere((d) => d.id == change.deviceId);

    // Handle different paths
    if (change.path == 'hostname') {
      await Database.updateDeviceConfig(device.id, {
        'hostname': change.newValue,
      });
      // Update local state
      device.config['hostname'] = change.newValue;
    } else if (change.path == 'ports') {
      // Special handling for ports - merge with defaults, don't replace
      if (change.newValue is! List) {
        throw Exception(
          'Ports must be an array. Got: ${change.newValue.runtimeType}. '
          'The AI should call get_device_settings first to see the correct format.',
        );
      }
      await _applyPortsChange(device, change.newValue as List);
    } else if (change.path.startsWith('config.')) {
      final configPath = change.path.substring(7); // Remove 'config.' prefix
      final config = Map<String, dynamic>.from(device.config);
      _setNestedValue(config, configPath, change.newValue);
      await Database.updateDeviceConfig(device.id, config);
      // Update local state
      device.config.addAll(config);
    } else {
      // Direct config update
      await Database.updateDeviceConfig(device.id, {
        change.path: change.newValue,
      });
      // Update local state
      device.config[change.path] = change.newValue;
    }

    // Notify app state that device changed
    _appState.notifyListeners();
  }

  /// Apply ports/interfaces change by merging with existing ports
  /// This ensures preset interfaces aren't deleted, only modified or subinterfaces added
  Future<void> _applyPortsChange(
    NetDevice device,
    List<dynamic> proposedPorts,
  ) async {
    // Get current interfaces (from config or preset defaults)
    final currentPorts = device.interfaces;
    final defaultPorts = device.preset.defaultInterfaces();

    // Build a map of proposed ports by name for lookup
    final proposedByName = <String, Map<String, dynamic>>{};
    for (final port in proposedPorts) {
      if (port is Map<String, dynamic> && port['name'] != null) {
        proposedByName[port['name'] as String] = port;
      }
    }

    // Start with existing/default ports and merge in proposed changes
    final mergedPorts = <Map<String, dynamic>>[];
    final usedNames = <String>{};

    // First, keep all default ports (can't be deleted) and apply any overrides
    for (int i = 0; i < defaultPorts.length; i++) {
      final defaultPort = defaultPorts[i];
      final portName = defaultPort.name;
      usedNames.add(portName);

      if (proposedByName.containsKey(portName)) {
        // AI proposed changes to this port - use the proposed version
        mergedPorts.add(proposedByName[portName]!);
      } else if (i < currentPorts.length) {
        // Keep current config for this port
        mergedPorts.add(currentPorts[i].toJson());
      } else {
        // Use default
        mergedPorts.add(defaultPort.toJson());
      }
    }

    // Then add any new ports (like subinterfaces) that AI proposed
    for (final port in proposedPorts) {
      if (port is Map<String, dynamic> && port['name'] != null) {
        final name = port['name'] as String;
        if (!usedNames.contains(name)) {
          // New port (likely a subinterface)
          mergedPorts.add(port);
          usedNames.add(name);
        }
      }
    }

    // Filter out null values from all ports before saving
    final cleanedPorts = mergedPorts
        .map((port) => _removeNullValues(port))
        .toList();

    // Save merged ports
    await Database.updateDeviceConfig(device.id, {'ports': cleanedPorts});
    device.config['ports'] = cleanedPorts;
  }

  /// Recursively remove null values from a map
  Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.value == null) continue;
      if (entry.value is Map<String, dynamic>) {
        result[entry.key] = _removeNullValues(
          entry.value as Map<String, dynamic>,
        );
      } else if (entry.value is List) {
        result[entry.key] = (entry.value as List)
            .map(
              (item) =>
                  item is Map<String, dynamic> ? _removeNullValues(item) : item,
            )
            .toList();
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Future<void> _applyProjectChange(JsonChange change) async {
    final project = _appState.selectedProject;
    if (project == null) return;

    // Handle properties path
    if (change.path.startsWith('properties.')) {
      final propsPath = change.path.substring(
        11,
      ); // Remove 'properties.' prefix

      // Get current properties as JSON, modify, then create new ProjectProperties
      final propsJson = project.properties.toJson();
      _setNestedValue(propsJson, propsPath, change.newValue);

      // Create new ProjectProperties from modified JSON and update
      final newProperties = ProjectProperties.fromJson(propsJson);
      await project.updateProperties(newProperties);

      // Notify app state that project changed
      _appState.notifyListeners();
    }
  }

  void _setNestedValue(Map<String, dynamic> map, String path, dynamic value) {
    final parts = path.split('.');
    var current = map;
    for (int i = 0; i < parts.length - 1; i++) {
      current.putIfAbsent(parts[i], () => <String, dynamic>{});
      current = current[parts[i]] as Map<String, dynamic>;
    }
    current[parts.last] = value;
  }

  /// Accept all pending changes across all messages
  Future<void> acceptAllPendingChanges() async {
    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message.proposedChanges == null) continue;

      final updatedChanges = List<JsonChange>.from(message.proposedChanges!);
      bool hasChanges = false;

      for (int j = 0; j < updatedChanges.length; j++) {
        final change = updatedChanges[j];
        if (change.status != JsonChangeStatus.pending) continue;

        try {
          // Apply the change
          if (change.targetType == 'device' && change.deviceId != null) {
            await _applyDeviceChange(change);
          } else if (change.targetType == 'project') {
            await _applyProjectChange(change);
          }

          updatedChanges[j] = change.copyWith(
            status: JsonChangeStatus.accepted,
          );
          hasChanges = true;
        } catch (e) {
          debugPrint('Error applying change: $e');
          // Mark as error but continue with others
        }
      }

      if (hasChanges) {
        _messages[i] = message.copyWith(proposedChanges: updatedChanges);
      }
    }
    notifyListeners();
  }

  /// Check if there are any pending changes
  bool get hasPendingChanges {
    for (final message in _messages) {
      if (message.proposedChanges == null) continue;
      for (final change in message.proposedChanges!) {
        if (change.status == JsonChangeStatus.pending) return true;
      }
    }
    return false;
  }

  /// Get count of pending changes
  int get pendingChangesCount {
    int count = 0;
    for (final message in _messages) {
      if (message.proposedChanges == null) continue;
      for (final change in message.proposedChanges!) {
        if (change.status == JsonChangeStatus.pending) count++;
      }
    }
    return count;
  }

  /// Validate device change before proposing
  String? _validateDeviceChange(dynamic device, String path, dynamic newValue) {
    // Check for invalid JSONPath-style paths
    if (path.contains('[') || path.contains('?') || path.contains('@')) {
      return 'Invalid path format. Use simple paths like "hostname", "vlans", "channel_groups". JSONPath bracket notation is not supported.';
    }

    // Validate based on path
    switch (path) {
      case 'hostname':
        if (newValue is! String || newValue.isEmpty) {
          return 'Hostname must be a non-empty string.';
        }
        if (newValue.contains(' ')) {
          return 'Hostname cannot contain spaces.';
        }
        break;

      case 'vlans':
        if (newValue is! List) {
          return 'VLANs must be an array.';
        }
        for (final vlan in newValue) {
          if (vlan is! Map) {
            return 'Each VLAN must be an object.';
          }
          // VLAN ID can be 'vlan_id' (preferred) or 'id'
          final hasVlanId =
              vlan.containsKey('vlan_id') && vlan['vlan_id'] is int;
          final hasId = vlan.containsKey('id') && vlan['id'] is int;
          if (!hasVlanId && !hasId) {
            return 'Each VLAN must have "vlan_id" (integer). Example: {"vlan_id": 10, "name": "Users"}';
          }
          if (!vlan.containsKey('name') || vlan['name'] is! String) {
            return 'Each VLAN must have a "name" (string).';
          }
        }
        break;

      case 'channel_groups':
        if (newValue is! List) {
          return 'Channel groups must be an array.';
        }
        for (final group in newValue) {
          if (group is! Map) {
            return 'Each channel group must be an object.';
          }
          if (!group.containsKey('group_number') ||
              group['group_number'] is! int) {
            return 'Each channel group must have "group_number" (integer).';
          }
          if (!group.containsKey('name') || group['name'] is! String) {
            return 'Each channel group must have "name" (string, e.g., "Port-channel1").';
          }
          if (!group.containsKey('mode') || group['mode'] is! String) {
            return 'Each channel group must have "mode" (string: "on", "active", "passive", "desirable", "auto").';
          }
          final validModes = ['on', 'active', 'passive', 'desirable', 'auto'];
          if (!validModes.contains(group['mode'])) {
            return 'Channel group mode must be one of: ${validModes.join(", ")}.';
          }
          if (!group.containsKey('port_indices') ||
              group['port_indices'] is! List) {
            return 'Each channel group must have "port_indices" (array of integers).';
          }
        }
        break;

      case 'static_routes':
        if (newValue is! List) {
          return 'Static routes must be an array.';
        }
        for (final route in newValue) {
          if (route is! Map) {
            return 'Each static route must be an object.';
          }
          if (!route.containsKey('network') || route['network'] is! String) {
            return 'Each static route must have "network" (string with CIDR, e.g., "10.0.0.0/8").';
          }
          if (!route.containsKey('next_hop') &&
              !route.containsKey('exit_interface')) {
            return 'Each static route must have either "next_hop" or "exit_interface".';
          }
        }
        break;

      case 'dhcp_pools':
        if (newValue is! List) {
          return 'DHCP pools must be an array.';
        }
        for (final pool in newValue) {
          if (pool is! Map) {
            return 'Each DHCP pool must be an object.';
          }
          if (!pool.containsKey('name') || pool['name'] is! String) {
            return 'Each DHCP pool must have "name" (string).';
          }
          if (!pool.containsKey('network') || pool['network'] is! String) {
            return 'Each DHCP pool must have "network" (string with CIDR).';
          }
        }
        break;

      case 'ports':
        if (newValue is! List) {
          return 'Ports must be an array. Got: ${newValue.runtimeType}';
        }
        for (final port in newValue) {
          if (port is! Map) {
            return 'Each port must be an object with name, port_number, etc.';
          }
          if (!port.containsKey('name') || port['name'] is! String) {
            return 'Each port must have "name" (string, e.g., "FastEthernet0/0").';
          }
        }
        break;

      case 'nat_rules':
        if (newValue is! List) {
          return 'NAT rules must be an array. Got: ${newValue.runtimeType}';
        }
        for (final rule in newValue) {
          if (rule is! Map) {
            return 'Each NAT rule must be an object.';
          }
          if (!rule.containsKey('type') || rule['type'] is! String) {
            return 'Each NAT rule must have "type" (string: "static", "dynamic", "overload", "pat").';
          }
        }
        break;

      case 'acls':
        if (newValue is! List) {
          return 'ACLs must be an array. Got: ${newValue.runtimeType}';
        }
        for (final acl in newValue) {
          if (acl is! Map) {
            return 'Each ACL must be an object.';
          }
          if (!acl.containsKey('name') || acl['name'] is! String) {
            return 'Each ACL must have "name" (string or number as string).';
          }
          if (acl.containsKey('entries') && acl['entries'] is! List) {
            return 'ACL entries must be an array.';
          }
        }
        break;

      default:
        // Unknown path - check if it's a valid config key
        final validPaths = [
          'hostname',
          'vlans',
          'ports',
          'channel_groups',
          'static_routes',
          'dhcp_pools',
          'nat_rules',
          'acls',
          'tunnels',
        ];
        if (!validPaths.contains(path) && !path.startsWith('config.')) {
          return 'Unknown config path "$path". Valid paths: ${validPaths.join(", ")}.';
        }
    }

    return null; // Valid
  }

  /// Validate project change before proposing
  String? _validateProjectChange(String path, dynamic newValue) {
    // Check for invalid JSONPath-style paths
    if (path.contains('[') && path.contains('?')) {
      return 'Invalid path format. Use simple paths like "properties.ospf_domains". JSONPath bracket notation is not supported.';
    }

    // Valid project property paths
    final validPaths = [
      'properties.ospf_domains',
      'properties.eigrp_domains',
      'properties.bgp_domains',
      'properties.hsrp_groups',
      'properties.vrf_configs',
      'properties.static_routes',
      'properties.switch_stacks',
    ];

    if (!validPaths.contains(path) && !path.startsWith('properties.')) {
      return 'Unknown project path "$path". Valid paths: ${validPaths.join(", ")}.';
    }

    // All project properties are arrays
    if (newValue is! List) {
      return 'Project properties must be arrays.';
    }

    return null; // Valid
  }

  /// Clear chat history and reset the chat session
  void clearMessages() {
    _messages.clear();
    _conversationHistory.clear();
    notifyListeners();
  }
}
