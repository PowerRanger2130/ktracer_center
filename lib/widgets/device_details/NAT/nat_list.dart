import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/NAT/nat_management.dart';
import 'package:ktracer_center/widgets/device_details/NAT/port_forward_wizard.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class NatList extends StatefulWidget {
  const NatList({super.key, required this.device});
  final NetDevice device;

  @override
  State<NatList> createState() => _NatListState();
}

class _NatListState extends State<NatList> {
  final ValueNotifier<NatRule?> _selectedRule = ValueNotifier(null);
  int _selectedRuleIndex = -1;

  // Controllers for add NAT rule dialog
  final _descriptionController = TextEditingController();
  NatType _selectedType = NatType.staticNat;

  @override
  void didUpdateWidget(NatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.id != oldWidget.device.id) {
      _selectedRule.value = null;
      _selectedRuleIndex = -1;
    }
  }

  @override
  void dispose() {
    _selectedRule.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addNatRule(NatRule rule) async {
    final rules = widget.device.natRules;
    final updatedRules = [...rules, rule];

    await Database.updateDeviceConfig(widget.device.id, {
      'nat_rules': updatedRules.map((r) => r.toJson()).toList(),
    });
  }

  Future<void> _deleteNatRule(int index) async {
    final rules = widget.device.natRules;
    final updatedRules = [...rules]..removeAt(index);

    await Database.updateDeviceConfig(widget.device.id, {
      'nat_rules': updatedRules.map((r) => r.toJson()).toList(),
    });

    _selectedRule.value = null;
    _selectedRuleIndex = -1;
    setState(() {});
  }

  String _getNatTypeLabel(NatType type) {
    switch (type) {
      case NatType.staticNat:
        return 'Static NAT';
      case NatType.dynamicNat:
        return 'Dynamic NAT';
      case NatType.pat:
        return 'PAT (Overload)';
      case NatType.staticPat:
        return 'Static PAT';
    }
  }

  void _showAddNatRuleDialog() {
    _descriptionController.clear();
    _selectedType = NatType.staticNat;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('Add NAT Rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // NAT Type selection
              const Text('NAT Type'),
              const SizedBox(height: 4),
              SizedBox(
                width: 250,
                child: ComboBox<NatType>(
                  value: _selectedType,
                  isExpanded: true,
                  popupColor: FluentTheme.of(context).menuColor,
                  items: NatType.values
                      .map(
                        (t) => ComboBoxItem<NatType>(
                          value: t,
                          child: Text(_getNatTypeLabel(t)),
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
              const SizedBox(height: 12),

              // Description
              const Text('Description (optional)'),
              const SizedBox(height: 4),
              SizedBox(
                width: 300,
                child: TextBox(
                  controller: _descriptionController,
                  placeholder: 'e.g., Web server NAT',
                ),
              ),
              const SizedBox(height: 12),

              // Hint about configuration
              InfoBar(
                title: const Text('Note'),
                content: Text(
                  _selectedType == NatType.staticNat ||
                          _selectedType == NatType.staticPat
                      ? 'Configure inside/outside addresses after adding.'
                      : 'Configure pool, ACL and interfaces after adding.',
                ),
                severity: InfoBarSeverity.info,
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
                final rule = NatRule(
                  type: _selectedType,
                  description: _descriptionController.text.trim(),
                );
                _addNatRule(rule);
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPortForwardWizard() {
    showDialog(
      context: context,
      builder: (context) => PortForwardWizard(device: widget.device),
    );
  }

  Widget _buildNatRuleItem(NatRule rule, int index) => ValueListenableBuilder(
    valueListenable: _selectedRule,
    builder: (context, value, _) => ListTile.selectable(
      title: Text(rule.displayName),
      subtitle: Text(
        rule.description.isNotEmpty
            ? rule.description
            : _getNatTypeLabel(rule.type),
      ),
      selected: _selectedRuleIndex == index,
      trailing: rule.enabled
          ? const Icon(
              FluentIcons.circle_fill,
              size: 8,
              color: Colors.successPrimaryColor,
            )
          : const Icon(FluentIcons.circle_ring, size: 8),
      onPressed: () {
        if (_selectedRuleIndex == index) {
          _selectedRule.value = null;
          _selectedRuleIndex = -1;
        } else {
          _selectedRule.value = rule;
          _selectedRuleIndex = index;
        }
        setState(() {});
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rules = widget.device.natRules;

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
                    'NAT Configuration',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _showPortForwardWizard,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.forward, size: 12),
                        SizedBox(width: 4),
                        Text('Quick Port Forward'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: _showAddNatRuleDialog,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('Add Rule'),
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
                    child: rules.isEmpty
                        ? const Center(child: Text('No NAT rules configured'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: rules.length,
                            itemBuilder: (context, index) =>
                                _buildNatRuleItem(rules[index], index),
                          ),
                  ),
                  Expanded(
                    child: FluentWidgets.mica(
                      child: ValueListenableBuilder(
                        valueListenable: _selectedRule,
                        builder: (context, value, _) => value == null
                            ? const Center(child: Text('No NAT rule selected'))
                            : NatManagement(
                                rule: _selectedRule,
                                device: widget.device,
                                ruleIndex: _selectedRuleIndex,
                                onDelete: () =>
                                    _deleteNatRule(_selectedRuleIndex),
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
