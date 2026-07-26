import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

/// A multi-select widget for VLANs that displays selected items as chips
/// and provides an autocomplete-style dropdown for selection.
///
/// This is a convenience wrapper around [FluentWidgets.multiSelect] for VLANs.
class VlanMultiSelect extends StatelessWidget {
  const VlanMultiSelect({
    super.key,
    required this.vlans,
    required this.selectedVlanIds,
    required this.onChanged,
    this.placeholder = 'Select VLANs...',
  });

  final List<VlanConfig> vlans;
  final Set<int> selectedVlanIds;
  final ValueChanged<Set<int>> onChanged;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    // Convert between VlanConfig and vlanId for the generic multi-select
    final selectedVlans = vlans
        .where((v) => selectedVlanIds.contains(v.vlanId))
        .toSet();

    return FluentMultiSelect<VlanConfig>(
      items: vlans,
      selectedItems: selectedVlans,
      onChanged: (selected) {
        onChanged(selected.map((v) => v.vlanId).toSet());
      },
      itemLabel: (vlan) => 'VLAN ${vlan.vlanId}',
      placeholder: placeholder,
      emptyMessage: 'No VLANs available',
      chipBuilder: (vlan) => FluentWidgets.chip(
        text: '${vlan.vlanId}',
        selected: true,
        onDeleted: () {
          final newSelection = Set<int>.from(selectedVlanIds);
          newSelection.remove(vlan.vlanId);
          onChanged(newSelection);
        },
      ),
      itemBuilder: (vlan, isSelected) {
        final theme = FluentTheme.of(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                checked: isSelected,
                onChanged: null, // Handled by parent
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('VLAN ${vlan.vlanId}', style: theme.typography.body),
                    if (vlan.name.isNotEmpty &&
                        vlan.name != 'VLAN ${vlan.vlanId}')
                      Text(
                        vlan.name,
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
