import 'package:flutter/widgets.dart';
import 'package:ktracer_center/utils/synced_controller.dart';

/// Descriptor for a form field - defines the field's metadata
/// This allows declaring form fields in a more declarative way
class FormFieldDescriptor<T> {
  /// The path to this field in the database (e.g., 'config.hostname')
  final String path;

  /// The type of field
  final FormFieldType type;

  /// Default value for the field
  final T? defaultValue;

  /// For enum fields, the list of possible values
  final List<Enum>? enumValues;

  /// For int set fields, the empty value string
  final String? emptyValue;

  /// Debounce duration for string fields
  final Duration debounce;

  FormFieldDescriptor({
    required this.path,
    required this.type,
    this.defaultValue,
    this.enumValues,
    this.emptyValue,
    this.debounce = const Duration(milliseconds: 500),
  });

  /// Create a string field descriptor
  static FormFieldDescriptor<String> string(
    String path, {
    String defaultValue = '',
    Duration debounce = const Duration(milliseconds: 500),
  }) {
    return FormFieldDescriptor<String>(
      path: path,
      type: FormFieldType.string,
      defaultValue: defaultValue,
      debounce: debounce,
    );
  }

  /// Create a bool field descriptor
  static FormFieldDescriptor<bool> boolean(
    String path, {
    bool defaultValue = false,
  }) {
    return FormFieldDescriptor<bool>(
      path: path,
      type: FormFieldType.bool,
      defaultValue: defaultValue,
    );
  }

  /// Create an int field descriptor
  static FormFieldDescriptor<int> integer(String path, {int defaultValue = 0}) {
    return FormFieldDescriptor<int>(
      path: path,
      type: FormFieldType.int,
      defaultValue: defaultValue,
    );
  }

  /// Create an enum field descriptor
  static FormFieldDescriptor<E> enumField<E extends Enum>(
    String path, {
    required E defaultValue,
    required List<E> values,
  }) {
    return FormFieldDescriptor<E>(
      path: path,
      type: FormFieldType.enumValue,
      defaultValue: defaultValue,
      enumValues: values,
    );
  }

  /// Create an int set field descriptor
  static FormFieldDescriptor<Set<int>> intSet(
    String path, {
    String emptyValue = 'all',
  }) {
    return FormFieldDescriptor<Set<int>>(
      path: path,
      type: FormFieldType.intSet,
      emptyValue: emptyValue,
    );
  }

  /// Create a string set field descriptor
  static FormFieldDescriptor<Set<String>> stringSet(
    String path, {
    String emptyValue = '',
  }) {
    return FormFieldDescriptor<Set<String>>(
      path: path,
      type: FormFieldType.stringSet,
      emptyValue: emptyValue,
    );
  }
}

/// Types of form fields
enum FormFieldType { string, bool, int, enumValue, intSet, stringSet }

/// A schema that describes all fields in a form
class FormSchema {
  final String tableName;
  final String primaryKey;
  final List<FormFieldDescriptor> fields;

  const FormSchema({
    required this.tableName,
    this.primaryKey = 'id',
    required this.fields,
  });

  /// Get a field by path
  FormFieldDescriptor? getField(String path) {
    return fields.where((f) => f.path == path).firstOrNull;
  }
}

/// Manages form state with automatic controller creation and cleanup
class ManagedForm {
  final FormSchema schema;
  late final RealtimeForm _form;
  final Map<String, SyncedController> _controllers = {};
  bool _disposed = false;

  ManagedForm(this.schema) {
    _form = RealtimeForm(
      tableName: schema.tableName,
      primaryKey: schema.primaryKey,
    );
    _createControllers();
  }

  void _createControllers() {
    for (final field in schema.fields) {
      final controller = _createController(field);
      _controllers[field.path] = controller;
    }
  }

  SyncedController _createController(FormFieldDescriptor field) {
    switch (field.type) {
      case FormFieldType.string:
        return _form.addField(field.path, debounce: field.debounce);
      case FormFieldType.bool:
        return _form.addBoolField(field.path);
      case FormFieldType.int:
        return _form.addIntField(
          field.path,
          initialValue: (field.defaultValue as int?) ?? 0,
        );
      case FormFieldType.enumValue:
        // This requires special handling - see getEnumController
        throw UnimplementedError(
          'Use getEnumController for enum fields: ${field.path}',
        );
      case FormFieldType.intSet:
        return _form.addIntSetField(
          field.path,
          emptyValue: field.emptyValue ?? 'all',
        );
      case FormFieldType.stringSet:
        return _form.addStringSetField(
          field.path,
          emptyValue: field.emptyValue ?? '',
        );
    }
  }

  /// Get a string controller
  SyncedController<String> getString(String path) {
    return _controllers[path] as SyncedController<String>;
  }

  /// Get a bool controller
  SyncedController<bool> getBool(String path) {
    return _controllers[path] as SyncedController<bool>;
  }

  /// Get an int controller
  SyncedController<int> getInt(String path) {
    return _controllers[path] as SyncedController<int>;
  }

  /// Get an int set controller
  SyncedController<Set<int>> getIntSet(String path) {
    return _controllers[path] as SyncedController<Set<int>>;
  }

  /// Get a string set controller
  SyncedController<Set<String>> getStringSet(String path) {
    return _controllers[path] as SyncedController<Set<String>>;
  }

  /// Add and get an enum controller (must be called separately due to generic type)
  SyncedController<T> addEnumController<T extends Enum>(
    String path, {
    required T initialValue,
    required List<T> values,
  }) {
    if (_controllers.containsKey(path)) {
      return _controllers[path] as SyncedController<T>;
    }

    final controller = _form.addEnumField<T>(
      path,
      initialValue: initialValue,
      values: values,
    );
    _controllers[path] = controller;
    return controller;
  }

  /// Set the ID and initial data for this form
  void setId(dynamic id, Map<String, dynamic> initialData) {
    _form.setId(id, initialData);
  }

  /// Set additional port indices for multi-select
  set additionalPortIndices(Set<int>? indices) {
    _form.additionalPortIndices = indices;
  }

  /// Dispose all controllers
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _form.dispose();
    _controllers.clear();
  }
}

/// Mixin to simplify form management in StatefulWidgets
///
/// Example usage:
/// ```dart
/// class _MyWidgetState extends State<MyWidget> with FormManagerMixin {
///   @override
///   void initState() {
///     super.initState();
///     initForm(FormSchema(
///       tableName: 'net_devices',
///       fields: [
///         FormFieldDescriptor.string('config.hostname'),
///         FormFieldDescriptor.bool('config.enabled'),
///       ],
///     ));
///
///     // Use controllers
///     final hostname = stringController('config.hostname');
///   }
///
///   @override
///   void dispose() {
///     disposeForm();
///     super.dispose();
///   }
/// }
/// ```
mixin FormManagerMixin<T extends StatefulWidget> on State<T> {
  ManagedForm? _managedForm;

  /// Initialize the form with a schema
  void initForm(FormSchema schema) {
    _managedForm = ManagedForm(schema);
  }

  /// Get a string controller by path
  SyncedController<String> stringController(String path) {
    return _managedForm!.getString(path);
  }

  /// Get a bool controller by path
  SyncedController<bool> boolController(String path) {
    return _managedForm!.getBool(path);
  }

  /// Get an int controller by path
  SyncedController<int> intController(String path) {
    return _managedForm!.getInt(path);
  }

  /// Get an int set controller by path
  SyncedController<Set<int>> intSetController(String path) {
    return _managedForm!.getIntSet(path);
  }

  /// Get a string set controller by path
  SyncedController<Set<String>> stringSetController(String path) {
    return _managedForm!.getStringSet(path);
  }

  /// Add and get an enum controller
  SyncedController<E> enumController<E extends Enum>(
    String path, {
    required E initialValue,
    required List<E> values,
  }) {
    return _managedForm!.addEnumController<E>(
      path,
      initialValue: initialValue,
      values: values,
    );
  }

  /// Set the ID and initial data for the form
  void setFormId(dynamic id, Map<String, dynamic> initialData) {
    _managedForm?.setId(id, initialData);
  }

  /// Set additional port indices for multi-select
  void setAdditionalPortIndices(Set<int>? indices) {
    _managedForm?.additionalPortIndices = indices;
  }

  /// Dispose the form - call this in dispose()
  void disposeForm() {
    _managedForm?.dispose();
    _managedForm = null;
  }
}

/// A builder widget that automatically manages form lifecycle
class ManagedFormBuilder extends StatefulWidget {
  final FormSchema schema;
  final dynamic id;
  final Map<String, dynamic> initialData;
  final Widget Function(BuildContext context, ManagedForm form) builder;

  const ManagedFormBuilder({
    super.key,
    required this.schema,
    required this.id,
    required this.initialData,
    required this.builder,
  });

  @override
  State<ManagedFormBuilder> createState() => _ManagedFormBuilderState();
}

class _ManagedFormBuilderState extends State<ManagedFormBuilder> {
  late ManagedForm _form;

  @override
  void initState() {
    super.initState();
    _form = ManagedForm(widget.schema);
    _form.setId(widget.id, widget.initialData);
  }

  @override
  void didUpdateWidget(ManagedFormBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) {
      _form.setId(widget.id, widget.initialData);
    }
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _form);
  }
}

/// Common form schemas for reuse
class CommonFormSchemas {
  CommonFormSchemas._();

  /// Schema for device general settings
  static FormSchema deviceGeneral(int deviceIndex) => FormSchema(
    tableName: 'net_devices',
    fields: [
      FormFieldDescriptor.string('config.hostname'),
      FormFieldDescriptor.boolean('config.domain_lookup'),
      FormFieldDescriptor.string('config.domain_name'),
      FormFieldDescriptor.string('config.banner_motd'),
    ],
  );

  /// Schema for port/interface settings
  static FormSchema portSettings(int portIndex) {
    final prefix = 'config.ports.$portIndex';
    return FormSchema(
      tableName: 'net_devices',
      fields: [
        FormFieldDescriptor.string('$prefix.description'),
        FormFieldDescriptor.boolean('$prefix.enabled'),
        FormFieldDescriptor.string('$prefix.ip_cidr'),
        FormFieldDescriptor.string('$prefix.ipv6_cidr'),
        // Switchport-specific fields would be added via addEnumController
      ],
    );
  }

  /// Schema for VLAN settings
  static FormSchema vlanSettings(int vlanIndex) {
    final prefix = 'config.vlans.$vlanIndex';
    return FormSchema(
      tableName: 'net_devices',
      fields: [
        FormFieldDescriptor.string('$prefix.name'),
        FormFieldDescriptor.string('$prefix.description'),
        FormFieldDescriptor.boolean('$prefix.enabled'),
        FormFieldDescriptor.string('$prefix.ip_cidr'),
        FormFieldDescriptor.string('$prefix.ipv6_cidr'),
      ],
    );
  }

  /// Schema for DHCP pool settings
  static FormSchema dhcpPoolSettings(int poolIndex) {
    final prefix = 'config.dhcp_pools.$poolIndex';
    return FormSchema(
      tableName: 'net_devices',
      fields: [
        FormFieldDescriptor.string('$prefix.default_router'),
        FormFieldDescriptor.string('$prefix.dns_server'),
        FormFieldDescriptor.string('$prefix.dns_server_secondary'),
        FormFieldDescriptor.string('$prefix.domain_name'),
        FormFieldDescriptor.integer('$prefix.lease_time', defaultValue: 86400),
        FormFieldDescriptor.string('$prefix.exclude_start'),
        FormFieldDescriptor.string('$prefix.exclude_end'),
        FormFieldDescriptor.boolean('$prefix.enabled'),
      ],
    );
  }
}
