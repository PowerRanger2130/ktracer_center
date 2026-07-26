import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/network/port.dart';

/// A multi-select widget for Interfaces that displays selected items as chips
/// and provides an autocomplete-style dropdown for selection.
class InterfaceMultiSelect extends StatefulWidget {
  const InterfaceMultiSelect({
    super.key,
    required this.interfaces,
    required this.selectedInterfaceIndices,
    required this.onChanged,
    this.availableInterfaceIndices,
    this.getInterfaceSpeed,
    this.lockedSpeed,
    this.placeholder = 'Select interfaces...',
    this.shortNameFormatter,
  });

  final List<Port> interfaces;
  final Set<int> selectedInterfaceIndices;
  final ValueChanged<Set<int>> onChanged;

  /// If provided, only these interface indices will be selectable
  final List<int>? availableInterfaceIndices;

  /// Function to get interface speed category (for filtering)
  final String Function(Port)? getInterfaceSpeed;

  /// If set, only interfaces matching this speed can be selected
  final String? lockedSpeed;
  final String placeholder;

  /// Optional function to format interface names (e.g., shorten)
  final String Function(String)? shortNameFormatter;

  @override
  State<InterfaceMultiSelect> createState() => _InterfaceMultiSelectState();
}

class _InterfaceMultiSelectState extends State<InterfaceMultiSelect> {
  final _flyoutController = FlyoutController();
  final _fieldKey = GlobalKey();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  String _getShortName(String name) {
    if (widget.shortNameFormatter != null) {
      return widget.shortNameFormatter!(name);
    }
    return name
        .replaceAll('FastEthernet', 'Fa')
        .replaceAll('GigabitEthernet', 'Gi')
        .replaceAll('TenGigabitEthernet', 'Te');
  }

  bool _isInterfaceAvailable(int index) {
    if (widget.availableInterfaceIndices != null) {
      return widget.availableInterfaceIndices!.contains(index);
    }
    return true;
  }

  bool _isInterfaceDisabled(int index) {
    final isSelected = widget.selectedInterfaceIndices.contains(index);
    if (isSelected) return false; // Always allow deselecting

    if (!_isInterfaceAvailable(index)) return true;

    if (widget.getInterfaceSpeed != null && widget.lockedSpeed != null) {
      final interfaceSpeed = widget.getInterfaceSpeed!(
        widget.interfaces[index],
      );
      if (interfaceSpeed != widget.lockedSpeed) return true;
    }

    return false;
  }

  String _getDisabledReason(int index) {
    if (!_isInterfaceAvailable(index)) {
      return 'Already in another group';
    }
    if (widget.getInterfaceSpeed != null && widget.lockedSpeed != null) {
      return 'Speed mismatch (requires ${widget.lockedSpeed})';
    }
    return '';
  }

  void _toggleInterface(int interfaceIndex) {
    final newSelection = Set<int>.from(widget.selectedInterfaceIndices);
    if (newSelection.contains(interfaceIndex)) {
      newSelection.remove(interfaceIndex);
    } else {
      newSelection.add(interfaceIndex);
    }
    widget.onChanged(newSelection);
  }

  void _removeInterface(int interfaceIndex) {
    final newSelection = Set<int>.from(widget.selectedInterfaceIndices);
    newSelection.remove(interfaceIndex);
    widget.onChanged(newSelection);
  }

  void _showFlyout() {
    final fieldWidth = _fieldKey.currentContext?.size?.width ?? 200.0;
    _flyoutController.showFlyout(
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      placementMode: FlyoutPlacementMode.bottomLeft,
      dismissOnPointerMoveAway: false,
      builder: (context) => _buildDropdown(fieldWidth),
    );
  }

  Widget _buildDropdown(double width) {
    final theme = FluentTheme.of(context);
    final interfaces = widget.interfaces;

    return Container(
      constraints: BoxConstraints(
        maxHeight: 250,
        minWidth: width,
        maxWidth: width,
      ),
      decoration: BoxDecoration(
        color: theme.menuColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: interfaces.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No interfaces available'),
            )
          : StatefulBuilder(
              builder: (context, setDropdownState) {
                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: interfaces.length,
                  itemBuilder: (context, index) {
                    final interface_ = interfaces[index];
                    final isSelected = widget.selectedInterfaceIndices.contains(
                      index,
                    );
                    final isDisabled = _isInterfaceDisabled(index);
                    final disabledReason = isDisabled
                        ? _getDisabledReason(index)
                        : '';

                    return Tooltip(
                      message: isDisabled ? disabledReason : interface_.name,
                      child: HoverButton(
                        onPressed: isDisabled
                            ? null
                            : () {
                                _toggleInterface(index);
                                setDropdownState(() {});
                              },
                        builder: (context, states) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: states.isHovered && !isDisabled
                                ? theme.resources.subtleFillColorSecondary
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Checkbox(
                                  checked: isSelected,
                                  onChanged: isDisabled
                                      ? null
                                      : (_) {
                                          _toggleInterface(index);
                                          setDropdownState(() {});
                                        },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getShortName(interface_.name),
                                        style: theme.typography.body?.copyWith(
                                          color: isDisabled
                                              ? theme
                                                    .resources
                                                    .textFillColorDisabled
                                              : null,
                                        ),
                                      ),
                                      if (interface_.description?.isNotEmpty ==
                                          true)
                                        Text(
                                          interface_.description!,
                                          style: theme.typography.caption
                                              ?.copyWith(
                                                color: isDisabled
                                                    ? theme
                                                          .resources
                                                          .textFillColorDisabled
                                                    : theme
                                                          .resources
                                                          .textFillColorSecondary,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final selectedInterfaces = widget.selectedInterfaceIndices
        .where((i) => i < widget.interfaces.length)
        .map((i) => MapEntry(i, widget.interfaces[i]))
        .toList();

    return FlyoutTarget(
      controller: _flyoutController,
      child: GestureDetector(
        onTap: _showFlyout,
        child: Container(
          key: _fieldKey,
          constraints: const BoxConstraints(minHeight: 32),
          decoration: BoxDecoration(
            color: theme.resources.controlFillColorDefault,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.resources.controlStrokeColorDefault,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: selectedInterfaces.isEmpty
                    ? Text(
                        widget.placeholder,
                        style: TextStyle(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      )
                    : Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: selectedInterfaces
                            .map(
                              (entry) => _InterfaceChip(
                                interfaceName: _getShortName(entry.value.name),
                                onDeleted: () => _removeInterface(entry.key),
                              ),
                            )
                            .toList(),
                      ),
              ),
              Icon(
                FluentIcons.chevron_down,
                size: 12,
                color: theme.resources.textFillColorSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterfaceChip extends StatelessWidget {
  const _InterfaceChip({required this.interfaceName, required this.onDeleted});

  final String interfaceName;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.accentColor.defaultBrushFor(theme.brightness),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            interfaceName,
            style: TextStyle(
              fontSize: 12,
              color: theme.resources.textOnAccentFillColorPrimary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDeleted,
            child: Icon(
              FluentIcons.chrome_close,
              size: 10,
              color: theme.resources.textOnAccentFillColorPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
