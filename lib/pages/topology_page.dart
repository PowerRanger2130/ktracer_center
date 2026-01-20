import 'dart:math' as math;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/devices/device_preset.dart';
import 'package:ktracer_center/devices/system_constraints.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/network/port.dart';
import 'package:provider/provider.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';
import 'package:vector_math/vector_math_64.dart' show Quad;

/// Generate a unique ID for virtual devices
String _generateUniqueId() {
  final now = DateTime.now();
  final random = math.Random();
  return '${now.millisecondsSinceEpoch}_${random.nextInt(99999)}';
}

class TopologyPage extends StatefulWidget {
  const TopologyPage({super.key});

  @override
  State<TopologyPage> createState() => _TopologyPageState();
}

class _TopologyPageState extends State<TopologyPage> {
  final Map<int, TopologyPosition> _positions = {};
  final List<TopologyConnection> _connections = [];
  final List<VirtualDevice> _virtualDevices = [];
  final List<VirtualConnection> _virtualConnections = [];
  final TransformationController _transformController =
      TransformationController();

  // Canvas offset to allow negative coordinates (center of canvas is logical origin)
  static const double canvasOffset = 50000.0;

  // For creating new connections
  int? _connectingFromDeviceId;
  String? _connectingFromPort;
  Offset? _connectingMousePosition; // In canvas coordinates

  // For connecting from virtual device
  String? _connectingFromVirtualId;

  // For dragging devices
  int? _draggingDeviceId;
  String? _draggingVirtualId;
  Offset? _lastDragPosition;

  // Track the current project to detect changes
  int? _currentProjectId;

  // Track if we've centered the viewport for current project
  bool _hasInitializedViewport = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _centerViewportOnDevices() {
    if (_hasInitializedViewport) return;
    _hasInitializedViewport = true;

    // Calculate the center of all devices, or use origin if no devices
    double centerX = 0;
    double centerY = 0;

    if (_positions.isNotEmpty) {
      double sumX = 0, sumY = 0;
      for (final pos in _positions.values) {
        sumX += pos.x;
        sumY += pos.y;
      }
      centerX = sumX / _positions.length;
      centerY = sumY / _positions.length;
    }

    // Set initial transform to center the viewport on the devices
    // We need to translate so that (centerX + canvasOffset, centerY + canvasOffset)
    // appears roughly in the center of the visible area
    final viewportCenter = Offset(
      centerX + canvasOffset - 400, // Offset by roughly half viewport width
      centerY + canvasOffset - 300, // Offset by roughly half viewport height
    );

    // Set the transform directly on the controller's initial value
    // Use Future.microtask to avoid layout conflicts
    Future.microtask(() {
      if (!mounted) return;
      _transformController.value = Matrix4.identity()
        ..translate(-viewportCenter.dx, -viewportCenter.dy);
    });
  }

  void _loadTopology(AppState state) {
    final project = state.selectedProject;
    final projectId = project?.id;

    // Detect project change and reset state
    if (projectId != _currentProjectId) {
      _currentProjectId = projectId;
      _positions.clear();
      _connections.clear();
      _virtualDevices.clear();
      _virtualConnections.clear();
      _hasInitializedViewport = false;
      _connectingFromDeviceId = null;
      _connectingFromPort = null;
      _connectingMousePosition = null;
      _connectingFromVirtualId = null;
    }

    if (project == null) return;

    final topology = project.properties.topology;
    if (topology == null) return;

    // Load positions (only if not already loaded for this project)
    if (_positions.isEmpty) {
      for (final pos in topology.positions) {
        _positions[pos.deviceId] = pos;
      }
    }

    // Load connections (only if not already loaded for this project)
    if (_connections.isEmpty && topology.connections.isNotEmpty) {
      _connections.addAll(topology.connections);
    }

    // Load virtual devices
    if (_virtualDevices.isEmpty && topology.virtualDevices.isNotEmpty) {
      _virtualDevices.addAll(topology.virtualDevices);
    }

    // Load virtual connections
    if (_virtualConnections.isEmpty && topology.virtualConnections.isNotEmpty) {
      _virtualConnections.addAll(topology.virtualConnections);
    }
  }

  /// Add permanent router-switch connections based on the devices in the project.
  /// These connections are automatically created when both router and switch are present.
  void _addPermanentConnections(List<NetDevice> devices) {
    for (final conn in permanentRouterSwitchConnections) {
      // Find the router and switch devices by realId
      final router = devices
          .where((d) => d.realId == conn.routerRealId)
          .firstOrNull;
      final switchDevice = devices
          .where((d) => d.realId == conn.switchRealId)
          .firstOrNull;

      if (router != null && switchDevice != null) {
        // Check if this connection already exists
        final exists = _connections.any(
          (c) =>
              (c.sourceDeviceId == router.id &&
                  c.targetDeviceId == switchDevice.id &&
                  c.sourcePort == conn.routerPort &&
                  c.targetPort == conn.switchPort) ||
              (c.sourceDeviceId == switchDevice.id &&
                  c.targetDeviceId == router.id &&
                  c.sourcePort == conn.switchPort &&
                  c.targetPort == conn.routerPort),
        );

        if (!exists) {
          _connections.add(
            TopologyConnection(
              sourceDeviceId: router.id,
              sourcePort: conn.routerPort,
              targetDeviceId: switchDevice.id,
              targetPort: conn.switchPort,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveTopology() async {
    final state = context.read<AppState>();
    final project = state.selectedProject;
    if (project == null) return;

    final topologyData = TopologyData(
      positions: _positions.values.toList(),
      connections: _connections,
      virtualDevices: _virtualDevices,
      virtualConnections: _virtualConnections,
    );

    await project.updateProperties(
      project.properties.copyWith(topology: topologyData),
    );
  }

  void _initializePositions(List<NetDevice> devices) {
    // Initialize positions for devices that don't have one
    for (int i = 0; i < devices.length; i++) {
      final device = devices[i];
      if (!_positions.containsKey(device.id)) {
        // Arrange in a grid pattern
        final col = i % 3;
        final row = i ~/ 3;
        _positions[device.id] = TopologyPosition(
          deviceId: device.id,
          x: 100 + col * 250.0,
          y: 100 + row * 200.0,
        );
      }
    }
    // Remove positions for devices that no longer exist
    _positions.removeWhere((id, _) => !devices.any((d) => d.id == id));
  }

  void _startConnection(int deviceId, String port) {
    setState(() {
      _connectingFromDeviceId = deviceId;
      _connectingFromPort = port;
    });
  }

  void _completeConnection(int targetDeviceId, String targetPort) {
    if (_connectingFromDeviceId != null &&
        _connectingFromPort != null &&
        _connectingFromDeviceId != targetDeviceId) {
      // Check if connection already exists
      final exists = _connections.any(
        (c) =>
            (c.sourceDeviceId == _connectingFromDeviceId &&
                c.sourcePort == _connectingFromPort) ||
            (c.targetDeviceId == _connectingFromDeviceId &&
                c.targetPort == _connectingFromPort) ||
            (c.sourceDeviceId == targetDeviceId &&
                c.sourcePort == targetPort) ||
            (c.targetDeviceId == targetDeviceId && c.targetPort == targetPort),
      );

      if (!exists) {
        setState(() {
          _connections.add(
            TopologyConnection(
              sourceDeviceId: _connectingFromDeviceId!,
              sourcePort: _connectingFromPort!,
              targetDeviceId: targetDeviceId,
              targetPort: targetPort,
            ),
          );
          _saveTopology();
        });
      }
    }
    _cancelConnection();
  }

  void _cancelConnection() {
    setState(() {
      _connectingFromDeviceId = null;
      _connectingFromPort = null;
      _connectingFromVirtualId = null;
      _connectingMousePosition = null;
    });
  }

  void _removeConnection(TopologyConnection connection) {
    // Check if this is a permanent connection that cannot be removed
    final state = context.read<AppState>();
    final sourceDevice = state.devices
        .where((d) => d.id == connection.sourceDeviceId)
        .firstOrNull;
    final targetDevice = state.devices
        .where((d) => d.id == connection.targetDeviceId)
        .firstOrNull;

    if (sourceDevice?.realId != null && targetDevice?.realId != null) {
      return;
      /*
      if (isPermanentConnection(
        sourceRealId: sourceDevice!.realId!,
        sourcePort: connection.sourcePort,
        targetRealId: targetDevice!.realId!,
        targetPort: connection.targetPort,
      )) {
        // Show message that this connection cannot be removed
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('Cannot remove connection'),
            content: const Text('This is a permanent management connection.'),
            severity: InfoBarSeverity.warning,
            onClose: close,
          ),
        );
        return;
      }
      */
    }

    setState(() {
      _connections.remove(connection);
    });
    _saveTopology();
  }

  Future<void> _deleteDeviceFromTopology(int deviceId) async {
    final state = context.read<AppState>();
    final device = state.devices.firstWhere((d) => d.id == deviceId);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text('Remove ${device.hostname}'),
        content: const Text(
          'Do you want to remove this device from the topology view only, '
          'or delete it completely from the project?',
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          Button(
            child: const Text('Remove from View'),
            onPressed: () => Navigator.pop(ctx, 'view'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Delete from Project'),
            onPressed: () => Navigator.pop(ctx, 'delete'),
          ),
        ],
      ),
    );

    if (result == null) return;

    // Remove from topology view
    setState(() {
      _positions.remove(deviceId);
      _connections.removeWhere(
        (c) => c.sourceDeviceId == deviceId || c.targetDeviceId == deviceId,
      );
    });
    await _saveTopology();

    // If user chose to delete completely, also delete from project
    if (result == 'delete') {
      await state.deleteDevice(deviceId, navigate: false);
    }
  }

  Future<void> _addDeviceFromPreset(
    DevicePreset preset,
    Offset canvasPosition,
  ) async {
    final state = context.read<AppState>();
    // Remember current navigation index before adding device
    final currentNavIndex = state.navigationIndex;

    // Add device without realId - it gets assigned later when deploying
    final device = await state.addDevice(preset.id);

    if (device != null && mounted) {
      setState(() {
        _positions[device.id] = TopologyPosition(
          deviceId: device.id,
          x: canvasPosition.dx,
          y: canvasPosition.dy,
        );
      });
      await _saveTopology();
    }

    // Restore navigation index if it changed (adding device can shift indices)
    if (mounted && state.navigationIndex != currentNavIndex) {
      state.setNavigationIndex(currentNavIndex);
    }
  }

  void _addVirtualDevice(VirtualDeviceType type, Offset canvasPosition) {
    final name = switch (type) {
      VirtualDeviceType.pc =>
        'PC${_virtualDevices.where((v) => v.type == VirtualDeviceType.pc).length + 1}',
      VirtualDeviceType.server =>
        'Server${_virtualDevices.where((v) => v.type == VirtualDeviceType.server).length + 1}',
      VirtualDeviceType.cloud =>
        'Cloud${_virtualDevices.where((v) => v.type == VirtualDeviceType.cloud).length + 1}',
      VirtualDeviceType.phone =>
        'Phone${_virtualDevices.where((v) => v.type == VirtualDeviceType.phone).length + 1}',
    };

    setState(() {
      _virtualDevices.add(
        VirtualDevice(
          id: _generateUniqueId(),
          type: type,
          name: name,
          x: canvasPosition.dx,
          y: canvasPosition.dy,
        ),
      );
    });
    _saveTopology();
  }

  void _deleteVirtualDevice(String virtualId) {
    setState(() {
      _virtualDevices.removeWhere((v) => v.id == virtualId);
      _virtualConnections.removeWhere((c) => c.virtualDeviceId == virtualId);
    });
    _saveTopology();
  }

  void _startVirtualConnection(String virtualId) {
    setState(() {
      _connectingFromVirtualId = virtualId;
      _connectingFromDeviceId = null;
      _connectingFromPort = null;
    });
  }

  void _completeVirtualConnection(int targetDeviceId, String targetPort) {
    if (_connectingFromVirtualId != null) {
      // Check if connection already exists
      final exists = _virtualConnections.any(
        (c) =>
            c.virtualDeviceId == _connectingFromVirtualId &&
            c.realDeviceId == targetDeviceId &&
            c.realDevicePort == targetPort,
      );

      if (!exists) {
        setState(() {
          _virtualConnections.add(
            VirtualConnection(
              virtualDeviceId: _connectingFromVirtualId!,
              realDeviceId: targetDeviceId,
              realDevicePort: targetPort,
            ),
          );
        });
        _saveTopology();
      }
    }
    _cancelConnection();
  }

  void _removeVirtualConnection(VirtualConnection connection) {
    setState(() {
      _virtualConnections.remove(connection);
    });
    _saveTopology();
  }

  Future<void> _editVirtualDevice(VirtualDevice device) async {
    final nameController = TextEditingController(text: device.name);
    final ipController = TextEditingController(text: device.ipAddress ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text('Edit ${device.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoLabel(
              label: 'Name',
              child: TextBox(controller: nameController),
            ),
            const SizedBox(height: 12),
            InfoLabel(
              label: 'IP Address',
              child: TextBox(
                controller: ipController,
                placeholder: '192.168.1.100',
              ),
            ),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            child: const Text('Save'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        final index = _virtualDevices.indexWhere((v) => v.id == device.id);
        if (index != -1) {
          _virtualDevices[index] = device.copyWith(
            name: nameController.text,
            ipAddress: ipController.text.isNotEmpty ? ipController.text : null,
            clearIpAddress: ipController.text.isEmpty,
          );
        }
      });
      _saveTopology();
    }

    nameController.dispose();
    ipController.dispose();
  }

  void _addVirtualDeviceAtCenter(VirtualDeviceType type) {
    // Calculate center position on canvas
    final matrix = _transformController.value;
    final inverseMatrix = Matrix4.inverted(matrix);
    final canvasPos = MatrixUtils.transformPoint(
      inverseMatrix,
      const Offset(500, 300),
    );
    // Convert to logical position
    final logicalPos = Offset(
      canvasPos.dx - canvasOffset,
      canvasPos.dy - canvasOffset,
    );
    _addVirtualDevice(type, logicalPos);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final devices = state.devices;
    final availablePresets = state.availablePresetsByCategory;
    _loadTopology(state);
    _initializePositions(devices);
    _addPermanentConnections(devices);
    _centerViewportOnDevices();

    return ScaffoldPage(
      header: const PageHeader(title: Text('Topology')),
      content: Row(
        children: [
          // Available lab devices on the left
          SizedBox(
            width: 280,
            child: FluentWidgets.mica(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Available Devices',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: availablePresets.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No available devices.\nAll device slots are in use.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[100]),
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(8),
                            children: [
                              for (final category
                                  in availablePresets.entries) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 4,
                                  ),
                                  child: Text(
                                    category.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[100],
                                    ),
                                  ),
                                ),
                                for (final preset in category.value)
                                  _PresetGroupCard(
                                    preset: preset,
                                    availableCount: state.getAvailableSlots(
                                      preset.id,
                                    ),
                                    onPressed: () {
                                      // Calculate center position on canvas (in canvas coords with offset)
                                      final matrix = _transformController.value;
                                      final inverseMatrix = Matrix4.inverted(
                                        matrix,
                                      );
                                      final canvasPos =
                                          MatrixUtils.transformPoint(
                                            inverseMatrix,
                                            const Offset(500, 300),
                                          );
                                      // Convert to logical position (subtract canvas offset)
                                      final logicalPos = Offset(
                                        canvasPos.dx - canvasOffset,
                                        canvasPos.dy - canvasOffset,
                                      );
                                      _addDeviceFromPreset(preset, logicalPos);
                                    },
                                  ),
                              ],
                            ],
                          ),
                  ),
                  // Virtual devices section
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Virtual Devices',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _VirtualDeviceButton(
                              type: VirtualDeviceType.pc,
                              icon: FluentIcons.desktop_flow,
                              label: 'PC',
                              onPressed: () => _addVirtualDeviceAtCenter(
                                VirtualDeviceType.pc,
                              ),
                            ),
                            _VirtualDeviceButton(
                              type: VirtualDeviceType.server,
                              icon: FluentIcons.server,
                              label: 'Server',
                              onPressed: () => _addVirtualDeviceAtCenter(
                                VirtualDeviceType.server,
                              ),
                            ),
                            _VirtualDeviceButton(
                              type: VirtualDeviceType.cloud,
                              icon: FluentIcons.cloud,
                              label: 'Cloud',
                              onPressed: () => _addVirtualDeviceAtCenter(
                                VirtualDeviceType.cloud,
                              ),
                            ),
                            _VirtualDeviceButton(
                              type: VirtualDeviceType.phone,
                              icon: FluentIcons.cell_phone,
                              label: 'Phone',
                              onPressed: () => _addVirtualDeviceAtCenter(
                                VirtualDeviceType.phone,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Canvas area
          Expanded(
            child: GestureDetector(
              onTap: _cancelConnection,
              child: Listener(
                onPointerMove: (event) {
                  if (_connectingFromDeviceId != null ||
                      _connectingFromVirtualId != null) {
                    // Convert screen position to canvas coordinates
                    final RenderBox? box =
                        context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      // Get local position relative to the InteractiveViewer
                      final localPos = box.globalToLocal(event.position);
                      // Account for the left sidebar width (280)
                      final adjustedPos = Offset(
                        localPos.dx - 280,
                        localPos.dy - 48,
                      ); // 48 for header
                      // Apply inverse transform to get canvas coordinates
                      final matrix = _transformController.value;
                      final inverseMatrix = Matrix4.inverted(matrix);
                      final canvasPos = MatrixUtils.transformPoint(
                        inverseMatrix,
                        adjustedPos,
                      );
                      setState(() {
                        _connectingMousePosition = canvasPos;
                      });
                    }
                  }
                },
                child: InteractiveViewer.builder(
                  transformationController: _transformController,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.02,
                  maxScale: 4.0,
                  interactionEndFrictionCoefficient: 0.0001,
                  scaleFactor: 200, // Higher = slower zoom per scroll
                  builder: (context, viewport) {
                    return SizedBox(
                      width: canvasOffset * 2,
                      height: canvasOffset * 2,
                      child: CustomPaint(
                        painter: _InfiniteGridPainter(
                          viewport: viewport,
                          transform: _transformController.value,
                        ),
                        child: CustomPaint(
                          painter: _ConnectionsPainter(
                            connections: _connections,
                            positions: _positions,
                            virtualDevices: _virtualDevices,
                            virtualConnections: _virtualConnections,
                            offset: canvasOffset,
                            connectingFrom: _connectingFromDeviceId != null
                                ? _positions[_connectingFromDeviceId]
                                : null,
                            connectingFromVirtual:
                                _connectingFromVirtualId != null
                                ? _virtualDevices.firstWhere(
                                    (v) => v.id == _connectingFromVirtualId,
                                    orElse: () => VirtualDevice(
                                      id: '',
                                      type: VirtualDeviceType.pc,
                                      name: '',
                                      x: 0,
                                      y: 0,
                                    ),
                                  )
                                : null,
                            connectingMousePosition: _connectingMousePosition,
                          ),
                          child: Stack(
                            children: [
                              // Device nodes
                              ...devices.map((device) {
                                final pos = _positions[device.id];
                                if (pos == null) return const SizedBox.shrink();
                                final deviceId = device.id;
                                return Positioned(
                                  left: pos.x + canvasOffset,
                                  top: pos.y + canvasOffset,
                                  child: _TopologyDeviceNode(
                                    device: device,
                                    isConnecting:
                                        _connectingFromDeviceId == device.id,
                                    isTargetMode:
                                        (_connectingFromDeviceId != null &&
                                            _connectingFromDeviceId !=
                                                device.id) ||
                                        _connectingFromVirtualId != null,
                                    isVirtualConnecting:
                                        _connectingFromVirtualId != null,
                                    connections: _connections,
                                    virtualConnections: _virtualConnections,
                                    onStartConnection: _startConnection,
                                    onCompleteConnection: (deviceId, port) {
                                      if (_connectingFromVirtualId != null) {
                                        _completeVirtualConnection(
                                          deviceId,
                                          port,
                                        );
                                      } else {
                                        _completeConnection(deviceId, port);
                                      }
                                    },
                                    onDragStart: (globalPosition) {
                                      _draggingDeviceId = deviceId;
                                      _lastDragPosition = globalPosition;
                                    },
                                    onDragUpdate: (globalPosition) {
                                      if (_draggingDeviceId == deviceId &&
                                          _lastDragPosition != null) {
                                        // Compute delta in screen space
                                        final screenDelta =
                                            globalPosition - _lastDragPosition!;
                                        _lastDragPosition = globalPosition;

                                        // Get current position (not captured pos)
                                        final currentPos = _positions[deviceId];
                                        if (currentPos == null) return;

                                        // Convert to canvas space by dividing by scale
                                        final scale = _transformController.value
                                            .getMaxScaleOnAxis();
                                        final canvasDelta = screenDelta / scale;

                                        setState(() {
                                          _positions[deviceId] = currentPos
                                              .copyWith(
                                                x:
                                                    currentPos.x +
                                                    canvasDelta.dx,
                                                y:
                                                    currentPos.y +
                                                    canvasDelta.dy,
                                              );
                                        });
                                      }
                                    },
                                    onDragEnd: () {
                                      _draggingDeviceId = null;
                                      _lastDragPosition = null;
                                      _saveTopology();
                                    },
                                    onDelete: () =>
                                        _deleteDeviceFromTopology(device.id),
                                  ),
                                );
                              }),
                              // Virtual device nodes
                              ..._virtualDevices.map((virtualDevice) {
                                return Positioned(
                                  left: virtualDevice.x + canvasOffset,
                                  top: virtualDevice.y + canvasOffset,
                                  child: _VirtualDeviceNode(
                                    device: virtualDevice,
                                    isConnecting:
                                        _connectingFromVirtualId ==
                                        virtualDevice.id,
                                    isTargetMode:
                                        _connectingFromVirtualId != null &&
                                        _connectingFromVirtualId !=
                                            virtualDevice.id,
                                    onDragStart: (globalPosition) {
                                      _draggingVirtualId = virtualDevice.id;
                                      _lastDragPosition = globalPosition;
                                    },
                                    onDragUpdate: (globalPosition) {
                                      if (_draggingVirtualId ==
                                              virtualDevice.id &&
                                          _lastDragPosition != null) {
                                        final screenDelta =
                                            globalPosition - _lastDragPosition!;
                                        _lastDragPosition = globalPosition;

                                        final scale = _transformController.value
                                            .getMaxScaleOnAxis();
                                        final canvasDelta = screenDelta / scale;

                                        setState(() {
                                          final index = _virtualDevices
                                              .indexWhere(
                                                (v) => v.id == virtualDevice.id,
                                              );
                                          if (index != -1) {
                                            _virtualDevices[index] =
                                                _virtualDevices[index].copyWith(
                                                  x:
                                                      _virtualDevices[index].x +
                                                      canvasDelta.dx,
                                                  y:
                                                      _virtualDevices[index].y +
                                                      canvasDelta.dy,
                                                );
                                          }
                                        });
                                      }
                                    },
                                    onDragEnd: () {
                                      _draggingVirtualId = null;
                                      _lastDragPosition = null;
                                      _saveTopology();
                                    },
                                    onDelete: () =>
                                        _deleteVirtualDevice(virtualDevice.id),
                                    onEdit: () =>
                                        _editVirtualDevice(virtualDevice),
                                    onConnect: () => _startVirtualConnection(
                                      virtualDevice.id,
                                    ),
                                    onCompleteConnection: _completeConnection,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Connection list / port details on the right
          SizedBox(
            width: 280,
            child: FluentWidgets.mica(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Connections',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: _connections.isEmpty
                        ? Center(
                            child: Text(
                              'No connections yet.\nRight-click a port to start connecting.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[100]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _connections.length,
                            itemBuilder: (context, index) {
                              final conn = _connections[index];
                              final sourceDevice = devices.firstWhere(
                                (d) => d.id == conn.sourceDeviceId,
                                orElse: () => devices.first,
                              );
                              final targetDevice = devices.firstWhere(
                                (d) => d.id == conn.targetDeviceId,
                                orElse: () => devices.first,
                              );

                              // Check if this is a permanent connection
                              final isPermanent =
                                  sourceDevice.realId != null &&
                                  targetDevice.realId != null; /* &&
                                  isPermanentConnection(
                                    sourceRealId: sourceDevice.realId!,
                                    sourcePort: conn.sourcePort,
                                    targetRealId: targetDevice.realId!,
                                    targetPort: conn.targetPort,
                                  );*/

                              return Card(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${sourceDevice.hostname}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _shortPortName(conn.sourcePort),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[100],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isPermanent)
                                      Tooltip(
                                        message:
                                            'Permanent management connection',
                                        child: Icon(
                                          FluentIcons.lock,
                                          size: 12,
                                          color: Colors.grey[100],
                                        ),
                                      )
                                    else
                                      const Icon(FluentIcons.forward, size: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${targetDevice.hostname}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            _shortPortName(conn.targetPort),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[100],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isPermanent)
                                      Tooltip(
                                        message:
                                            'Cannot remove permanent connection',
                                        child: Icon(
                                          FluentIcons.delete,
                                          size: 14,
                                          color: Colors.grey[80],
                                        ),
                                      )
                                    else
                                      IconButton(
                                        icon: const Icon(
                                          FluentIcons.delete,
                                          size: 14,
                                        ),
                                        onPressed: () =>
                                            _removeConnection(conn),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing a preset type with available slots that can be added
class _PresetGroupCard extends StatelessWidget {
  const _PresetGroupCard({
    required this.preset,
    required this.availableCount,
    required this.onPressed,
  });

  final DevicePreset preset;
  final int availableCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final interfaces = preset.defaultInterfaces();
    final interfaceSummary = generatePortRangeSummary(interfaces);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverButton(
        onPressed: onPressed,
        builder: (context, states) {
          return Card(
            padding: const EdgeInsets.all(10),
            backgroundColor: states.isHovered
                ? FluentTheme.of(context).accentColor.withValues(alpha: .1)
                : null,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        preset.color?.withValues(alpha: .2) ?? Colors.grey[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    preset.category == NetDeviceCategory.Switch
                        ? FluentIcons.switch_widget
                        : FluentIcons.branch_fork2,
                    size: 20,
                    color: preset.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.sku,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        interfaceSummary,
                        style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$availableCount available',
                        style: TextStyle(fontSize: 10, color: Colors.grey[120]),
                      ),
                    ],
                  ),
                ),
                const Icon(FluentIcons.add, size: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Converts port names to short format
/// e.g., "FastEthernet 0/1" -> "Fa0/1", "GigabitEthernet 0/1" -> "Gi0/1"
String _shortPortName(String name) {
  return name
      .replaceAll('FastEthernet ', 'Fa')
      .replaceAll('GigabitEthernet ', 'Gi')
      .replaceAll('TenGigabitEthernet ', 'Te')
      .replaceAll('Ethernet ', 'Eth')
      .replaceAll('Serial ', 'Se')
      .replaceAll('Loopback ', 'Lo')
      .replaceAll('Vlan ', 'Vlan');
}

/// Generates a short port range string from a list of ports
/// e.g., [Fa0/1, Fa0/2, Fa0/3, Gi0/1, Gi0/2] -> "Fa0/1-3, Gi0/1-2"
String generatePortRangeSummary(List<Port> ports) {
  if (ports.isEmpty) return 'No ports';

  // Group ports by prefix (e.g., "FastEthernet 0/")
  final groups = <String, List<int>>{};

  for (final port in ports) {
    final match = RegExp(r'^(.+?)(\d+)$').firstMatch(port.name);
    if (match != null) {
      final prefix = match.group(1)!;
      final number = int.parse(match.group(2)!);
      groups.putIfAbsent(prefix, () => []).add(number);
    }
  }

  // Sort each group and create range strings
  final result = <String>[];
  for (final entry in groups.entries) {
    final prefix = _shortPortName(entry.key);
    final numbers = entry.value..sort();

    // Find consecutive ranges
    final ranges = <String>[];
    int rangeStart = numbers[0];
    int rangeEnd = numbers[0];

    for (int i = 1; i < numbers.length; i++) {
      if (numbers[i] == rangeEnd + 1) {
        rangeEnd = numbers[i];
      } else {
        ranges.add(
          rangeStart == rangeEnd
              ? '$prefix$rangeStart'
              : '$prefix$rangeStart-$rangeEnd',
        );
        rangeStart = numbers[i];
        rangeEnd = numbers[i];
      }
    }
    ranges.add(
      rangeStart == rangeEnd
          ? '$prefix$rangeStart'
          : '$prefix$rangeStart-$rangeEnd',
    );

    result.addAll(ranges);
  }

  return result.join(', ');
}

/// A device node on the topology canvas
class _TopologyDeviceNode extends StatefulWidget {
  const _TopologyDeviceNode({
    required this.device,
    required this.isConnecting,
    required this.isTargetMode,
    this.isVirtualConnecting = false,
    required this.connections,
    this.virtualConnections = const [],
    required this.onStartConnection,
    required this.onCompleteConnection,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDelete,
  });

  final NetDevice device;
  final bool isConnecting;
  final bool isTargetMode; // True when another device started connecting
  final bool
  isVirtualConnecting; // True when a virtual device started connecting
  final List<TopologyConnection> connections;
  final List<VirtualConnection> virtualConnections;
  final void Function(int deviceId, String port) onStartConnection;
  final void Function(int deviceId, String port) onCompleteConnection;
  final void Function(Offset globalPosition) onDragStart;
  final void Function(Offset globalPosition) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDelete;

  @override
  State<_TopologyDeviceNode> createState() => _TopologyDeviceNodeState();
}

class _TopologyDeviceNodeState extends State<_TopologyDeviceNode> {
  final _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  /// Get ports that are already connected for this device
  Set<String> get _connectedPorts {
    final connected = <String>{};
    for (final conn in widget.connections) {
      if (conn.sourceDeviceId == widget.device.id) {
        connected.add(conn.sourcePort);
      }
      if (conn.targetDeviceId == widget.device.id) {
        connected.add(conn.targetPort);
      }
    }
    // Also check virtual connections
    for (final vConn in widget.virtualConnections) {
      if (vConn.realDeviceId == widget.device.id) {
        connected.add(vConn.realDevicePort);
      }
    }
    return connected;
  }

  @override
  Widget build(BuildContext context) {
    final connectedPorts = _connectedPorts;

    return GestureDetector(
      onPanStart: (details) => widget.onDragStart(details.globalPosition),
      onPanUpdate: (details) => widget.onDragUpdate(details.globalPosition),
      onPanEnd: (_) => widget.onDragEnd(),
      child: FlyoutTarget(
        controller: _flyoutController,
        child: Card(
          padding: EdgeInsets.zero,
          backgroundColor: widget.isTargetMode
              ? Colors.orange.withValues(alpha: .1)
              : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 140),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isTargetMode
                        ? Colors.orange.withValues(alpha: .3)
                        : widget.device.color?.withValues(alpha: .3) ??
                              FluentTheme.of(
                                context,
                              ).accentColor.withValues(alpha: .3),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.device.category == NetDeviceCategory.Switch
                            ? FluentIcons.switch_widget
                            : FluentIcons.branch_fork2,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.device.hostname,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Icon(
                          FluentIcons.delete,
                          size: 14,
                          color: Colors.red.lightest,
                        ),
                      ),
                    ],
                  ),
                ),
                // Body with port info
                Container(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.device.name,
                        style: TextStyle(fontSize: 10, color: Colors.grey[100]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        generatePortRangeSummary(widget.device.interfaces),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey[120],
                          fontFamily: 'Consolas',
                        ),
                      ),
                      if (connectedPorts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Connected: ${connectedPorts.map(_shortPortName).join(", ")}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.blue,
                            fontFamily: 'Consolas',
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Connect button or target button
                      if (widget.isTargetMode)
                        FilledButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              Colors.orange,
                            ),
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                          onPressed: () {
                            _flyoutController.showFlyout(
                              barrierDismissible: true,
                              dismissOnPointerMoveAway: false,
                              builder: (flyoutCtx) {
                                return _PortSelectionFlyout(
                                  device: widget.device,
                                  connectedPorts: connectedPorts,
                                  title: 'Connect To',
                                  onPortSelected: (port) {
                                    Flyout.maybeOf(flyoutCtx)?.close();
                                    widget.onCompleteConnection(
                                      widget.device.id,
                                      port,
                                    );
                                  },
                                );
                              },
                            );
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.plug_connected, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Connect Here',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        )
                      else
                        Button(
                          style: ButtonStyle(
                            padding: WidgetStateProperty.all(
                              const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                          onPressed: () {
                            _flyoutController.showFlyout(
                              barrierDismissible: true,
                              dismissOnPointerMoveAway: false,
                              builder: (flyoutCtx) {
                                return _PortSelectionFlyout(
                                  device: widget.device,
                                  connectedPorts: connectedPorts,
                                  title: 'Select Source Port',
                                  onPortSelected: (port) {
                                    Flyout.maybeOf(flyoutCtx)?.close();
                                    widget.onStartConnection(
                                      widget.device.id,
                                      port,
                                    );
                                  },
                                );
                              },
                            );
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.plug_connected, size: 12),
                              SizedBox(width: 4),
                              Text('Connect', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Flyout for selecting a port to connect
class _PortSelectionFlyout extends StatelessWidget {
  const _PortSelectionFlyout({
    required this.device,
    required this.connectedPorts,
    required this.title,
    required this.onPortSelected,
  });

  final NetDevice device;
  final Set<String> connectedPorts;
  final String title;
  final void Function(String port) onPortSelected;

  @override
  Widget build(BuildContext context) {
    final ports = device.interfaces;
    final realId = device.realId;
    final preset = device.preset;

    return Container(
      constraints: const BoxConstraints(maxHeight: 350, maxWidth: 220),
      child: Card(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              device.hostname,
              style: TextStyle(fontSize: 11, color: Colors.grey[100]),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ports.length,
                itemBuilder: (context, index) {
                  final port = ports[index];
                  final isConnected = connectedPorts.contains(port.name);
                  final isSystemReserved = isPortReserved(
                    port.name,
                    realId: realId,
                  );
                  final systemReason = isSystemReserved
                      ? getPortReservationReason(port.name, realId: realId)
                      : null;
                  final isPresetLocked = preset.isInterfaceLocked(port.name);
                  final presetReason = isPresetLocked
                      ? preset.lockedInterfaceReason
                      : null;
                  final isLocked = isSystemReserved || isPresetLocked;
                  final lockReason = systemReason ?? presetReason;
                  final isDisabled = isConnected || isLocked;

                  return Tooltip(
                    message: isLocked
                        ? 'Locked: ${lockReason ?? "Unavailable"}'
                        : '',
                    child: HoverButton(
                      onPressed: isDisabled
                          ? null
                          : () => onPortSelected(port.name),
                      builder: (context, states) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: states.isHovered && !isDisabled
                                ? Colors.blue.withValues(alpha: .1)
                                : isLocked
                                ? Colors.red.withValues(alpha: .05)
                                : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isLocked
                                      ? Colors.red
                                      : isConnected
                                      ? Colors.blue
                                      : port.enabled
                                      ? Colors.green
                                      : Colors.grey[80],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _shortPortName(port.name),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Consolas',
                                    color: isDisabled ? Colors.grey[100] : null,
                                  ),
                                ),
                              ),
                              if (isLocked)
                                Icon(
                                  FluentIcons.lock,
                                  size: 12,
                                  color: Colors.red,
                                )
                              else if (isConnected)
                                Text(
                                  'in use',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[100],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints an infinite grid background that extends in all directions
class _InfiniteGridPainter extends CustomPainter {
  _InfiniteGridPainter({required this.viewport, required this.transform});

  final Quad viewport;
  final Matrix4 transform;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[30].withValues(alpha: 0.15)
      ..strokeWidth = 0.5;

    const spacing = 50.0;

    // Calculate visible area bounds from viewport
    final minX = [
      viewport.point0.x,
      viewport.point1.x,
      viewport.point2.x,
      viewport.point3.x,
    ].reduce((a, b) => a < b ? a : b);
    final maxX = [
      viewport.point0.x,
      viewport.point1.x,
      viewport.point2.x,
      viewport.point3.x,
    ].reduce((a, b) => a > b ? a : b);
    final minY = [
      viewport.point0.y,
      viewport.point1.y,
      viewport.point2.y,
      viewport.point3.y,
    ].reduce((a, b) => a < b ? a : b);
    final maxY = [
      viewport.point0.y,
      viewport.point1.y,
      viewport.point2.y,
      viewport.point3.y,
    ].reduce((a, b) => a > b ? a : b);

    // Extend bounds slightly for smooth scrolling
    final startX = (minX / spacing).floor() * spacing - spacing;
    final endX = (maxX / spacing).ceil() * spacing + spacing;
    final startY = (minY / spacing).floor() * spacing - spacing;
    final endY = (maxY / spacing).ceil() * spacing + spacing;

    // Draw vertical lines
    for (double x = startX; x <= endX; x += spacing) {
      canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
    }

    // Draw horizontal lines
    for (double y = startY; y <= endY; y += spacing) {
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _InfiniteGridPainter oldDelegate) {
    return viewport != oldDelegate.viewport;
  }
}

/// Paints connections between devices
class _ConnectionsPainter extends CustomPainter {
  _ConnectionsPainter({
    required this.connections,
    required this.positions,
    required this.virtualDevices,
    required this.virtualConnections,
    this.offset = 0,
    this.connectingFrom,
    this.connectingFromVirtual,
    this.connectingMousePosition,
  });

  final List<TopologyConnection> connections;
  final Map<int, TopologyPosition> positions;
  final List<VirtualDevice> virtualDevices;
  final List<VirtualConnection> virtualConnections;
  final double offset;
  final TopologyPosition? connectingFrom;
  final VirtualDevice? connectingFromVirtual;
  final Offset? connectingMousePosition;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Count connections between each pair of devices to calculate offsets
    final connectionCounts = <String, int>{};
    final connectionIndices = <TopologyConnection, int>{};

    for (final conn in connections) {
      // Create a consistent key regardless of direction
      final key = conn.sourceDeviceId < conn.targetDeviceId
          ? '${conn.sourceDeviceId}-${conn.targetDeviceId}'
          : '${conn.targetDeviceId}-${conn.sourceDeviceId}';
      final currentIndex = connectionCounts[key] ?? 0;
      connectionIndices[conn] = currentIndex;
      connectionCounts[key] = currentIndex + 1;
    }

    // Draw existing connections
    for (final conn in connections) {
      final sourcePos = positions[conn.sourceDeviceId];
      final targetPos = positions[conn.targetDeviceId];

      if (sourcePos != null && targetPos != null) {
        // Get the index and total count for this device pair
        final key = conn.sourceDeviceId < conn.targetDeviceId
            ? '${conn.sourceDeviceId}-${conn.targetDeviceId}'
            : '${conn.targetDeviceId}-${conn.sourceDeviceId}';
        final index = connectionIndices[conn] ?? 0;
        final total = connectionCounts[key] ?? 1;

        // Calculate base positions (center of devices)
        final baseStart = Offset(
          sourcePos.x + offset + 70,
          sourcePos.y + offset + 50,
        );
        final baseEnd = Offset(
          targetPos.x + offset + 70,
          targetPos.y + offset + 50,
        );

        // Calculate perpendicular offset for multiple cables
        final dx = baseEnd.dx - baseStart.dx;
        final dy = baseEnd.dy - baseStart.dy;
        final length = math.sqrt(dx * dx + dy * dy);

        // Perpendicular unit vector (rotated 90 degrees)
        final perpX = length > 0 ? -dy / length : 0.0;
        final perpY = length > 0 ? dx / length : 1.0;

        // Calculate offset amount (spread cables perpendicular to the line)
        final cableOffset = total > 1 ? (index - (total - 1) / 2) * 12.0 : 0.0;
        final offsetX = perpX * cableOffset;
        final offsetY = perpY * cableOffset;

        final start = Offset(baseStart.dx + offsetX, baseStart.dy + offsetY);
        final end = Offset(baseEnd.dx + offsetX, baseEnd.dy + offsetY);

        // Draw curved line
        final path = Path();
        path.moveTo(start.dx, start.dy);

        // Control point for smooth curve (offset perpendicular to maintain spacing)
        final midX = (start.dx + end.dx) / 2;
        final midY = (start.dy + end.dy) / 2;
        final curveAmount = 30.0 + cableOffset.abs() * 0.3;

        final controlPoint = Offset(
          midX + perpX * curveAmount,
          midY + perpY * curveAmount,
        );

        path.quadraticBezierTo(
          controlPoint.dx,
          controlPoint.dy,
          end.dx,
          end.dy,
        );

        canvas.drawPath(path, paint);

        // Draw connection dots
        final dotPaint = Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.fill;
        canvas.drawCircle(start, 4, dotPaint);
        canvas.drawCircle(end, 4, dotPaint);
      }
    }

    // Draw virtual device connections
    final virtualPaint = Paint()
      ..color = Colors.teal
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final vConn in virtualConnections) {
      final virtualDevice = virtualDevices.firstWhere(
        (v) => v.id == vConn.virtualDeviceId,
        orElse: () => VirtualDevice(
          id: '',
          type: VirtualDeviceType.pc,
          name: '',
          x: 0,
          y: 0,
        ),
      );
      final realPos = positions[vConn.realDeviceId];

      if (virtualDevice.id.isNotEmpty && realPos != null) {
        // Virtual device center (smaller nodes)
        final virtualStart = Offset(
          virtualDevice.x + offset + 50,
          virtualDevice.y + offset + 40,
        );
        // Real device center
        final realEnd = Offset(
          realPos.x + offset + 70,
          realPos.y + offset + 50,
        );

        // Draw curved line
        final path = Path();
        path.moveTo(virtualStart.dx, virtualStart.dy);

        final midX = (virtualStart.dx + realEnd.dx) / 2;
        final midY = (virtualStart.dy + realEnd.dy) / 2;
        final dx = realEnd.dx - virtualStart.dx;
        final dy = realEnd.dy - virtualStart.dy;
        final length = math.sqrt(dx * dx + dy * dy);
        final perpX = length > 0 ? -dy / length : 0.0;
        final perpY = length > 0 ? dx / length : 1.0;

        final controlPoint = Offset(midX + perpX * 30, midY + perpY * 30);

        path.quadraticBezierTo(
          controlPoint.dx,
          controlPoint.dy,
          realEnd.dx,
          realEnd.dy,
        );

        canvas.drawPath(path, virtualPaint);

        // Draw dots
        final dotPaint = Paint()
          ..color = Colors.teal
          ..style = PaintingStyle.fill;
        canvas.drawCircle(virtualStart, 4, dotPaint);
        canvas.drawCircle(realEnd, 4, dotPaint);
      }
    }

    // Draw line while connecting from real device
    if (connectingFrom != null && connectingMousePosition != null) {
      final pendingPaint = Paint()
        ..color = Colors.orange
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final start = Offset(
        connectingFrom!.x + offset + 70,
        connectingFrom!.y + offset + 50,
      );

      // Draw dashed line
      _drawDashedLine(canvas, start, connectingMousePosition!, pendingPaint);
    }

    // Draw line while connecting from virtual device
    if (connectingFromVirtual != null && connectingMousePosition != null) {
      final pendingPaint = Paint()
        ..color = Colors.orange
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final start = Offset(
        connectingFromVirtual!.x + offset + 50,
        connectingFromVirtual!.y + offset + 40,
      );

      _drawDashedLine(canvas, start, connectingMousePosition!, pendingPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 8.0;
    const gapLength = 4.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final unitX = dx / distance;
    final unitY = dy / distance;

    double currentDistance = 0;
    while (currentDistance < distance) {
      final dashEnd = math.min(currentDistance + dashLength, distance);
      canvas.drawLine(
        Offset(
          start.dx + unitX * currentDistance,
          start.dy + unitY * currentDistance,
        ),
        Offset(start.dx + unitX * dashEnd, start.dy + unitY * dashEnd),
        paint,
      );
      currentDistance = dashEnd + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionsPainter oldDelegate) {
    return connections != oldDelegate.connections ||
        positions != oldDelegate.positions ||
        virtualDevices != oldDelegate.virtualDevices ||
        virtualConnections != oldDelegate.virtualConnections ||
        connectingFrom != oldDelegate.connectingFrom ||
        connectingFromVirtual != oldDelegate.connectingFromVirtual ||
        connectingMousePosition != oldDelegate.connectingMousePosition;
  }
}

/// Button for adding virtual devices
class _VirtualDeviceButton extends StatelessWidget {
  const _VirtualDeviceButton({
    required this.type,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final VirtualDeviceType type;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: states.isHovered
                ? FluentTheme.of(context).accentColor.withValues(alpha: .15)
                : FluentTheme.of(context).resources.controlFillColorDefault,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: states.isHovered
                  ? FluentTheme.of(context).accentColor
                  : FluentTheme.of(context).resources.controlStrokeColorDefault,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

/// Virtual device node on the topology canvas
class _VirtualDeviceNode extends StatelessWidget {
  const _VirtualDeviceNode({
    required this.device,
    required this.isConnecting,
    required this.isTargetMode,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDelete,
    required this.onEdit,
    required this.onConnect,
    required this.onCompleteConnection,
  });

  final VirtualDevice device;
  final bool isConnecting;
  final bool isTargetMode;
  final void Function(Offset globalPosition) onDragStart;
  final void Function(Offset globalPosition) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onConnect;
  final void Function(int deviceId, String port) onCompleteConnection;

  IconData get _icon => switch (device.type) {
    VirtualDeviceType.pc => FluentIcons.desktop_flow,
    VirtualDeviceType.server => FluentIcons.server,
    VirtualDeviceType.cloud => FluentIcons.cloud,
    VirtualDeviceType.phone => FluentIcons.cell_phone,
  };

  Color get _color => switch (device.type) {
    VirtualDeviceType.pc => Colors.teal,
    VirtualDeviceType.server => Colors.purple,
    VirtualDeviceType.cloud => Colors.blue,
    VirtualDeviceType.phone => Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => onDragStart(details.globalPosition),
      onPanUpdate: (details) => onDragUpdate(details.globalPosition),
      onPanEnd: (_) => onDragEnd(),
      child: Card(
        padding: EdgeInsets.zero,
        backgroundColor: isTargetMode
            ? Colors.orange.withValues(alpha: .1)
            : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isTargetMode
                      ? Colors.orange.withValues(alpha: .3)
                      : _color.withValues(alpha: .3),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onEdit,
                      child: Icon(
                        FluentIcons.edit,
                        size: 12,
                        color: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(
                        FluentIcons.delete,
                        size: 12,
                        color: Colors.red.lightest,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (device.ipAddress != null)
                      Text(
                        device.ipAddress!,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Consolas',
                          color: Colors.grey[100],
                        ),
                      )
                    else
                      Text(
                        'No IP',
                        style: TextStyle(fontSize: 10, color: Colors.grey[120]),
                      ),
                    const SizedBox(height: 6),
                    if (isTargetMode)
                      Text(
                        'Select port on device',
                        style: TextStyle(fontSize: 9, color: Colors.orange),
                      )
                    else
                      Button(
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                          ),
                        ),
                        onPressed: onConnect,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.plug_connected, size: 10),
                            SizedBox(width: 4),
                            Text('Connect', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
