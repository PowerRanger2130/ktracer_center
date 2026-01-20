// ignore_for_file: unintended_html_in_doc_comment

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A type adapter that handles conversion between runtime values and storage values.
abstract class SyncedTypeAdapter<T> {
  /// Convert a value from the server/storage to the runtime type.
  T fromStorage(dynamic value, T currentValue);

  /// Convert a runtime value to the storage format.
  dynamic toStorage(T value);

  /// Get the default value for this type.
  T get defaultValue;

  /// Check if two values are equal.
  bool equals(T a, T b) => a == b;
}

/// Adapter for String values with debouncing support.
class StringAdapter extends SyncedTypeAdapter<String> {
  @override
  String fromStorage(dynamic value, String currentValue) =>
      value?.toString() ?? '';

  @override
  dynamic toStorage(String value) => value;

  @override
  String get defaultValue => '';
}

/// Adapter for bool values.
class BoolAdapter extends SyncedTypeAdapter<bool> {
  @override
  bool fromStorage(dynamic value, bool currentValue) =>
      value is bool ? value : (value == true || value == 'true');

  @override
  dynamic toStorage(bool value) => value;

  @override
  bool get defaultValue => false;
}

/// Adapter for int values.
class IntAdapter extends SyncedTypeAdapter<int> {
  final int defaultVal;

  IntAdapter({this.defaultVal = 0});

  @override
  int fromStorage(dynamic value, int currentValue) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? currentValue;
  }

  @override
  dynamic toStorage(int value) => value;

  @override
  int get defaultValue => defaultVal;
}

/// Adapter for Enum values.
class EnumAdapter<T extends Enum> extends SyncedTypeAdapter<T> {
  final List<T> values;
  final T defaultVal;

  EnumAdapter({required this.values, required this.defaultVal});

  @override
  T fromStorage(dynamic value, T currentValue) {
    if (value == null) return currentValue;
    final strValue = value.toString();
    return values.firstWhere(
      (e) => e.name == strValue,
      orElse: () => currentValue,
    );
  }

  @override
  dynamic toStorage(T value) => value.name;

  @override
  T get defaultValue => defaultVal;
}

/// Adapter for Set<int> values stored as comma-separated strings.
class IntSetAdapter extends SyncedTypeAdapter<Set<int>> {
  final String emptyValue;

  IntSetAdapter({this.emptyValue = 'all'});

  @override
  Set<int> fromStorage(dynamic value, Set<int> currentValue) {
    if (value == null || value == emptyValue || value == '') {
      return {};
    }
    return _parseIntSet(value.toString());
  }

  @override
  dynamic toStorage(Set<int> value) {
    if (value.isEmpty) return emptyValue;
    final sorted = value.toList()..sort();
    return sorted.join(',');
  }

  @override
  Set<int> get defaultValue => {};

  @override
  bool equals(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    return a.every((e) => b.contains(e));
  }

  Set<int> _parseIntSet(String value) {
    final result = <int>{};
    for (final part in value.split(',')) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final range = trimmed.split('-');
        if (range.length == 2) {
          final start = int.tryParse(range[0].trim());
          final end = int.tryParse(range[1].trim());
          if (start != null && end != null) {
            for (var i = start; i <= end; i++) {
              result.add(i);
            }
          }
        }
      } else {
        final id = int.tryParse(trimmed);
        if (id != null) result.add(id);
      }
    }
    return result;
  }
}

/// Adapter for Set<String> values stored as comma-separated strings.
class StringSetAdapter extends SyncedTypeAdapter<Set<String>> {
  final String emptyValue;

  StringSetAdapter({this.emptyValue = ''});

  @override
  Set<String> fromStorage(dynamic value, Set<String> currentValue) {
    if (value == null || value == emptyValue || value == '') {
      return {};
    }
    return _parseStringSet(value.toString());
  }

  @override
  dynamic toStorage(Set<String> value) {
    if (value.isEmpty) return emptyValue;
    return value.join(',');
  }

  @override
  Set<String> get defaultValue => {};

  @override
  bool equals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every((e) => b.contains(e));
  }

  Set<String> _parseStringSet(String value) {
    final result = <String>{};
    for (final part in value.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        result.add(trimmed);
      }
    }
    return result;
  }
}

/// A unified synced controller that handles any type T.
/// Extends ValueNotifier for easy integration with Flutter widgets.
class SyncedController<T> extends ValueNotifier<T> {
  final Future<void> Function(dynamic value) _onSave;
  final SyncedTypeAdapter<T> _adapter;
  final Duration debounceDuration;
  Timer? _debounce;
  bool _isPendingSave = false;

  /// For String type, we also expose a TextEditingController for convenience.
  TextEditingController? _textController;

  SyncedController({
    required Future<void> Function(dynamic value) onSave,
    required SyncedTypeAdapter<T> adapter,
    T? initialValue,
    this.debounceDuration = const Duration(milliseconds: 500),
  }) : _onSave = onSave,
       _adapter = adapter,
       super(initialValue ?? adapter.defaultValue) {
    // Create TextEditingController for String types
    if (T == String) {
      _textController = TextEditingController(text: value as String);
    }
  }

  /// Get the TextEditingController (only for String type).
  TextEditingController get controller {
    if (_textController == null) {
      throw StateError(
        'TextEditingController is only available for SyncedController<String>',
      );
    }
    return _textController!;
  }

  /// Updates the controller with a value from the server.
  void serverUpdate(dynamic rawValue) {
    final newValue = _adapter.fromStorage(rawValue, value);
    if (_adapter.equals(value, newValue)) return;

    // If user is typing (debounce active), don't interrupt
    if (_isPendingSave) return;

    value = newValue;
    _textController?.text = value as String;
  }

  /// Call this method when the value changes (e.g., from onChanged callback).
  void onChanged(T? newValue) {
    if (newValue == null) return;
    value = newValue;

    // For String types, use debouncing
    if (T == String) {
      _isPendingSave = true;
      _debounce?.cancel();
      _debounce = Timer(debounceDuration, () async {
        _isPendingSave = false;
        await _onSave(_adapter.toStorage(value));
      });
    } else {
      // For other types, save immediately
      _onSave(_adapter.toStorage(value));
    }
  }

  /// Convenience method for String onChanged that takes String directly.
  void onTextChanged(String newValue) {
    if (T != String) {
      throw StateError(
        'onTextChanged is only available for SyncedController<String>',
      );
    }
    onChanged(newValue as T);
  }

  /// Resets the controller to a new value, cancelling any pending saves.
  void reset(T newValue) {
    _debounce?.cancel();
    _isPendingSave = false;
    value = newValue;
    _textController?.text = value as String;
  }

  /// Reset from a raw storage value.
  void resetFromStorage(dynamic rawValue) {
    reset(_adapter.fromStorage(rawValue, _adapter.defaultValue));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController?.dispose();
    super.dispose();
  }
}

// Type aliases for convenience
typedef SyncedString = SyncedController<String>;
typedef SyncedBool = SyncedController<bool>;
typedef SyncedInt = SyncedController<int>;
typedef SyncedIntSet = SyncedController<Set<int>>;

/// Manages multiple [SyncedController]s for a single database row.
/// Handles realtime subscriptions and updates.
class RealtimeForm {
  final String tableName;
  final String primaryKey;
  final Map<String, SyncedController> _controllers = {};

  StreamSubscription? _subscription;
  dynamic _currentId;

  RealtimeForm({required this.tableName, this.primaryKey = 'id'});

  /// Registers a String field and returns its controller.
  SyncedController<String> addField(
    String fieldName, {
    Duration debounce = const Duration(milliseconds: 500),
  }) {
    final controller = SyncedController<String>(
      onSave: (value) => _save(fieldName, value),
      adapter: StringAdapter(),
      debounceDuration: debounce,
    );
    _controllers[fieldName] = controller;
    return controller;
  }

  /// Registers a boolean field and returns its controller.
  SyncedController<bool> addBoolField(String fieldName) {
    final controller = SyncedController<bool>(
      onSave: (value) => _save(fieldName, value),
      adapter: BoolAdapter(),
    );
    _controllers[fieldName] = controller;
    return controller;
  }

  /// Registers an integer field and returns its controller.
  SyncedController<int> addIntField(String fieldName, {int initialValue = 0}) {
    final controller = SyncedController<int>(
      onSave: (value) => _save(fieldName, value),
      adapter: IntAdapter(defaultVal: initialValue),
      initialValue: initialValue,
    );
    _controllers[fieldName] = controller;
    return controller;
  }

  /// Registers an enum field and returns its controller.
  SyncedController<T> addEnumField<T extends Enum>(
    String fieldName, {
    required T initialValue,
    required List<T> values,
  }) {
    final controller = SyncedController<T>(
      onSave: (value) => _save(fieldName, value),
      adapter: EnumAdapter<T>(values: values, defaultVal: initialValue),
      initialValue: initialValue,
    );
    _controllers[fieldName] = controller;
    return controller;
  }

  /// Registers a Set<int> field and returns its controller.
  SyncedController<Set<int>> addIntSetField(
    String fieldName, {
    String emptyValue = 'all',
  }) {
    final controller = SyncedController<Set<int>>(
      onSave: (value) => _save(fieldName, value),
      adapter: IntSetAdapter(emptyValue: emptyValue),
    );
    _controllers[fieldName] = controller;
    return controller;
  }

  /// Registers a Set<String> field and returns its controller.
  SyncedController<Set<String>> addStringSetField(
    String fieldName, {
    String emptyValue = '',
  }) {
    final controller = SyncedController<Set<String>>(
      onSave: (value) => _save(fieldName, value),
      adapter: StringSetAdapter(emptyValue: emptyValue),
    );
    _controllers[fieldName] = controller;
    return controller;
  }

  /// Additional port indices to apply changes to (for multi-select)
  Set<int>? additionalPortIndices;

  Future<void> _save(String field, dynamic value) async {
    if (_currentId == null) return;
    try {
      if (field.contains('.')) {
        final parts = field.split('.');
        final column = parts.first;
        final pathRest = parts.sublist(1);

        final data = await Supabase.instance.client
            .from(tableName)
            .select(column)
            .eq(primaryKey, _currentId)
            .single();

        var currentJson = data[column] as Map<String, dynamic>? ?? {};
        var newJson = _updateNestedMap(currentJson, pathRest, value);

        // Apply to additional port indices if we're in multi-select mode
        if (additionalPortIndices != null &&
            pathRest.length >= 2 &&
            pathRest[0] == 'ports') {
          // pathRest looks like ['ports', '0', 'description']
          final fieldName = pathRest.sublist(2); // e.g., ['description']
          for (final portIndex in additionalPortIndices!) {
            final multiPath = ['ports', '$portIndex', ...fieldName];
            newJson = _updateNestedMap(newJson, multiPath, value);
          }
        }

        await Supabase.instance.client
            .from(tableName)
            .update({column: newJson})
            .eq(primaryKey, _currentId);
      } else {
        await Supabase.instance.client
            .from(tableName)
            .update({field: value})
            .eq(primaryKey, _currentId);
      }
    } catch (e) {
      debugPrint('Error saving $field: $e');
    }
  }

  /// Sets the ID of the row to watch and resets controllers with initial data.
  void setId(dynamic id, Map<String, dynamic> initialData) {
    if (_currentId == id) return;
    _currentId = id;

    _controllers.forEach((key, controller) {
      final val = _getNestedValue(initialData, key);
      controller.resetFromStorage(val);
    });

    _setupSubscription();
  }

  void _setupSubscription() {
    _subscription?.cancel();
    if (_currentId == null) return;

    try {
      _subscription = Supabase.instance.client
          .from(tableName)
          .stream(primaryKey: [primaryKey])
          .eq(primaryKey, _currentId)
          .listen((data) {
            if (data.isNotEmpty) {
              final row = data.first;
              _controllers.forEach((key, controller) {
                if (_hasNestedKey(row, key)) {
                  final val = _getNestedValue(row, key);
                  controller.serverUpdate(val);
                }
              });
            }
          });
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
    for (var c in _controllers.values) {
      c.dispose();
    }
  }

  dynamic _getNestedValue(Map<String, dynamic> data, String path) {
    final keys = path.split('.');
    dynamic current = data;
    for (final key in keys) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  bool _hasNestedKey(Map<String, dynamic> data, String path) {
    final keys = path.split('.');
    dynamic current = data;
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        if (i == keys.length - 1) return true;
        current = current[key];
      } else {
        return false;
      }
    }
    return false;
  }

  Map<String, dynamic> _updateNestedMap(
    Map<String, dynamic> source,
    List<String> path,
    dynamic value,
  ) {
    if (path.isEmpty) return source;
    final key = path.first;

    if (path.length == 1) {
      return {...source, key: value};
    }

    // Handle List format for ports (when ports is stored as a full list)
    if (source[key] is List) {
      final list = List<dynamic>.from(source[key] as List);
      final index = int.tryParse(path[1]);
      if (index != null && index < list.length && path.length >= 2) {
        // Update the specific element in the list
        final currentElement = list[index];
        if (currentElement is Map<String, dynamic> || currentElement is Map) {
          final elementMap = Map<String, dynamic>.from(currentElement as Map);
          if (path.length == 2) {
            // Direct assignment to list element (shouldn't happen typically)
            list[index] = value;
          } else {
            // Update nested field within the list element
            list[index] = _updateNestedMapSimple(
              elementMap,
              path.sublist(2),
              value,
            );
          }
        }
      }
      return {...source, key: list};
    }

    // Handle Map format (sparse overrides)
    final nextSource = (source[key] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(source[key] as Map<String, dynamic>)
        : <String, dynamic>{};
    return {
      ...source,
      key: _updateNestedMap(nextSource, path.sublist(1), value),
    };
  }

  /// Simple nested map update without List handling (for updating within list elements)
  Map<String, dynamic> _updateNestedMapSimple(
    Map<String, dynamic> source,
    List<String> path,
    dynamic value,
  ) {
    if (path.isEmpty) return source;
    final key = path.first;

    if (path.length == 1) {
      return {...source, key: value};
    }

    final nextSource = (source[key] is Map<String, dynamic>)
        ? Map<String, dynamic>.from(source[key] as Map<String, dynamic>)
        : <String, dynamic>{};
    return {
      ...source,
      key: _updateNestedMapSimple(nextSource, path.sublist(1), value),
    };
  }
}
