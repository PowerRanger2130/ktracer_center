import 'package:fluent_ui/fluent_ui.dart';

/// A multi-select widget for MAC addresses that displays selected items as chips
/// and provides a text field to add new addresses.
class MacAddressMultiSelect extends StatefulWidget {
  const MacAddressMultiSelect({
    super.key,
    required this.selectedMacAddresses,
    required this.onChanged,
    this.placeholder = 'No MAC addresses configured',
    this.availableMacAddresses,
  });

  /// Currently selected MAC addresses.
  final Set<String> selectedMacAddresses;

  /// Callback when the selection changes.
  final ValueChanged<Set<String>> onChanged;

  /// Placeholder text when no addresses are selected.
  final String placeholder;

  /// Optional list of MAC addresses from the MAC address table for quick selection.
  final List<String>? availableMacAddresses;

  @override
  State<MacAddressMultiSelect> createState() => _MacAddressMultiSelectState();
}

class _MacAddressMultiSelectState extends State<MacAddressMultiSelect> {
  final _flyoutController = FlyoutController();
  final _fieldKey = GlobalKey();
  final _textController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _flyoutController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _addMacAddress(String mac) {
    final normalized = _normalizeMacAddress(mac);
    if (normalized == null) {
      setState(() {
        _errorMessage = 'Invalid MAC address format';
      });
      return;
    }

    if (widget.selectedMacAddresses.contains(normalized)) {
      setState(() {
        _errorMessage = 'MAC address already added';
      });
      return;
    }

    final newSelection = Set<String>.from(widget.selectedMacAddresses);
    newSelection.add(normalized);
    widget.onChanged(newSelection);
    _textController.clear();
    setState(() {
      _errorMessage = null;
    });
  }

  void _removeMacAddress(String mac) {
    final newSelection = Set<String>.from(widget.selectedMacAddresses);
    newSelection.remove(mac);
    widget.onChanged(newSelection);
  }

  void _toggleMacAddress(String mac) {
    final newSelection = Set<String>.from(widget.selectedMacAddresses);
    if (newSelection.contains(mac)) {
      newSelection.remove(mac);
    } else {
      newSelection.add(mac);
    }
    widget.onChanged(newSelection);
  }

  /// Normalizes MAC address to format: AA:BB:CC:DD:EE:FF
  String? _normalizeMacAddress(String input) {
    // Remove all separators and convert to uppercase
    final cleaned = input.replaceAll(RegExp(r'[.:\-]'), '').toUpperCase();

    // Validate it's exactly 12 hex characters
    if (cleaned.length != 12 || !RegExp(r'^[0-9A-F]{12}$').hasMatch(cleaned)) {
      return null;
    }

    // Format as AA:BB:CC:DD:EE:FF
    final parts = <String>[];
    for (var i = 0; i < 12; i += 2) {
      parts.add(cleaned.substring(i, i + 2));
    }
    return parts.join(':');
  }

  void _showFlyout() {
    final fieldWidth = _fieldKey.currentContext?.size?.width ?? 300.0;
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
    final available = widget.availableMacAddresses ?? [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: 300,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextBox(
                        controller: _textController,
                        placeholder: 'Enter MAC address',
                        onSubmitted: _addMacAddress,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _addMacAddress(_textController.text),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage!,
                    style: TextStyle(fontSize: 12, color: Colors.red.normal),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Formats: AA:BB:CC:DD:EE:FF, AA-BB-CC-DD-EE-FF, AABB.CCDD.EEFF',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (available.isNotEmpty) ...[
            Divider(
              style: DividerTheme.of(context).merge(
                const DividerThemeData(
                  horizontalMargin: EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'From MAC Address Table',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ),
            Flexible(
              child: StatefulBuilder(
                builder: (context, setDropdownState) {
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final mac = available[index];
                      final isSelected = widget.selectedMacAddresses.contains(
                        mac,
                      );

                      return HoverButton(
                        onPressed: () {
                          _toggleMacAddress(mac);
                          setDropdownState(() {});
                        },
                        builder: (context, states) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: states.isHovered
                                ? theme.resources.subtleFillColorSecondary
                                : Colors.transparent,
                            child: Row(
                              children: [
                                Checkbox(
                                  checked: isSelected,
                                  onChanged: (_) {
                                    _toggleMacAddress(mac);
                                    setDropdownState(() {});
                                  },
                                ),
                                const SizedBox(width: 8),
                                Text(mac, style: theme.typography.body),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final selectedMacs = widget.selectedMacAddresses.toList()..sort();

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
                child: selectedMacs.isEmpty
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
                        children: selectedMacs
                            .map(
                              (mac) => _MacChip(
                                mac: mac,
                                onDeleted: () => _removeMacAddress(mac),
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

class _MacChip extends StatelessWidget {
  const _MacChip({required this.mac, required this.onDeleted});

  final String mac;
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
            mac,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'Consolas',
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
