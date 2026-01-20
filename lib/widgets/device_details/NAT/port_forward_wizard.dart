import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:provider/provider.dart';

/// Common services with their default ports for quick port forwarding
class ServiceTemplate {
  final String name;
  final String protocol;
  final int port;
  final IconData icon;

  const ServiceTemplate({
    required this.name,
    required this.protocol,
    required this.port,
    required this.icon,
  });
}

/// Predefined service templates for common port forwards
const List<ServiceTemplate> _commonServices = [
  ServiceTemplate(
    name: 'HTTP',
    protocol: 'tcp',
    port: 80,
    icon: FluentIcons.globe,
  ),
  ServiceTemplate(
    name: 'HTTPS',
    protocol: 'tcp',
    port: 443,
    icon: FluentIcons.shield,
  ),
  ServiceTemplate(
    name: 'SSH',
    protocol: 'tcp',
    port: 22,
    icon: FluentIcons.command_prompt,
  ),
  ServiceTemplate(
    name: 'RDP',
    protocol: 'tcp',
    port: 3389,
    icon: FluentIcons.remote,
  ),
  ServiceTemplate(
    name: 'FTP',
    protocol: 'tcp',
    port: 21,
    icon: FluentIcons.folder,
  ),
  ServiceTemplate(
    name: 'SMTP',
    protocol: 'tcp',
    port: 25,
    icon: FluentIcons.mail,
  ),
  ServiceTemplate(
    name: 'DNS',
    protocol: 'udp',
    port: 53,
    icon: FluentIcons.rename,
  ),
  ServiceTemplate(
    name: 'MySQL',
    protocol: 'tcp',
    port: 3306,
    icon: FluentIcons.database,
  ),
  ServiceTemplate(
    name: 'PostgreSQL',
    protocol: 'tcp',
    port: 5432,
    icon: FluentIcons.database,
  ),
  ServiceTemplate(
    name: 'MongoDB',
    protocol: 'tcp',
    port: 27017,
    icon: FluentIcons.database,
  ),
  ServiceTemplate(
    name: 'Redis',
    protocol: 'tcp',
    port: 6379,
    icon: FluentIcons.database,
  ),
  ServiceTemplate(
    name: 'Custom',
    protocol: 'tcp',
    port: 0,
    icon: FluentIcons.settings,
  ),
];

/// A connected device with its IP from the topology
class ConnectedEndpoint {
  final VirtualDevice device;
  final VirtualConnection connection;
  final String portName;

  const ConnectedEndpoint({
    required this.device,
    required this.connection,
    required this.portName,
  });

  /// Display name with IP if available
  String get displayName {
    if (device.ipAddress != null && device.ipAddress!.isNotEmpty) {
      return '${device.name} (${device.ipAddress})';
    }
    return device.name;
  }
}

/// Port Forward Wizard - simplifies creating Static PAT rules
class PortForwardWizard extends StatefulWidget {
  const PortForwardWizard({super.key, required this.device});

  final NetDevice device;

  @override
  State<PortForwardWizard> createState() => _PortForwardWizardState();
}

class _PortForwardWizardState extends State<PortForwardWizard> {
  ServiceTemplate? _selectedService;
  ConnectedEndpoint? _selectedEndpoint;

  // Custom service fields
  final _customProtocolController = TextEditingController(text: 'tcp');
  final _customLocalPortController = TextEditingController();
  final _customGlobalPortController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Get interfaces configured as NAT inside
  Set<String> _getInsideInterfaces() {
    final insideInterfaces = <String>{};
    final interfaces = widget.device.interfaces;
    final portsData = widget.device.config['ports'];

    for (int i = 0; i < interfaces.length; i++) {
      Map<String, dynamic>? portConfig;

      // Handle both List and Map formats for ports config
      if (portsData is List && i < portsData.length) {
        portConfig = portsData[i] as Map<String, dynamic>?;
      } else if (portsData is Map<String, dynamic>) {
        portConfig = portsData[i.toString()] as Map<String, dynamic>?;
      }

      if (portConfig != null) {
        final roleStr = portConfig['natRole'] as String?;
        if (roleStr == 'inside') {
          insideInterfaces.add(interfaces[i].name);
        }
      }
    }
    return insideInterfaces;
  }

  /// Walk the topology graph to find all reachable virtual devices
  /// starting from the inside interfaces of this device
  List<ConnectedEndpoint> _getConnectedEndpoints(AppState appState) {
    final topology = appState.selectedProject?.properties.topology;
    if (topology == null) return [];

    final devices = appState.devices;
    final insideInterfaces = _getInsideInterfaces();

    // Track visited devices to avoid infinite loops
    final visitedDevices = <int>{widget.device.id};
    final endpoints = <ConnectedEndpoint>[];

    // Queue of (deviceId, portName) to explore
    final toExplore = <(int, String?)>[];

    // Start with connections from this device's inside interfaces
    // Check device-to-device connections
    for (final conn in topology.connections) {
      if (conn.sourceDeviceId == widget.device.id &&
          (insideInterfaces.isEmpty ||
              insideInterfaces.contains(conn.sourcePort))) {
        toExplore.add((conn.targetDeviceId, conn.targetPort));
      } else if (conn.targetDeviceId == widget.device.id &&
          (insideInterfaces.isEmpty ||
              insideInterfaces.contains(conn.targetPort))) {
        toExplore.add((conn.sourceDeviceId, conn.sourcePort));
      }
    }

    // Also check virtual devices directly connected to this device's inside interfaces
    for (final vConn in topology.virtualConnections) {
      if (vConn.realDeviceId == widget.device.id &&
          (insideInterfaces.isEmpty ||
              insideInterfaces.contains(vConn.realDevicePort))) {
        final vDevice = topology.virtualDevices.firstWhere(
          (v) => v.id == vConn.virtualDeviceId,
          orElse: () => VirtualDevice(
            id: '',
            type: VirtualDeviceType.pc,
            name: 'Unknown',
            x: 0,
            y: 0,
          ),
        );
        if (vDevice.id.isNotEmpty) {
          endpoints.add(
            ConnectedEndpoint(
              device: vDevice,
              connection: vConn,
              portName: vConn.realDevicePort,
            ),
          );
        }
      }
    }

    // BFS through connected devices
    while (toExplore.isNotEmpty) {
      final (currentDeviceId, _) = toExplore.removeAt(0);

      if (visitedDevices.contains(currentDeviceId)) continue;
      visitedDevices.add(currentDeviceId);

      // Find virtual devices connected to this device
      for (final vConn in topology.virtualConnections) {
        if (vConn.realDeviceId == currentDeviceId) {
          final vDevice = topology.virtualDevices.firstWhere(
            (v) => v.id == vConn.virtualDeviceId,
            orElse: () => VirtualDevice(
              id: '',
              type: VirtualDeviceType.pc,
              name: 'Unknown',
              x: 0,
              y: 0,
            ),
          );
          if (vDevice.id.isNotEmpty) {
            endpoints.add(
              ConnectedEndpoint(
                device: vDevice,
                connection: vConn,
                portName: vConn.realDevicePort,
              ),
            );
          }
        }
      }

      // Check if this is a switch (layer 2 device) - if so, continue walking
      final device = devices.firstWhere(
        (d) => d.id == currentDeviceId,
        orElse: () => widget.device, // fallback
      );

      // Only continue walking through layer 2 devices (switches)
      // Routers would be a boundary
      final isSwitch =
          device.preset.capabilities.contains('vlan') &&
          !device.preset.capabilities.contains('static-routing');

      if (isSwitch) {
        // Add all connections from this switch to explore
        for (final conn in topology.connections) {
          if (conn.sourceDeviceId == currentDeviceId &&
              !visitedDevices.contains(conn.targetDeviceId)) {
            toExplore.add((conn.targetDeviceId, conn.targetPort));
          } else if (conn.targetDeviceId == currentDeviceId &&
              !visitedDevices.contains(conn.sourceDeviceId)) {
            toExplore.add((conn.sourceDeviceId, conn.sourcePort));
          }
        }
      }
    }

    return endpoints;
  }

  Future<void> _createPortForward() async {
    if (_selectedService == null || _selectedEndpoint == null) return;

    final service = _selectedService!;
    final endpoint = _selectedEndpoint!;

    // Get values based on custom or template
    final protocol = service.name == 'Custom'
        ? _customProtocolController.text
        : service.protocol;
    final localPort = service.name == 'Custom'
        ? int.tryParse(_customLocalPortController.text) ?? 0
        : service.port;
    final globalPort = service.name == 'Custom'
        ? int.tryParse(_customGlobalPortController.text) ?? localPort
        : service.port;

    if (localPort == 0) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Error'),
          content: const Text('Please specify a valid port number'),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
      return;
    }

    // Create the Static PAT rule
    final description = _descriptionController.text.isNotEmpty
        ? _descriptionController.text
        : '${service.name} to ${endpoint.device.name}';

    final rule = NatRule(
      type: NatType.staticPat,
      description: description,
      insideLocal: endpoint.device.ipAddress,
      protocol: protocol,
      localPort: localPort,
      globalPort: globalPort,
      enabled: true,
    );

    // Add the rule
    final rules = widget.device.natRules;
    final updatedRules = [...rules, rule];

    await Database.updateDeviceConfig(widget.device.id, {
      'nat_rules': updatedRules.map((r) => r.toJson()).toList(),
    });

    if (mounted) {
      Navigator.of(context).pop();
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Port Forward Created'),
          content: Text(
            'Forwarding ${service.name} ($protocol/$globalPort) to ${endpoint.device.name}',
          ),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  Widget _buildServiceGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _commonServices.map((service) {
        final isSelected = _selectedService == service;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedService = service;
              // Reset custom port fields when selecting a template
              if (service.name != 'Custom') {
                _customLocalPortController.clear();
                _customGlobalPortController.clear();
              }
            });
          },
          child: Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? FluentTheme.of(context).accentColor.withValues(alpha: 0.2)
                  : FluentTheme.of(context).cardColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? FluentTheme.of(context).accentColor
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  service.icon,
                  size: 24,
                  color: isSelected
                      ? FluentTheme.of(context).accentColor
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  service.name,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (service.port > 0)
                  Text(
                    '${service.port}',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: Colors.grey[100],
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEndpointList(List<ConnectedEndpoint> endpoints) {
    if (endpoints.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: InfoBar(
          title: Text('No Connected Devices'),
          content: Text(
            'Add virtual devices (PCs, Servers) to the topology and connect them to this router to enable quick port forwarding.',
          ),
          severity: InfoBarSeverity.info,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Forward to:', style: FluentTheme.of(context).typography.body),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: endpoints.map((endpoint) {
            final isSelected = _selectedEndpoint == endpoint;
            final icon = _getDeviceIcon(endpoint.device.type);

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedEndpoint = endpoint;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FluentTheme.of(
                          context,
                        ).accentColor.withValues(alpha: 0.2)
                      : FluentTheme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? FluentTheme.of(context).accentColor
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isSelected
                          ? FluentTheme.of(context).accentColor
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          endpoint.device.name,
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(
                                fontWeight: isSelected ? FontWeight.w600 : null,
                              ),
                        ),
                        if (endpoint.device.ipAddress != null)
                          Text(
                            endpoint.device.ipAddress!,
                            style: FluentTheme.of(context).typography.caption
                                ?.copyWith(
                                  color: Colors.grey[100],
                                  fontSize: 10,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedEndpoint != null &&
            (_selectedEndpoint!.device.ipAddress == null ||
                _selectedEndpoint!.device.ipAddress!.isEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InfoBar(
              title: const Text('IP Required'),
              content: Text(
                '${_selectedEndpoint!.device.name} needs an IP address. Configure it in the topology view.',
              ),
              severity: InfoBarSeverity.warning,
            ),
          ),
      ],
    );
  }

  Widget _buildCustomServiceFields() {
    if (_selectedService?.name != 'Custom') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Custom Service',
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Protocol'),
                  const SizedBox(height: 4),
                  ComboBox<String>(
                    value: _customProtocolController.text,
                    isExpanded: true,
                    popupColor: FluentTheme.of(context).menuColor,
                    items: const [
                      ComboBoxItem(value: 'tcp', child: Text('TCP')),
                      ComboBoxItem(value: 'udp', child: Text('UDP')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _customProtocolController.text = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Local Port'),
                  const SizedBox(height: 4),
                  TextBox(
                    controller: _customLocalPortController,
                    placeholder: 'e.g., 8080',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('External Port (optional)'),
                  const SizedBox(height: 4),
                  TextBox(
                    controller: _customGlobalPortController,
                    placeholder: 'Same as local',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getDeviceIcon(VirtualDeviceType type) {
    switch (type) {
      case VirtualDeviceType.pc:
        return FluentIcons.desktop_flow;
      case VirtualDeviceType.server:
        return FluentIcons.server;
      case VirtualDeviceType.cloud:
        return FluentIcons.cloud;
      case VirtualDeviceType.phone:
        return FluentIcons.cell_phone;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final endpoints = _getConnectedEndpoints(appState);
        final canCreate =
            _selectedService != null &&
            _selectedEndpoint != null &&
            _selectedEndpoint!.device.ipAddress != null &&
            _selectedEndpoint!.device.ipAddress!.isNotEmpty &&
            (_selectedService!.name != 'Custom' ||
                _customLocalPortController.text.isNotEmpty);

        return ContentDialog(
          title: const Text('Quick Port Forward'),
          constraints: const BoxConstraints(maxWidth: 550),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '1. Select Service',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 8),
                _buildServiceGrid(),
                _buildCustomServiceFields(),
                const SizedBox(height: 16),
                Text(
                  '2. Select Destination',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 8),
                _buildEndpointList(endpoints),
                const SizedBox(height: 16),
                const Text('Description (optional)'),
                const SizedBox(height: 4),
                TextBox(
                  controller: _descriptionController,
                  placeholder:
                      _selectedService != null && _selectedEndpoint != null
                      ? '${_selectedService!.name} to ${_selectedEndpoint!.device.name}'
                      : 'e.g., Web server access',
                ),
                const SizedBox(height: 16),
                if (_selectedService != null && _selectedEndpoint != null)
                  _buildPreview(),
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: canCreate ? _createPortForward : null,
              child: const Text('Create Port Forward'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreview() {
    final service = _selectedService!;
    final endpoint = _selectedEndpoint!;

    final protocol = service.name == 'Custom'
        ? _customProtocolController.text.toUpperCase()
        : service.protocol.toUpperCase();
    final port = service.name == 'Custom'
        ? _customLocalPortController.text
        : service.port.toString();
    final globalPort =
        service.name == 'Custom' && _customGlobalPortController.text.isNotEmpty
        ? _customGlobalPortController.text
        : port;

    return InfoBar(
      title: const Text('Preview'),
      content: Text(
        'External $protocol port $globalPort → '
        '${endpoint.device.ipAddress ?? "?"} port $port',
      ),
      severity: InfoBarSeverity.info,
    );
  }

  @override
  void dispose() {
    _customProtocolController.dispose();
    _customLocalPortController.dispose();
    _customGlobalPortController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
