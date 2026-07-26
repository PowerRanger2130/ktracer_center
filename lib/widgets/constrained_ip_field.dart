import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/network/ipv4_utils.dart';
import 'package:ktracer_center/utils/synced_controller.dart';

/// Mode for IP address input
enum IpInputMode {
  /// Full CIDR notation (e.g., 192.168.1.1/24)
  cidr,

  /// Just the IP address (e.g., 192.168.1.1)
  addressOnly,

  /// Just the host portion (e.g., .1 when prefix is 192.168.1)
  hostOnly,
}

/// An enhanced IP address input field with network constraint validation
class ConstrainedIpField extends StatefulWidget {
  /// Synced controller for the IP value
  final SyncedController<String> controller;

  /// Network constraint - if set, validates that the IP is within this network
  final IPv4Network? networkConstraint;

  /// Whether to allow the network address (first address)
  final bool allowNetworkAddress;

  /// Whether to allow the broadcast address (last address)
  final bool allowBroadcastAddress;

  /// Additional addresses to exclude
  final Set<String> excludedAddresses;

  /// Input mode (CIDR, address only, or host only)
  final IpInputMode mode;

  /// Placeholder text
  final String? placeholder;

  /// Label text (shown above the field)
  final String? label;

  /// Help text (shown below the field when no error)
  final String? helpText;

  /// Whether to show network info (network, broadcast, usable range)
  final bool showNetworkInfo;

  /// Fixed prefix for host-only mode (e.g., "192.168.1")
  final String? fixedPrefix;

  /// Custom validator (in addition to network constraints)
  final String? Function(String value)? customValidator;

  const ConstrainedIpField({
    super.key,
    required this.controller,
    this.networkConstraint,
    this.allowNetworkAddress = false,
    this.allowBroadcastAddress = false,
    this.excludedAddresses = const {},
    this.mode = IpInputMode.addressOnly,
    this.placeholder,
    this.label,
    this.helpText,
    this.showNetworkInfo = false,
    this.fixedPrefix,
    this.customValidator,
  });

  /// Create a field for DHCP exclusion range start
  factory ConstrainedIpField.dhcpRangeStart({
    Key? key,
    required SyncedController<String> controller,
    required IPv4Network network,
    String? rangeEndAddress,
    String? label,
  }) {
    return ConstrainedIpField(
      key: key,
      controller: controller,
      networkConstraint: network,
      allowNetworkAddress: false,
      allowBroadcastAddress: false,
      mode: IpInputMode.addressOnly,
      label: label ?? 'Range Start',
      placeholder: network.addressAtOffset(1),
      customValidator: (value) {
        if (rangeEndAddress != null && rangeEndAddress.isNotEmpty) {
          final startInt = IPv4Math.addressToInt(value);
          final endInt = IPv4Math.addressToInt(rangeEndAddress);
          if (startInt != null && endInt != null && startInt > endInt) {
            return 'Start must be ≤ end address';
          }
        }
        return null;
      },
    );
  }

  /// Create a field for DHCP exclusion range end
  factory ConstrainedIpField.dhcpRangeEnd({
    Key? key,
    required SyncedController<String> controller,
    required IPv4Network network,
    String? rangeStartAddress,
    String? label,
  }) {
    return ConstrainedIpField(
      key: key,
      controller: controller,
      networkConstraint: network,
      allowNetworkAddress: false,
      allowBroadcastAddress: false,
      mode: IpInputMode.addressOnly,
      label: label ?? 'Range End',
      placeholder: network.addressAtOffset(network.usableAddresses),
      customValidator: (value) {
        if (rangeStartAddress != null && rangeStartAddress.isNotEmpty) {
          final endInt = IPv4Math.addressToInt(value);
          final startInt = IPv4Math.addressToInt(rangeStartAddress);
          if (startInt != null && endInt != null && endInt < startInt) {
            return 'End must be ≥ start address';
          }
        }
        return null;
      },
    );
  }

  /// Create a field for default gateway
  factory ConstrainedIpField.gateway({
    Key? key,
    required SyncedController<String> controller,
    required IPv4Network network,
    String? label,
  }) {
    return ConstrainedIpField(
      key: key,
      controller: controller,
      networkConstraint: network,
      allowNetworkAddress: false,
      allowBroadcastAddress: false,
      mode: IpInputMode.addressOnly,
      label: label ?? 'Default Gateway',
      placeholder: network.addressAtOffset(1),
    );
  }

  @override
  State<ConstrainedIpField> createState() => _ConstrainedIpFieldState();
}

class _ConstrainedIpFieldState extends State<ConstrainedIpField> {
  late TextEditingController _localController;
  String? _errorMessage;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _localController = TextEditingController(
      text: _formatForDisplay(widget.controller.controller.text),
    );
    widget.controller.addListener(_onExternalUpdate);
  }

  @override
  void didUpdateWidget(ConstrainedIpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onExternalUpdate);
      widget.controller.addListener(_onExternalUpdate);
      _localController.text = _formatForDisplay(
        widget.controller.controller.text,
      );
      _isDirty = false;
      _errorMessage = null;
    }

    // If network constraint changed, re-validate
    if (widget.networkConstraint != oldWidget.networkConstraint) {
      _validate(_localController.text);
    }
  }

  void _onExternalUpdate() {
    if (!_isDirty && mounted) {
      _localController.text = _formatForDisplay(
        widget.controller.controller.text,
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalUpdate);
    _localController.dispose();
    super.dispose();
  }

  /// Format stored value for display based on mode
  String _formatForDisplay(String value) {
    if (value.isEmpty) return '';

    switch (widget.mode) {
      case IpInputMode.cidr:
        return value;
      case IpInputMode.addressOnly:
        // Strip CIDR prefix if present
        String addr = value;
        if (value.contains('/')) {
          addr = value.split('/')[0];
        }
        // Strip display prefix if we're showing one
        return _stripPrefixForDisplay(addr);
      case IpInputMode.hostOnly:
        // Extract just the host portion
        if (widget.fixedPrefix != null) {
          final prefixParts = widget.fixedPrefix!.split('.');
          final valueParts = value.contains('/')
              ? value.split('/')[0].split('.')
              : value.split('.');
          if (valueParts.length == 4) {
            return valueParts.sublist(prefixParts.length).join('.');
          }
        }
        return value;
    }
  }

  /// Convert display value to storage format
  String _formatForStorage(String displayValue) {
    if (displayValue.isEmpty) return '';

    switch (widget.mode) {
      case IpInputMode.cidr:
        return displayValue;
      case IpInputMode.addressOnly:
        // Add prefix back if we're stripping it for display
        return _addPrefixForStorage(displayValue);
      case IpInputMode.hostOnly:
        // Combine with fixed prefix
        if (widget.fixedPrefix != null && displayValue.isNotEmpty) {
          return '${widget.fixedPrefix}.$displayValue';
        }
        return displayValue;
    }
  }

  /// Get the full IP address for validation
  String _getFullAddress(String displayValue) {
    final storageValue = _formatForStorage(displayValue);
    if (storageValue.contains('/')) {
      return storageValue.split('/')[0];
    }
    return storageValue;
  }

  /// Validate the input
  String? _validate(String displayValue) {
    if (displayValue.isEmpty) {
      return null; // Empty is valid (clears the field)
    }

    final fullAddress = _getFullAddress(displayValue);

    // Basic format validation
    if (!IPv4Math.isValidAddress(fullAddress)) {
      return 'Invalid IP address format';
    }

    // CIDR format validation for CIDR mode
    if (widget.mode == IpInputMode.cidr) {
      final parsed = IPv4Math.parseCIDR(displayValue);
      if (parsed == null) {
        return 'Invalid CIDR format (e.g., 192.168.1.1/24)';
      }
    }

    // Network constraint validation
    if (widget.networkConstraint != null) {
      final network = widget.networkConstraint!;
      final addrInt = IPv4Math.addressToInt(fullAddress)!;

      // Check if in network
      if (!network.containsInt(addrInt)) {
        return 'Address must be in ${network.cidr}';
      }

      // Check network address
      if (!widget.allowNetworkAddress && network.isNetworkAddress(addrInt)) {
        return 'Cannot use network address';
      }

      // Check broadcast address
      if (!widget.allowBroadcastAddress &&
          network.isBroadcastAddress(addrInt)) {
        return 'Cannot use broadcast address';
      }
    }

    // Check excluded addresses
    if (widget.excludedAddresses.contains(fullAddress)) {
      return 'This address is reserved';
    }

    // Custom validator
    if (widget.customValidator != null) {
      final customError = widget.customValidator!(fullAddress);
      if (customError != null) {
        return customError;
      }
    }

    return null;
  }

  void _onChanged(String value) {
    setState(() {
      _isDirty = true;
      _errorMessage = _validate(value);
    });
  }

  void _onSubmitted(String value) {
    _trySave();
  }

  void _trySave() {
    final error = _validate(_localController.text);
    if (error == null) {
      setState(() {
        _isDirty = false;
        _errorMessage = null;
      });

      final storageValue = _formatForStorage(_localController.text);
      widget.controller.controller.text = storageValue;
      widget.controller.onTextChanged(storageValue);
    }
  }

  String get _placeholder {
    if (widget.placeholder != null) return widget.placeholder!;

    switch (widget.mode) {
      case IpInputMode.cidr:
        return '192.168.1.1/24';
      case IpInputMode.addressOnly:
        if (widget.networkConstraint != null) {
          return widget.networkConstraint!.addressAtOffset(1) ?? '192.168.1.1';
        }
        return '192.168.1.1';
      case IpInputMode.hostOnly:
        return '1';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!),
          const SizedBox(height: 4),
        ],
        _buildInputRow(context),
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
        ] else if (widget.helpText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helpText!,
            style: TextStyle(color: Colors.grey[100], fontSize: 12),
          ),
        ],
        if (widget.showNetworkInfo && widget.networkConstraint != null)
          _buildNetworkInfo(context),
      ],
    );
  }

  /// Calculate the display prefix based on network constraint
  /// Returns the fixed portion of the IP and how many octets it covers
  (String prefix, int octetCount)? _calculateDisplayPrefix() {
    if (widget.networkConstraint == null) return null;
    if (widget.mode == IpInputMode.cidr) return null;

    final network = widget.networkConstraint!;
    final prefix = network.prefixLength;

    // Only show prefix for /8, /16, /24 boundaries for clean display
    // For other masks, let the user enter the full address
    if (prefix >= 24) {
      // /24 or smaller - show first 3 octets (e.g., "192.168.1.")
      final parts = network.networkAddress.split('.');
      return ('${parts[0]}.${parts[1]}.${parts[2]}.', 3);
    } else if (prefix >= 16) {
      // /16 to /23 - show first 2 octets (e.g., "192.168.")
      final parts = network.networkAddress.split('.');
      return ('${parts[0]}.${parts[1]}.', 2);
    } else if (prefix >= 8) {
      // /8 to /15 - show first octet (e.g., "10.")
      final parts = network.networkAddress.split('.');
      return ('${parts[0]}.', 1);
    }

    // For very large networks, don't show prefix
    return null;
  }

  /// Strip prefix from full address for display
  String _stripPrefixForDisplay(String fullAddress) {
    final prefixInfo = _calculateDisplayPrefix();
    if (prefixInfo == null) return fullAddress;

    final (displayPrefix, _) = prefixInfo;
    if (fullAddress.startsWith(displayPrefix)) {
      return fullAddress.substring(displayPrefix.length);
    }
    return fullAddress;
  }

  /// Add prefix to display value for full address
  String _addPrefixForStorage(String displayValue) {
    final prefixInfo = _calculateDisplayPrefix();
    if (prefixInfo == null) return displayValue;

    final (displayPrefix, _) = prefixInfo;
    // Don't double-add prefix
    if (displayValue.startsWith(displayPrefix)) return displayValue;
    return '$displayPrefix$displayValue';
  }

  Widget _buildInputRow(BuildContext context) {
    final prefixInfo = _calculateDisplayPrefix();

    // Host-only mode with explicit fixed prefix
    if (widget.mode == IpInputMode.hostOnly && widget.fixedPrefix != null) {
      return SizedBox(
        width: 150,
        child: TextBox(
          controller: _localController,
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
          placeholder: _placeholder,
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '${widget.fixedPrefix}.',
              style: FluentTheme.of(context).typography.body,
            ),
          ),
          prefixMode: OverlayVisibilityMode.always,
          padding: const EdgeInsets.only(top: 1, bottom: 0, right: 8, left: 0),
        ),
      );
    }

    // Address mode with network constraint - show calculated prefix
    if (prefixInfo != null && widget.mode == IpInputMode.addressOnly) {
      final (displayPrefix, _) = prefixInfo;
      return SizedBox(
        width: 180,
        child: TextBox(
          controller: _localController,
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
          placeholder: _stripPrefixForDisplay(_placeholder),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              displayPrefix,
              style: FluentTheme.of(context).typography.body,
            ),
          ),
          prefixMode: OverlayVisibilityMode.always,
          padding: const EdgeInsets.only(top: 1, bottom: 0, right: 8, left: 0),
        ),
      );
    }

    // Default: full input without prefix
    return SizedBox(
      width: widget.mode == IpInputMode.cidr ? 200 : 150,
      child: TextBox(
        controller: _localController,
        onChanged: _onChanged,
        onSubmitted: _onSubmitted,
        placeholder: _placeholder,
      ),
    );
  }

  Widget _buildNetworkInfo(BuildContext context) {
    final network = widget.networkConstraint!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Network: ${network.networkAddress}',
            style: FluentTheme.of(context).typography.caption,
          ),
          Text(
            'Broadcast: ${network.broadcastAddress}',
            style: FluentTheme.of(context).typography.caption,
          ),
          Text(
            'Usable: ${network.addressAtOffset(1)} - ${network.addressAtOffset(network.totalAddresses - 2)}',
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      ),
    );
  }
}

/// A simple IP address field without synced controller
/// For use in dialogs and other non-synced contexts
class SimpleIpField extends StatefulWidget {
  /// Current value
  final String value;

  /// Callback when value changes (after validation)
  final void Function(String value)? onChanged;

  /// Network constraint
  final IPv4Network? networkConstraint;

  /// Whether to allow empty value
  final bool allowEmpty;

  /// Input mode
  final IpInputMode mode;

  /// Placeholder text
  final String? placeholder;

  /// Label text
  final String? label;

  const SimpleIpField({
    super.key,
    required this.value,
    this.onChanged,
    this.networkConstraint,
    this.allowEmpty = true,
    this.mode = IpInputMode.addressOnly,
    this.placeholder,
    this.label,
  });

  @override
  State<SimpleIpField> createState() => _SimpleIpFieldState();
}

class _SimpleIpFieldState extends State<SimpleIpField> {
  late TextEditingController _controller;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _stripPrefixForDisplay(widget.value),
    );
  }

  @override
  void didUpdateWidget(SimpleIpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final stripped = _stripPrefixForDisplay(widget.value);
      if (stripped != _controller.text) {
        _controller.text = stripped;
        _errorMessage = null;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Calculate the display prefix based on network constraint
  (String prefix, int octetCount)? _calculateDisplayPrefix() {
    if (widget.networkConstraint == null) return null;
    if (widget.mode == IpInputMode.cidr) return null;

    final network = widget.networkConstraint!;
    final prefix = network.prefixLength;

    if (prefix >= 24) {
      final parts = network.networkAddress.split('.');
      return ('${parts[0]}.${parts[1]}.${parts[2]}.', 3);
    } else if (prefix >= 16) {
      final parts = network.networkAddress.split('.');
      return ('${parts[0]}.${parts[1]}.', 2);
    } else if (prefix >= 8) {
      final parts = network.networkAddress.split('.');
      return ('${parts[0]}.', 1);
    }
    return null;
  }

  String _stripPrefixForDisplay(String fullAddress) {
    if (fullAddress.isEmpty) return '';
    final prefixInfo = _calculateDisplayPrefix();
    if (prefixInfo == null) return fullAddress;

    final (displayPrefix, _) = prefixInfo;
    if (fullAddress.startsWith(displayPrefix)) {
      return fullAddress.substring(displayPrefix.length);
    }
    return fullAddress;
  }

  String _addPrefixForStorage(String displayValue) {
    if (displayValue.isEmpty) return '';
    final prefixInfo = _calculateDisplayPrefix();
    if (prefixInfo == null) return displayValue;

    final (displayPrefix, _) = prefixInfo;
    if (displayValue.startsWith(displayPrefix)) return displayValue;
    return '$displayPrefix$displayValue';
  }

  String? _validate(String displayValue) {
    if (displayValue.isEmpty) {
      return widget.allowEmpty ? null : 'IP address is required';
    }

    final fullAddress = _addPrefixForStorage(displayValue);

    if (!IPv4Math.isValidAddress(fullAddress)) {
      return 'Invalid IP address format';
    }

    if (widget.networkConstraint != null) {
      final network = widget.networkConstraint!;
      final addrInt = IPv4Math.addressToInt(fullAddress)!;

      if (!network.containsInt(addrInt)) {
        return 'Address must be in ${network.cidr}';
      }

      if (network.isNetworkAddress(addrInt)) {
        return 'Cannot use network address';
      }

      if (network.isBroadcastAddress(addrInt)) {
        return 'Cannot use broadcast address';
      }
    }

    return null;
  }

  void _onChanged(String value) {
    final error = _validate(value);
    setState(() {
      _errorMessage = error;
    });

    if (error == null) {
      widget.onChanged?.call(_addPrefixForStorage(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefixInfo = _calculateDisplayPrefix();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!),
          const SizedBox(height: 4),
        ],
        SizedBox(
          width: prefixInfo != null ? 180 : 150,
          child: TextBox(
            controller: _controller,
            onChanged: _onChanged,
            placeholder: _stripPrefixForDisplay(
              widget.placeholder ?? '192.168.1.1',
            ),
            prefix: prefixInfo != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      prefixInfo.$1,
                      style: FluentTheme.of(context).typography.body,
                    ),
                  )
                : null,
            prefixMode: prefixInfo != null
                ? OverlayVisibilityMode.always
                : OverlayVisibilityMode.editing,
            padding: prefixInfo != null
                ? const EdgeInsets.only(top: 5, bottom: 5, right: 8, left: 0)
                : const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            _errorMessage!,
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
