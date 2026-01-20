import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:provider/provider.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class StaticRoutesList extends StatefulWidget {
  const StaticRoutesList({super.key, required this.device});
  final NetDevice device;

  @override
  State<StaticRoutesList> createState() => _StaticRoutesListState();
}

class _StaticRoutesListState extends State<StaticRoutesList> {
  StaticRouteConfig? _selectedRoute;
  int _selectedIndex = -1;

  @override
  void didUpdateWidget(StaticRoutesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device.id != oldWidget.device.id) {
      _selectedRoute = null;
      _selectedIndex = -1;
    }
  }

  Future<void> _addRoute(StaticRouteConfig route) async {
    final routes = widget.device.staticRoutes;
    final updatedRoutes = [...routes, route];

    await Database.updateDeviceConfig(widget.device.id, {
      'static_routes': updatedRoutes.map((r) => r.toJson()).toList(),
    });
  }

  Future<void> _updateRoute(int index, StaticRouteConfig route) async {
    final routes = widget.device.staticRoutes;
    final updatedRoutes = [...routes];
    updatedRoutes[index] = route;

    await Database.updateDeviceConfig(widget.device.id, {
      'static_routes': updatedRoutes.map((r) => r.toJson()).toList(),
    });

    _selectedRoute = route;
  }

  Future<void> _deleteRoute(int index) async {
    final routes = widget.device.staticRoutes;
    final updatedRoutes = [...routes]..removeAt(index);

    await Database.updateDeviceConfig(widget.device.id, {
      'static_routes': updatedRoutes.map((r) => r.toJson()).toList(),
    });

    _selectedRoute = null;
    _selectedIndex = -1;
    setState(() {});
  }

  /// Get connected virtual devices from topology by walking the graph
  /// Follows connections through switches to find all reachable endpoints
  List<VirtualDevice> _getConnectedVirtualDevices() {
    final appState = context.read<AppState>();
    final topology = appState.selectedProject?.properties.topology;
    if (topology == null) return [];

    final devices = appState.devices;

    // Track visited devices to avoid infinite loops
    final visitedDevices = <int>{widget.device.id};
    final connectedDevices = <VirtualDevice>[];

    // Queue of device IDs to explore
    final toExplore = <int>[];

    // Start with all connections from this device
    for (final conn in topology.connections) {
      if (conn.sourceDeviceId == widget.device.id) {
        toExplore.add(conn.targetDeviceId);
      } else if (conn.targetDeviceId == widget.device.id) {
        toExplore.add(conn.sourceDeviceId);
      }
    }

    // Also check virtual devices directly connected to this device
    for (final vConn in topology.virtualConnections) {
      if (vConn.realDeviceId == widget.device.id) {
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
        if (vDevice.id.isNotEmpty && vDevice.ipAddress != null) {
          connectedDevices.add(vDevice);
        }
      }
    }

    // BFS through connected devices
    while (toExplore.isNotEmpty) {
      final currentDeviceId = toExplore.removeAt(0);

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
          if (vDevice.id.isNotEmpty && vDevice.ipAddress != null) {
            connectedDevices.add(vDevice);
          }
        }
      }

      // Check if this is a switch (layer 2 device) - continue walking if so
      final device = devices.firstWhere(
        (d) => d.id == currentDeviceId,
        orElse: () => widget.device,
      );

      // Only continue through layer 2 devices (switches), not routers
      final isSwitch =
          device.preset.capabilities.contains('vlan') &&
          !device.preset.capabilities.contains('static-routing');

      if (isSwitch) {
        for (final conn in topology.connections) {
          if (conn.sourceDeviceId == currentDeviceId &&
              !visitedDevices.contains(conn.targetDeviceId)) {
            toExplore.add(conn.targetDeviceId);
          } else if (conn.targetDeviceId == currentDeviceId &&
              !visitedDevices.contains(conn.sourceDeviceId)) {
            toExplore.add(conn.sourceDeviceId);
          }
        }
      }
    }

    return connectedDevices;
  }

  /// Get icon for virtual device type
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

  void _showAddRouteDialog() {
    final destinationController = TextEditingController();
    final nextHopController = TextEditingController();
    final adminDistanceController = TextEditingController();
    final nameController = TextEditingController();
    String? selectedInterface;
    VirtualDevice? selectedDevice;

    final connectedDevices = _getConnectedVirtualDevices();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // When a device is selected, auto-fill the next hop and destination
          void selectDevice(VirtualDevice? device) {
            setDialogState(() {
              selectedDevice = device;
              if (device != null && device.ipAddress != null) {
                // Set destination as the device's IP with /32 (host route)
                destinationController.text = '${device.ipAddress}/32';
                // Set name to device name
                if (nameController.text.isEmpty) {
                  nameController.text = 'Route to ${device.name}';
                }
              }
            });
          }

          return ContentDialog(
            title: const Text('Add Static Route'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick device selection from topology
                  if (connectedDevices.isNotEmpty) ...[
                    Text(
                      'Quick Select (from Topology)',
                      style: FluentTheme.of(context).typography.bodyStrong,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: connectedDevices.map((device) {
                        final isSelected = selectedDevice?.id == device.id;
                        return GestureDetector(
                          onTap: () => selectDevice(isSelected ? null : device),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FluentTheme.of(
                                      context,
                                    ).accentColor.withValues(alpha: 0.2)
                                  : FluentTheme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? FluentTheme.of(context).accentColor
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getDeviceIcon(device.type), size: 14),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      device.name,
                                      style: FluentTheme.of(
                                        context,
                                      ).typography.caption,
                                    ),
                                    if (device.ipAddress != null)
                                      Text(
                                        device.ipAddress!,
                                        style: FluentTheme.of(context)
                                            .typography
                                            .caption
                                            ?.copyWith(
                                              fontSize: 10,
                                              color: Colors.grey[100],
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
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Or Enter Manually',
                      style: FluentTheme.of(context).typography.bodyStrong,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Text('Destination Network (CIDR)'),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 220,
                    child: TextBox(
                      controller: destinationController,
                      placeholder: 'e.g., 0.0.0.0/0 or 10.0.0.0/8',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Next Hop IP (optional if exit interface set)'),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 180,
                    child: TextBox(
                      controller: nextHopController,
                      placeholder: 'e.g., 192.168.1.1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Exit Interface (optional)'),
                  const SizedBox(height: 4),
                  ComboBox<String>(
                    value: selectedInterface,
                    items: [
                      const ComboBoxItem(value: null, child: Text('None')),
                      ...widget.device.interfaces.map(
                        (p) => ComboBoxItem(value: p.name, child: Text(p.name)),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedInterface = v),
                    placeholder: const Text('Select interface'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Administrative Distance (optional)'),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 100,
                    child: NumberBox<int>(
                      value: int.tryParse(adminDistanceController.text),
                      onChanged: (v) =>
                          adminDistanceController.text = v?.toString() ?? '',
                      min: 1,
                      max: 255,
                      placeholder: '1-255',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Name/Description (optional)'),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 250,
                    child: TextBox(
                      controller: nameController,
                      placeholder: 'Route description',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final destination = destinationController.text.trim();
                  if (destination.isEmpty) return;

                  // Must have either next hop or exit interface
                  final nextHop = nextHopController.text.trim();
                  if (nextHop.isEmpty && selectedInterface == null) {
                    return;
                  }

                  _addRoute(
                    StaticRouteConfig(
                      destinationNetwork: destination,
                      nextHop: nextHop.isNotEmpty ? nextHop : null,
                      exitInterface: selectedInterface,
                      adminDistance: int.tryParse(adminDistanceController.text),
                      name: nameController.text.isNotEmpty
                          ? nameController.text.trim()
                          : null,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRouteItem(StaticRouteConfig route, int index) {
    final isDefault = route.destinationNetwork == '0.0.0.0/0';

    return ListTile.selectable(
      title: Text(
        route.destinationNetwork,
        style: TextStyle(
          fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        [
          if (route.nextHop != null) 'via ${route.nextHop}',
          if (route.exitInterface != null) 'out ${route.exitInterface}',
          if (route.adminDistance != null) '[${route.adminDistance}]',
          if (route.name != null) '- ${route.name}',
        ].join(' '),
      ),
      leading: Icon(
        isDefault ? FluentIcons.globe : FluentIcons.branch_fork2,
        size: 16,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!route.enabled)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(FluentIcons.blocked, size: 14),
            ),
          IconButton(
            icon: const Icon(FluentIcons.delete, size: 14),
            onPressed: () => _deleteRoute(index),
          ),
        ],
      ),
      selected: _selectedIndex == index,
      onPressed: () {
        setState(() {
          if (_selectedIndex == index) {
            _selectedRoute = null;
            _selectedIndex = -1;
          } else {
            _selectedRoute = route;
            _selectedIndex = index;
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final routes = widget.device.staticRoutes;

    return Row(
      children: [
        // Left: Routes list
        SizedBox(
          width: 400,
          child: Column(
            children: [
              CommandBar(
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.add),
                    label: const Text('Add Route'),
                    onPressed: _showAddRouteDialog,
                  ),
                ],
              ),
              Expanded(
                child: routes.isEmpty
                    ? const Center(child: Text('No static routes configured'))
                    : ListView.builder(
                        itemCount: routes.length,
                        itemBuilder: (context, index) =>
                            _buildRouteItem(routes[index], index),
                      ),
              ),
            ],
          ),
        ),
        // Right: Route details/editor
        Expanded(
          child: _selectedRoute == null
              ? const Center(
                  child: Text('Select a route to view or edit details'),
                )
              : _RouteDetails(
                  route: _selectedRoute!,
                  device: widget.device,
                  index: _selectedIndex,
                  onUpdate: (route) => _updateRoute(_selectedIndex, route),
                  onDelete: () => _deleteRoute(_selectedIndex),
                ),
        ),
      ],
    );
  }
}

class _RouteDetails extends StatefulWidget {
  const _RouteDetails({
    required this.route,
    required this.device,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });
  final StaticRouteConfig route;
  final NetDevice device;
  final int index;
  final Function(StaticRouteConfig) onUpdate;
  final VoidCallback onDelete;

  @override
  State<_RouteDetails> createState() => _RouteDetailsState();
}

class _RouteDetailsState extends State<_RouteDetails> {
  late TextEditingController _destinationController;
  late TextEditingController _nextHopController;
  late TextEditingController _adminDistanceController;
  late TextEditingController _nameController;
  String? _exitInterface;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(_RouteDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.route != oldWidget.route) {
      _initControllers();
    }
  }

  void _initControllers() {
    _destinationController = TextEditingController(
      text: widget.route.destinationNetwork,
    );
    _nextHopController = TextEditingController(
      text: widget.route.nextHop ?? '',
    );
    _adminDistanceController = TextEditingController(
      text: widget.route.adminDistance?.toString() ?? '',
    );
    _nameController = TextEditingController(text: widget.route.name ?? '');
    _exitInterface = widget.route.exitInterface;
    _enabled = widget.route.enabled;
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _nextHopController.dispose();
    _adminDistanceController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) return;

    final nextHop = _nextHopController.text.trim();
    if (nextHop.isEmpty && _exitInterface == null) return;

    widget.onUpdate(
      StaticRouteConfig(
        destinationNetwork: destination,
        nextHop: nextHop.isNotEmpty ? nextHop : null,
        exitInterface: _exitInterface,
        adminDistance: int.tryParse(_adminDistanceController.text),
        name: _nameController.text.isNotEmpty
            ? _nameController.text.trim()
            : null,
        enabled: _enabled,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FluentWidgets.mica(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Static Route Details',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            const SizedBox(height: 16),
            const Text('Destination Network'),
            const SizedBox(height: 4),
            SizedBox(
              width: 220,
              child: TextBox(
                controller: _destinationController,
                placeholder: 'e.g., 0.0.0.0/0',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Next Hop IP'),
            const SizedBox(height: 4),
            SizedBox(
              width: 180,
              child: TextBox(
                controller: _nextHopController,
                placeholder: 'e.g., 192.168.1.1',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Exit Interface'),
            const SizedBox(height: 4),
            ComboBox<String>(
              value: _exitInterface,
              items: [
                const ComboBoxItem(value: null, child: Text('None')),
                ...widget.device.interfaces.map(
                  (p) => ComboBoxItem(value: p.name, child: Text(p.name)),
                ),
              ],
              onChanged: (v) => setState(() => _exitInterface = v),
              placeholder: const Text('Select interface'),
            ),
            const SizedBox(height: 12),
            const Text('Administrative Distance'),
            const SizedBox(height: 4),
            SizedBox(
              width: 100,
              child: NumberBox<int>(
                value: int.tryParse(_adminDistanceController.text),
                onChanged: (v) =>
                    _adminDistanceController.text = v?.toString() ?? '',
                min: 1,
                max: 255,
                placeholder: '1-255',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Name/Description'),
            const SizedBox(height: 4),
            SizedBox(
              width: 250,
              child: TextBox(
                controller: _nameController,
                placeholder: 'Route description',
              ),
            ),
            const SizedBox(height: 12),
            Checkbox(
              checked: _enabled,
              onChanged: (v) => setState(() => _enabled = v ?? true),
              content: const Text('Enabled'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save Changes'),
                ),
                const SizedBox(width: 8),
                Button(
                  onPressed: widget.onDelete,
                  child: const Text('Delete Route'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
