import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/ipv4_utils.dart';
import 'package:ktracer_center/utils/synced_controller.dart';
import 'package:ktracer_center/widgets/constrained_ip_field.dart';

/// A basic IP address input field with CIDR support.
///
/// For more advanced use cases with network constraints, use
/// [IpAddressField.constrained] or [ConstrainedIpField] directly.
class IpAddressField extends StatefulWidget {
  const IpAddressField({
    required this.controller,
    this.placeholder = '192.168.1.1/24',
    this.enableCidr = true,
    this.conflictChecker,
    this.label = 'IP Address',
    this.title,
    this.headerTrailing,
    this.customFieldContent,
    super.key,
  });

  final SyncedController<String> controller;
  final String placeholder;
  final bool enableCidr;
  final String label;
  final String? title;
  final Widget? headerTrailing;
  final Widget? customFieldContent;

  /// Optional conflict checker to validate against other interfaces
  final IpConflictChecker? conflictChecker;

  /// Creates an IP address field with network constraints.
  ///
  /// This is a convenience factory that creates a [ConstrainedIpField]
  /// with the given parameters.
  static Widget constrained({
    Key? key,
    required SyncedController<String> controller,
    IPv4Network? networkConstraint,
    bool allowNetworkAddress = false,
    bool allowBroadcastAddress = false,
    Set<String> excludedAddresses = const {},
    IpInputMode mode = IpInputMode.addressOnly,
    String? placeholder,
    String? label,
    String? helpText,
    bool showNetworkInfo = false,
    String? fixedPrefix,
    String? Function(String value)? customValidator,
  }) {
    return ConstrainedIpField(
      key: key,
      controller: controller,
      networkConstraint: networkConstraint,
      allowNetworkAddress: allowNetworkAddress,
      allowBroadcastAddress: allowBroadcastAddress,
      excludedAddresses: excludedAddresses,
      mode: mode,
      placeholder: placeholder,
      label: label,
      helpText: helpText,
      showNetworkInfo: showNetworkInfo,
      fixedPrefix: fixedPrefix,
      customValidator: customValidator,
    );
  }

  /// Creates a field for DHCP range start address.
  static Widget dhcpRangeStart({
    Key? key,
    required SyncedController<String> controller,
    required IPv4Network network,
    String? rangeEndAddress,
    String? label,
  }) {
    return ConstrainedIpField.dhcpRangeStart(
      key: key,
      controller: controller,
      network: network,
      rangeEndAddress: rangeEndAddress,
      label: label,
    );
  }

  /// Creates a field for DHCP range end address.
  static Widget dhcpRangeEnd({
    Key? key,
    required SyncedController<String> controller,
    required IPv4Network network,
    String? rangeStartAddress,
    String? label,
  }) {
    return ConstrainedIpField.dhcpRangeEnd(
      key: key,
      controller: controller,
      network: network,
      rangeStartAddress: rangeStartAddress,
      label: label,
    );
  }

  /// Creates a field for default gateway.
  static Widget gateway({
    Key? key,
    required SyncedController<String> controller,
    required IPv4Network network,
    String? label,
  }) {
    return ConstrainedIpField.gateway(
      key: key,
      controller: controller,
      network: network,
      label: label,
    );
  }

  @override
  State<IpAddressField> createState() => _IpAddressFieldState();
}

class _IpAddressFieldState extends State<IpAddressField> {
  late TextEditingController _localController;
  String? _errorMessage;
  String? _warningMessage;
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
  void didUpdateWidget(IpAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onExternalUpdate);
      widget.controller.addListener(_onExternalUpdate);
      _localController.text = widget.controller.controller.text;
      _isDirty = false;
      _errorMessage = null;
      _warningMessage = null;
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

  /// Validates and normalizes an IP address input
  /// Returns the normalized CIDR string if valid, null otherwise
  String? _validateAndNormalize(String input) {
    final trimmed = input.trim();

    // Empty is valid (clears the IP)
    if (trimmed.isEmpty) return '';

    if (!widget.enableCidr) {
      if (trimmed.contains('/')) return null;
      if (!IPv4.isValidAddress(trimmed)) return null;
      return trimmed;
    }

    // Check if it's just an IP without prefix - add /24 default
    String cidr = trimmed;
    if (!trimmed.contains('/')) {
      cidr = '$trimmed/24';
    }

    // Validate using IPv4.tryParse
    final parsed = IPv4.tryParse(cidr);
    if (parsed == null) return null;

    return cidr;
  }

  /// Check for IP conflicts (including subnet overlaps)
  IpConflictResult? _checkConflict(String cidr) {
    if (widget.conflictChecker == null) return null;
    if (cidr.isEmpty) return null;

    final parsed = widget.enableCidr
        ? IPv4.tryParse(cidr)
        : (IPv4.isValidAddress(cidr) ? IPv4.fromAddress(cidr) : null);
    if (parsed == null) return null;

    return widget.conflictChecker!.checkConflictWithSubnet(
      parsed.address,
      parsed.subnetMask,
    );
  }

  void _onChanged(String value) {
    setState(() {
      _isDirty = true;
      final normalized = _validateAndNormalize(value);
      if (normalized == null && value.isNotEmpty) {
        _errorMessage = 'Invalid IP address format';
        _warningMessage = null;
      } else {
        _errorMessage = null;
        // Check for conflicts
        if (normalized != null && normalized.isNotEmpty) {
          final conflict = _checkConflict(normalized);
          if (conflict != null) {
            _warningMessage = conflict.message;
          } else {
            _warningMessage = null;
          }
        } else {
          _warningMessage = null;
        }
      }
    });
  }

  void _onSubmitted(String value) {
    _trySave();
  }

  void _trySave() {
    final normalized = _validateAndNormalize(_localController.text);
    if (normalized != null) {
      // Check for conflicts before saving
      final conflict = _checkConflict(normalized);
      if (conflict != null) {
        setState(() {
          _errorMessage = 'Cannot save: ${conflict.message}';
        });
        return;
      }

      setState(() {
        _isDirty = false;
        _errorMessage = null;
        _warningMessage = null;
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
        Row(
          children: [
            Text(widget.title ?? widget.label),
            if (widget.headerTrailing != null) ...[
              const SizedBox(width: 8),
              widget.headerTrailing!,
            ],
          ],
        ),
        const SizedBox(height: 4),
        if (widget.customFieldContent != null)
          widget.customFieldContent!
        else
          TextBox(
            controller: _localController,
            onChanged: _onChanged,
            onSubmitted: _onSubmitted,
            placeholder: widget.placeholder,
          ),
        if (widget.customFieldContent == null && _errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ] else if (widget.customFieldContent == null &&
            _warningMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _warningMessage!,
            style: TextStyle(color: Colors.warningPrimaryColor, fontSize: 12),
          ),
        ] else if (widget.customFieldContent == null && _isDirty) ...[
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
