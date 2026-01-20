import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/ACLs/acl_management.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class AclList extends StatefulWidget {
  const AclList({super.key, required this.device});
  final NetDevice device;

  @override
  State<AclList> createState() => _AclListState();
}

class _AclListState extends State<AclList> {
  final ValueNotifier<AclConfig?> _selectedAcl = ValueNotifier(null);
  int _selectedAclIndex = -1;

  // Controllers for add ACL dialog
  final _aclNumberController = TextEditingController();
  final _aclNameController = TextEditingController();
  AclType _selectedType = AclType.standard;
  bool _isNamedAcl = false;

  @override
  void didUpdateWidget(AclList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.id != oldWidget.device.id) {
      _selectedAcl.value = null;
      _selectedAclIndex = -1;
    }
  }

  @override
  void dispose() {
    _selectedAcl.dispose();
    _aclNumberController.dispose();
    _aclNameController.dispose();
    super.dispose();
  }

  Future<void> _addAcl(AclConfig acl) async {
    final acls = widget.device.acls;

    // Check for duplicate
    if (acl.isNamed) {
      if (acls.any(
        (a) => a.isNamed && a.name.toLowerCase() == acl.name.toLowerCase(),
      )) {
        return;
      }
    } else {
      if (acls.any((a) => !a.isNamed && a.number == acl.number)) {
        return;
      }
    }

    final updatedAcls = [...acls, acl];

    // Sort: numbered ACLs first (by number), then named ACLs (alphabetically)
    updatedAcls.sort((a, b) {
      if (a.isNamed && !b.isNamed) return 1;
      if (!a.isNamed && b.isNamed) return -1;
      if (!a.isNamed && !b.isNamed) {
        return (a.number ?? 0).compareTo(b.number ?? 0);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    await Database.updateDeviceConfig(widget.device.id, {
      'acls': updatedAcls.map((a) => a.toJson()).toList(),
    });
  }

  Future<void> _deleteAcl(int index) async {
    final acls = widget.device.acls;
    final updatedAcls = [...acls]..removeAt(index);

    await Database.updateDeviceConfig(widget.device.id, {
      'acls': updatedAcls.map((a) => a.toJson()).toList(),
    });

    _selectedAcl.value = null;
    _selectedAclIndex = -1;
    setState(() {});
  }

  String _getNumberRangeHint(AclType type) {
    switch (type) {
      case AclType.standard:
        return '1-99, 1300-1999';
      case AclType.extended:
        return '100-199, 2000-2699';
    }
  }

  void _showAddAclDialog() {
    _aclNumberController.clear();
    _aclNameController.clear();
    _selectedType = AclType.standard;
    _isNamedAcl = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add Access Control List'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ACL Type selection
              const Text('ACL Type'),
              const SizedBox(height: 4),
              Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: ComboBox<AclType>(
                      value: _selectedType,
                      isExpanded: true,
                      popupColor: FluentTheme.of(context).menuColor,
                      items: AclType.values
                          .map(
                            (t) => ComboBoxItem<AclType>(
                              value: t,
                              child: Text(
                                t == AclType.standard ? 'Standard' : 'Extended',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => _selectedType = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Checkbox(
                    checked: _isNamedAcl,
                    onChanged: (value) {
                      setDialogState(() => _isNamedAcl = value ?? false);
                    },
                    content: const Text('Named ACL'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Numbered or Named input
              if (!_isNamedAcl) ...[
                Text('ACL Number (${_getNumberRangeHint(_selectedType)})'),
                const SizedBox(height: 4),
                SizedBox(
                  width: 200,
                  child: TextBox(
                    controller: _aclNumberController,
                    placeholder: 'Enter ACL number',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Description (optional)'),
              ] else ...[
                const Text('ACL Name'),
              ],
              const SizedBox(height: 4),
              SizedBox(
                width: 300,
                child: TextBox(
                  controller: _aclNameController,
                  placeholder: _isNamedAcl
                      ? 'Enter ACL name (e.g., BLOCK_TELNET)'
                      : 'Enter description',
                ),
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (_isNamedAcl) {
                  final name = _aclNameController.text.trim();
                  if (name.isEmpty) return;

                  _addAcl(
                    AclConfig(name: name, type: _selectedType, isNamed: true),
                  );
                } else {
                  final number = int.tryParse(_aclNumberController.text.trim());
                  if (number == null) return;

                  if (!AclConfig.isValidNumber(number, _selectedType)) {
                    displayInfoBar(
                      context,
                      builder: (context, close) => InfoBar(
                        title: const Text('Invalid ACL Number'),
                        content: Text(
                          'For ${_selectedType.name} ACLs, use: ${_getNumberRangeHint(_selectedType)}',
                        ),
                        severity: InfoBarSeverity.error,
                        onClose: close,
                      ),
                    );
                    return;
                  }

                  _addAcl(
                    AclConfig(
                      number: number,
                      name: _aclNameController.text.trim(),
                      type: _selectedType,
                      isNamed: false,
                    ),
                  );
                }
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAclItem(AclConfig acl, int index) => ValueListenableBuilder(
    valueListenable: _selectedAcl,
    builder: (context, value, _) => ListTile.selectable(
      title: Text(acl.displayName),
      subtitle: Text(
        '${acl.type == AclType.standard ? 'Standard' : 'Extended'} • ${acl.entries.length} ${acl.entries.length == 1 ? 'entry' : 'entries'}',
      ),
      selected: _selectedAclIndex == index,
      trailing: acl.enabled
          ? const Icon(
              FluentIcons.circle_fill,
              size: 8,
              color: Colors.successPrimaryColor,
            )
          : const Icon(FluentIcons.circle_ring, size: 8),
      onPressed: () {
        if (_selectedAclIndex == index) {
          _selectedAcl.value = null;
          _selectedAclIndex = -1;
        } else {
          _selectedAcl.value = acl;
          _selectedAclIndex = index;
        }
        setState(() {});
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final acls = widget.device.acls;

    return FluentWidgets.mica(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text(
                    'Access Control Lists',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const Spacer(),
                  Button(
                    onPressed: _showAddAclDialog,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('Add ACL'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    child: acls.isEmpty
                        ? const Center(child: Text('No ACLs configured'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: acls.length,
                            itemBuilder: (context, index) =>
                                _buildAclItem(acls[index], index),
                          ),
                  ),
                  Expanded(
                    child: FluentWidgets.mica(
                      child: ValueListenableBuilder(
                        valueListenable: _selectedAcl,
                        builder: (context, value, _) => value == null
                            ? const Center(child: Text('No ACL selected'))
                            : AclManagement(
                                acl: _selectedAcl,
                                device: widget.device,
                                aclIndex: _selectedAclIndex,
                                onDelete: () => _deleteAcl(_selectedAclIndex),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
