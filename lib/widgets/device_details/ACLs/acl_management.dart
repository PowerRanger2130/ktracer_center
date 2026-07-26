import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/utils/synced_controller.dart';
import 'package:ktracer_center/widgets/device_details/synced_toggle_switch.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class AclManagement extends StatefulWidget {
  const AclManagement({
    super.key,
    required this.acl,
    required this.device,
    required this.aclIndex,
    this.onDelete,
  });

  final ValueNotifier<AclConfig?> acl;
  final NetDevice device;
  final int aclIndex;
  final VoidCallback? onDelete;

  @override
  State<AclManagement> createState() => _AclManagementState();
}

class _AclManagementState extends State<AclManagement> {
  late RealtimeForm _form;
  late SyncedController<bool> _enabledController;

  // Controllers for add entry dialog
  final _sourceAddressController = TextEditingController();
  final _sourceWildcardController = TextEditingController();
  final _destAddressController = TextEditingController();
  final _destWildcardController = TextEditingController();
  final _sourcePortController = TextEditingController();
  final _sourcePortEndController = TextEditingController();
  final _destPortController = TextEditingController();
  final _destPortEndController = TextEditingController();
  final _remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initForm();
    widget.acl.addListener(_handleAclChange);
    _handleAclChange();
  }

  void _initForm() {
    _form = RealtimeForm(tableName: 'net_devices');
    _enabledController = _form.addBoolField(
      'config.acls.${widget.aclIndex}.enabled',
    );
  }

  @override
  void didUpdateWidget(AclManagement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.acl != oldWidget.acl || widget.aclIndex != oldWidget.aclIndex) {
      oldWidget.acl.removeListener(_handleAclChange);

      _form.dispose();
      _initForm();

      widget.acl.addListener(_handleAclChange);
      _handleAclChange();
    }
  }

  void _handleAclChange() {
    final acl = widget.acl.value;
    if (acl == null) return;

    _form.setId(widget.device.id, {
      'config': {
        'acls': {
          '${widget.aclIndex}': {'enabled': acl.enabled},
        },
      },
    });
  }

  @override
  void dispose() {
    widget.acl.removeListener(_handleAclChange);
    _form.dispose();
    _sourceAddressController.dispose();
    _sourceWildcardController.dispose();
    _destAddressController.dispose();
    _destWildcardController.dispose();
    _sourcePortController.dispose();
    _sourcePortEndController.dispose();
    _destPortController.dispose();
    _destPortEndController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  int _getNextSequenceNumber(List<AclEntry> entries) {
    if (entries.isEmpty) return 10;
    final maxSeq = entries
        .map((e) => e.sequenceNumber)
        .reduce((a, b) => a > b ? a : b);
    return ((maxSeq ~/ 10) + 1) * 10;
  }

  Future<void> _addEntry(AclEntry entry) async {
    final acl = widget.acl.value;
    if (acl == null) return;

    final updatedEntries = [...acl.entries, entry];
    // Sort by sequence number
    updatedEntries.sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));

    await _saveEntries(updatedEntries);
  }

  Future<void> _updateEntry(int entryIndex, AclEntry entry) async {
    final acl = widget.acl.value;
    if (acl == null) return;

    final updatedEntries = [...acl.entries];
    updatedEntries[entryIndex] = entry;

    await _saveEntries(updatedEntries);
  }

  Future<void> _deleteEntry(int entryIndex) async {
    final acl = widget.acl.value;
    if (acl == null) return;

    final updatedEntries = [...acl.entries]..removeAt(entryIndex);
    await _saveEntries(updatedEntries);
  }

  Future<void> _reorderEntries(int oldIndex, int newIndex) async {
    final acl = widget.acl.value;
    if (acl == null) return;

    final entries = [...acl.entries];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = entries.removeAt(oldIndex);
    entries.insert(newIndex, item);

    // Reassign sequence numbers based on new order
    for (int i = 0; i < entries.length; i++) {
      entries[i] = entries[i].copyWith(sequenceNumber: (i + 1) * 10);
    }

    await _saveEntries(entries);
  }

  Future<void> _saveEntries(List<AclEntry> entries) async {
    final acls = widget.device.acls;
    final updatedAcl = AclConfig(
      number: widget.acl.value!.number,
      name: widget.acl.value!.name,
      type: widget.acl.value!.type,
      isNamed: widget.acl.value!.isNamed,
      entries: entries,
      enabled: widget.acl.value!.enabled,
    );

    final updatedAcls = [...acls];
    updatedAcls[widget.aclIndex] = updatedAcl;

    await Database.updateDeviceConfig(widget.device.id, {
      'acls': updatedAcls.map((a) => a.toJson()).toList(),
    });

    // Update local notifier to refresh UI
    widget.acl.value = updatedAcl;
    setState(() {});
  }

  void _showAddEntryDialog({AclEntry? existingEntry, int? entryIndex}) {
    final acl = widget.acl.value;
    if (acl == null) return;

    final isExtended = acl.type == AclType.extended;
    final isEditing = existingEntry != null;

    // Initialize controllers
    AclAction selectedAction = existingEntry?.action ?? AclAction.permit;
    AclProtocol selectedProtocol = existingEntry?.protocol ?? AclProtocol.ip;
    AclPortOperator? sourcePortOp = existingEntry?.sourcePortOperator;
    AclPortOperator? destPortOp = existingEntry?.destPortOperator;
    bool logMatches = existingEntry?.log ?? false;
    bool isRemark = existingEntry?.remark != null;

    _sourceAddressController.text = existingEntry?.sourceAddress ?? '';
    _sourceWildcardController.text = existingEntry?.sourceWildcard ?? '';
    _destAddressController.text = existingEntry?.destAddress ?? '';
    _destWildcardController.text = existingEntry?.destWildcard ?? '';
    _sourcePortController.text = existingEntry?.sourcePort?.toString() ?? '';
    _sourcePortEndController.text =
        existingEntry?.sourcePortEnd?.toString() ?? '';
    _destPortController.text = existingEntry?.destPort?.toString() ?? '';
    _destPortEndController.text = existingEntry?.destPortEnd?.toString() ?? '';
    _remarkController.text = existingEntry?.remark ?? '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final showPortFields =
              isExtended &&
              (selectedProtocol == AclProtocol.tcp ||
                  selectedProtocol == AclProtocol.udp);

          return ContentDialog(
            title: Text(isEditing ? 'Edit ACL Entry' : 'Add ACL Entry'),
            constraints: const BoxConstraints(maxWidth: 500),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Remark toggle
                  Checkbox(
                    checked: isRemark,
                    onChanged: (value) {
                      setDialogState(() => isRemark = value ?? false);
                    },
                    content: const Text('This is a remark (comment)'),
                  ),
                  const SizedBox(height: 12),

                  if (isRemark) ...[
                    const Text('Remark'),
                    const SizedBox(height: 4),
                    TextBox(
                      controller: _remarkController,
                      placeholder: 'Enter comment',
                      maxLines: 2,
                    ),
                  ] else ...[
                    // Action selection
                    const Text('Action'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RadioButton(
                          checked: selectedAction == AclAction.permit,
                          onChanged: (checked) {
                            if (checked) {
                              setDialogState(
                                () => selectedAction = AclAction.permit,
                              );
                            }
                          },
                          content: const Text('Permit'),
                        ),
                        const SizedBox(width: 16),
                        RadioButton(
                          checked: selectedAction == AclAction.deny,
                          onChanged: (checked) {
                            if (checked) {
                              setDialogState(
                                () => selectedAction = AclAction.deny,
                              );
                            }
                          },
                          content: const Text('Deny'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Protocol (extended only)
                    if (isExtended) ...[
                      const Text('Protocol'),
                      const SizedBox(height: 4),
                      ComboBox<AclProtocol>(
                        value: selectedProtocol,
                        isExpanded: true,
                        popupColor: FluentTheme.of(context).menuColor,
                        items: AclProtocol.values
                            .map(
                              (p) => ComboBoxItem<AclProtocol>(
                                value: p,
                                child: Text(p.name.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedProtocol = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Source address
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Source Address'),
                              const SizedBox(height: 4),
                              TextBox(
                                controller: _sourceAddressController,
                                placeholder: 'any, host x.x.x.x, or IP',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Wildcard'),
                              const SizedBox(height: 4),
                              TextBox(
                                controller: _sourceWildcardController,
                                placeholder: '0.0.0.255',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Source port (TCP/UDP only)
                    if (showPortFields) ...[
                      const SizedBox(height: 12),
                      _buildPortFields(
                        'Source Port',
                        sourcePortOp,
                        _sourcePortController,
                        _sourcePortEndController,
                        (op) => setDialogState(() => sourcePortOp = op),
                      ),
                    ],

                    // Destination (extended only)
                    if (isExtended) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Destination Address'),
                                const SizedBox(height: 4),
                                TextBox(
                                  controller: _destAddressController,
                                  placeholder: 'any, host x.x.x.x, or IP',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Wildcard'),
                                const SizedBox(height: 4),
                                TextBox(
                                  controller: _destWildcardController,
                                  placeholder: '0.0.0.255',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Destination port (TCP/UDP only)
                      if (showPortFields) ...[
                        const SizedBox(height: 12),
                        _buildPortFields(
                          'Destination Port',
                          destPortOp,
                          _destPortController,
                          _destPortEndController,
                          (op) => setDialogState(() => destPortOp = op),
                        ),
                      ],
                    ],

                    const SizedBox(height: 12),
                    Checkbox(
                      checked: logMatches,
                      onChanged: (value) {
                        setDialogState(() => logMatches = value ?? false);
                      },
                      content: const Text('Log matches'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final entry = _buildEntryFromForm(
                    isRemark: isRemark,
                    action: selectedAction,
                    protocol: selectedProtocol,
                    sourcePortOp: sourcePortOp,
                    destPortOp: destPortOp,
                    logMatches: logMatches,
                    sequenceNumber:
                        existingEntry?.sequenceNumber ??
                        _getNextSequenceNumber(acl.entries),
                  );

                  if (entry == null) return;

                  if (isEditing && entryIndex != null) {
                    _updateEntry(entryIndex, entry);
                  } else {
                    _addEntry(entry);
                  }
                  Navigator.of(context).pop();
                },
                child: Text(isEditing ? 'Save' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPortFields(
    String label,
    AclPortOperator? operator,
    TextEditingController portController,
    TextEditingController portEndController,
    ValueChanged<AclPortOperator?> onOperatorChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: ComboBox<AclPortOperator?>(
                value: operator,
                isExpanded: true,
                placeholder: const Text('None'),
                popupColor: FluentTheme.of(context).menuColor,
                items: [
                  const ComboBoxItem<AclPortOperator?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...AclPortOperator.values.map(
                    (op) => ComboBoxItem<AclPortOperator>(
                      value: op,
                      child: Text(op.name),
                    ),
                  ),
                ],
                onChanged: onOperatorChanged,
              ),
            ),
            if (operator != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: TextBox(
                  controller: portController,
                  placeholder: 'Port',
                  keyboardType: TextInputType.number,
                ),
              ),
              if (operator == AclPortOperator.range) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextBox(
                    controller: portEndController,
                    placeholder: 'End port',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }

  AclEntry? _buildEntryFromForm({
    required bool isRemark,
    required AclAction action,
    required AclProtocol protocol,
    AclPortOperator? sourcePortOp,
    AclPortOperator? destPortOp,
    required bool logMatches,
    required int sequenceNumber,
  }) {
    final acl = widget.acl.value;
    if (acl == null) return null;

    if (isRemark) {
      final remark = _remarkController.text.trim();
      if (remark.isEmpty) return null;
      return AclEntry(
        sequenceNumber: sequenceNumber,
        action: AclAction.permit,
        sourceAddress: 'any',
        remark: remark,
      );
    }

    final sourceAddr = _sourceAddressController.text.trim();
    if (sourceAddr.isEmpty) return null;

    String? sourceWildcard;
    if (sourceAddr.toLowerCase() != 'any' &&
        !sourceAddr.toLowerCase().startsWith('host ')) {
      sourceWildcard = _sourceWildcardController.text.trim();
      if (sourceWildcard.isEmpty) sourceWildcard = '0.0.0.0';
    }

    String? destAddr;
    String? destWildcard;
    if (acl.type == AclType.extended) {
      destAddr = _destAddressController.text.trim();
      if (destAddr.isEmpty) destAddr = 'any';

      if (destAddr.toLowerCase() != 'any' &&
          !destAddr.toLowerCase().startsWith('host ')) {
        destWildcard = _destWildcardController.text.trim();
        if (destWildcard.isEmpty) destWildcard = '0.0.0.0';
      }
    }

    return AclEntry(
      sequenceNumber: sequenceNumber,
      action: action,
      protocol: acl.type == AclType.extended ? protocol : AclProtocol.ip,
      sourceAddress: sourceAddr,
      sourceWildcard: sourceWildcard,
      sourcePortOperator: sourcePortOp,
      sourcePort: sourcePortOp != null
          ? int.tryParse(_sourcePortController.text.trim())
          : null,
      sourcePortEnd: sourcePortOp == AclPortOperator.range
          ? int.tryParse(_sourcePortEndController.text.trim())
          : null,
      destAddress: destAddr,
      destWildcard: destWildcard,
      destPortOperator: destPortOp,
      destPort: destPortOp != null
          ? int.tryParse(_destPortController.text.trim())
          : null,
      destPortEnd: destPortOp == AclPortOperator.range
          ? int.tryParse(_destPortEndController.text.trim())
          : null,
      log: logMatches,
    );
  }

  Widget _buildEntryTile(AclEntry entry, int index) {
    final isRemark = entry.remark != null && entry.remark!.isNotEmpty;
    final theme = FluentTheme.of(context);

    return Container(
      key: ValueKey('entry_$index'),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
      ),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  FluentIcons.global_nav_button,
                  size: 14,
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ),
          ),
          // Priority/Sequence number
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${entry.sequenceNumber}',
              style: theme.typography.bodyStrong?.copyWith(
                fontFamily: 'Consolas',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Action indicator
          if (!isRemark)
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: entry.action == AclAction.permit
                    ? Colors.green.withOpacity(0.15)
                    : Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.action.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: entry.action == AclAction.permit
                      ? Colors.green
                      : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          // Entry content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                isRemark
                    ? 'remark ${entry.remark}'
                    : _formatEntryContent(entry),
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 13,
                  fontStyle: isRemark ? FontStyle.italic : FontStyle.normal,
                  color: isRemark
                      ? theme.resources.textFillColorSecondary
                      : theme.resources.textFillColorPrimary,
                ),
              ),
            ),
          ),
          // Actions
          IconButton(
            icon: const Icon(FluentIcons.edit, size: 14),
            onPressed: () =>
                _showAddEntryDialog(existingEntry: entry, entryIndex: index),
          ),
          IconButton(
            icon: Icon(FluentIcons.delete, size: 14, color: Colors.red.light),
            onPressed: () => _showDeleteEntryDialog(index),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatEntryContent(AclEntry entry) {
    final parts = <String>[];
    final acl = widget.acl.value;
    if (acl == null) return '';

    // Protocol for extended
    if (acl.type == AclType.extended && entry.protocol != AclProtocol.ip) {
      parts.add(entry.protocol.name);
    }

    // Source
    if (entry.isSourceAny) {
      parts.add('any');
    } else if (entry.sourceWildcard == '0.0.0.0') {
      parts.add('host ${entry.sourceAddress}');
    } else {
      parts.add(entry.sourceAddress);
      if (entry.sourceWildcard != null) {
        parts.add(entry.sourceWildcard!);
      }
    }

    // Source port
    if (entry.sourcePortOperator != null && entry.sourcePort != null) {
      parts.add(
        _formatPortSpec(
          entry.sourcePortOperator!,
          entry.sourcePort!,
          entry.sourcePortEnd,
        ),
      );
    }

    // Destination for extended
    if (acl.type == AclType.extended && entry.destAddress != null) {
      if (entry.isDestAny) {
        parts.add('any');
      } else if (entry.destWildcard == '0.0.0.0') {
        parts.add('host ${entry.destAddress}');
      } else {
        parts.add(entry.destAddress!);
        if (entry.destWildcard != null) {
          parts.add(entry.destWildcard!);
        }
      }

      // Dest port
      if (entry.destPortOperator != null && entry.destPort != null) {
        parts.add(
          _formatPortSpec(
            entry.destPortOperator!,
            entry.destPort!,
            entry.destPortEnd,
          ),
        );
      }
    }

    if (entry.log) parts.add('log');

    return parts.join(' ');
  }

  String _formatPortSpec(AclPortOperator op, int port, int? portEnd) {
    switch (op) {
      case AclPortOperator.eq:
        return 'eq $port';
      case AclPortOperator.neq:
        return 'neq $port';
      case AclPortOperator.gt:
        return 'gt $port';
      case AclPortOperator.lt:
        return 'lt $port';
      case AclPortOperator.range:
        return 'range $port ${portEnd ?? port}';
    }
  }

  void _showDeleteEntryDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this ACL entry?'),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.red),
            ),
            onPressed: () {
              _deleteEntry(index);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acl = widget.acl.value;
    if (acl == null) {
      return const Center(child: Text('No ACL selected'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    acl.displayName,
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${acl.type == AclType.standard ? 'Standard' : 'Extended'} ACL${acl.isNamed ? ' (Named)' : ''}',
                    style: FluentTheme.of(context).typography.caption,
                  ),
                ],
              ),
              const Spacer(),
              if (widget.onDelete != null)
                Button(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => ContentDialog(
                        title: const Text('Delete ACL'),
                        content: Text(
                          'Are you sure you want to delete "${acl.displayName}"?\n\n'
                          'This will remove all ${acl.entries.length} entries.',
                        ),
                        actions: [
                          Button(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                Colors.red,
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onDelete!();
                            },
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Delete'),
                ),
            ],
          ),
        ),
        Divider(
          style: DividerTheme.of(
            context,
          ).merge(const DividerThemeData(horizontalMargin: EdgeInsets.zero)),
        ),
        // Controls
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SyncedToggleSwitch(
                label: 'Enabled',
                controller: _enabledController,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _showAddEntryDialog,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add, size: 12),
                    SizedBox(width: 4),
                    Text('Add Entry'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Entries list header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const SizedBox(width: 44), // Drag handle space
              SizedBox(
                width: 50,
                child: Text(
                  'Seq',
                  style: FluentTheme.of(
                    context,
                  ).typography.caption?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 68,
                child: Text(
                  'Action',
                  style: FluentTheme.of(
                    context,
                  ).typography.caption?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  'Rule',
                  style: FluentTheme.of(
                    context,
                  ).typography.caption?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 80), // Actions space
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Entries list with drag-to-reorder
        Expanded(
          child: acl.entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FluentIcons.shield,
                        size: 48,
                        color: FluentTheme.of(
                          context,
                        ).resources.textFillColorSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No entries in this ACL',
                        style: FluentTheme.of(context).typography.body,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add entries to define access rules',
                        style: FluentTheme.of(context).typography.caption,
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: acl.entries.length,
                    onReorder: _reorderEntries,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final elevation = Tween<double>(
                            begin: 0,
                            end: 8,
                          ).evaluate(animation);
                          return FluentWidgets.acrylic(
                            // TODO: elevation: elevation,
                            // TODO: color: Colors.transparent,
                            child: child,
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      return _buildEntryTile(acl.entries[index], index);
                    },
                  ),
                ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
