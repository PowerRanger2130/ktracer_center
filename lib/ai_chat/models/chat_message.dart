import 'dart:convert';

enum ChatRole { user, assistant, system }

enum MessageStatus { pending, complete, error }

/// Represents a chat message in the AI chat
class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final List<ToolCall>? toolCalls;
  final List<JsonChange>? proposedChanges;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.status = MessageStatus.complete,
    this.toolCalls,
    this.proposedChanges,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    List<ToolCall>? toolCalls,
    List<JsonChange>? proposedChanges,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      toolCalls: toolCalls ?? this.toolCalls,
      proposedChanges: proposedChanges ?? this.proposedChanges,
    );
  }
}

/// Represents a tool call made by the AI
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final ToolCallStatus status;
  final dynamic result;
  final String? error;

  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.status = ToolCallStatus.pending,
    this.result,
    this.error,
  });

  ToolCall copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? arguments,
    ToolCallStatus? status,
    dynamic result,
    String? error,
  }) {
    return ToolCall(
      id: id ?? this.id,
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

enum ToolCallStatus { pending, running, success, error }

/// Represents a proposed JSON change from the AI
class JsonChange {
  final String id;
  final String targetType; // 'device', 'project'
  final int? deviceId;
  final String? deviceName;
  final String path; // JSON path like 'config.hostname' or 'properties.ospf'
  final String description;
  final dynamic originalValue;
  final dynamic newValue;
  final JsonChangeStatus status;

  JsonChange({
    required this.id,
    required this.targetType,
    this.deviceId,
    this.deviceName,
    required this.path,
    required this.description,
    required this.originalValue,
    required this.newValue,
    this.status = JsonChangeStatus.pending,
  });

  JsonChange copyWith({
    String? id,
    String? targetType,
    int? deviceId,
    String? deviceName,
    String? path,
    String? description,
    dynamic originalValue,
    dynamic newValue,
    JsonChangeStatus? status,
  }) {
    return JsonChange(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      path: path ?? this.path,
      description: description ?? this.description,
      originalValue: originalValue ?? this.originalValue,
      newValue: newValue ?? this.newValue,
      status: status ?? this.status,
    );
  }

  /// Get formatted JSON for display
  String get originalJson => _formatJson(originalValue);
  String get newJson => _formatJson(newValue);

  String _formatJson(dynamic value) {
    if (value == null) return 'null';
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(value);
  }
}

enum JsonChangeStatus { pending, accepted, declined }
