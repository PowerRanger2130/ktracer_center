import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/network/ipv6.dart';
import 'package:ktracer_center/utils/synced_controller.dart';

/// An IPv6 address input field with CIDR support.
class Ipv6AddressField extends StatefulWidget {
  const Ipv6AddressField({
    required this.controller,
    this.placeholder = '2001:db8::1/64',
    this.label = 'IPv6 Address (CIDR)',
    super.key,
  });

  final SyncedController<String> controller;
  final String placeholder;
  final String label;

  @override
  State<Ipv6AddressField> createState() => _Ipv6AddressFieldState();
}

class _Ipv6AddressFieldState extends State<Ipv6AddressField> {
  late TextEditingController _localController;
  String? _errorMessage;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _localController = TextEditingController(
      text: widget.controller.controller.text,
    );
    // Listen for external updates from the synced controller
    widget.controller.addListener(_onExternalUpdate);
  }

  @override
  void didUpdateWidget(Ipv6AddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onExternalUpdate);
      widget.controller.addListener(_onExternalUpdate);
      _localController.text = widget.controller.controller.text;
      _isDirty = false;
      _errorMessage = null;
    }
  }

  void _onExternalUpdate() {
    // Only update local controller if we're not currently editing
    if (!_isDirty && mounted) {
      _localController.text = widget.controller.controller.text;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalUpdate);
    _localController.dispose();
    super.dispose();
  }

  /// Validates and normalizes an IPv6 address input
  /// Returns the normalized CIDR string if valid, null otherwise
  String? _validateAndNormalize(String input) {
    final trimmed = input.trim();

    // Empty is valid (clears the IP)
    if (trimmed.isEmpty) return '';

    // Check if it's just an IP without prefix - add /64 default
    String cidr = trimmed;
    if (!trimmed.contains('/')) {
      cidr = '$trimmed/64';
    }

    // Validate using IPv6.tryParse
    final parsed = IPv6.tryParse(cidr);
    if (parsed == null) return null;

    return cidr;
  }

  void _onChanged(String value) {
    setState(() {
      _isDirty = true;
      final normalized = _validateAndNormalize(value);
      if (normalized == null && value.isNotEmpty) {
        _errorMessage = 'Invalid IPv6 address format';
      } else {
        _errorMessage = null;
      }
    });
  }

  void _onSubmitted(String value) {
    _trySave();
  }

  void _trySave() {
    final normalized = _validateAndNormalize(_localController.text);
    if (normalized != null) {
      setState(() {
        _isDirty = false;
        _errorMessage = null;
      });
      // Update the synced controller's internal text and trigger save
      widget.controller.controller.text = normalized;
      widget.controller.onTextChanged(normalized);
      // Also update local controller to show normalized value
      _localController.text = normalized;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label),
        const SizedBox(height: 4),
        TextBox(
          controller: _localController,
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
          placeholder: widget.placeholder,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ] else if (_isDirty) ...[
          const SizedBox(height: 4),
          Text(
            'Press Enter to save',
            style: TextStyle(color: Colors.grey[100], fontSize: 12),
          ),
        ],
      ],
    );
  }
}
