import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/window.dart';
import 'package:flutter_acrylic/window_effect.dart';

import 'package:ktracer_center/ai_chat/ai_chat_state.dart';
import 'package:ktracer_center/ai_chat/widgets/ai_chat_panel.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/devices/device_preset.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/pages/settings_page.dart';
import 'package:ktracer_center/widgets/device_details/device_details.dart';
import 'package:ktracer_center/pages/home_page.dart';
import 'package:ktracer_center/pages/network_services_page.dart';
import 'package:ktracer_center/pages/topology_page.dart';
import 'package:ktracer_center/widgets/title_bar_content.dart';
import 'package:strworks/app_runtime_config.dart';
import 'package:strworks/strworks.dart';
import 'package:provider/provider.dart';
import 'package:strworks/widgets/fluent/fluent_page_data.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await StrworksAppRuntimeConfig.load();
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hwhwupvotfuanhxvocgn.supabase.co',
    anonKey: 'sb_publishable_1oSBJ6_I0u2h4eoBCVJI4Q_mAkb1TZf',
  );

  await Window.initialize();

  doWhenWindowReady(() {
    appWindow.show();
  });
  await Window.setEffect(effect: WindowEffect.mica, dark: true);
  await Window.hideWindowControls();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider(
          create: (context) => Strworks(
            StrworksAppRelationship(
              currentApp: StrworksAppDefinition(
                appId: "ktracer_center",
                displayName: "KTracer Center",
                githubRepo: "ktracer_center",
              ),
            ),
          ),
        ),
        ChangeNotifierProxyProvider<AppState, AiChatState>(
          create: (context) => AiChatState(context.read<AppState>()),
          update: (context, appState, previous) =>
              previous ?? AiChatState(appState),
        ),
      ],
      child: MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late Future<void> _initFuture;
  late final FluentNavigationController _navController;

  /// Index of the "Devices" entry in the primary items list (0-based).
  static const int _devicesModuleIndex = 3;

  @override
  void initState() {
    super.initState();
    _navController = FluentNavigationController();
    final appState = context.read<AppState>();
    final strworks = context.read<Strworks>();
    _initFuture = _initialize(appState, strworks);
    // Listen for navigation requests that originate from non-navigation code
    // (e.g. tapping a device card on the Project page).
    appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    context.read<AppState>().removeListener(_onAppStateChanged);
    _navController.dispose();
    super.dispose();
  }

  void _onAppStateChanged() {
    final appState = context.read<AppState>();

    if (appState.pendingNavigateToHome) {
      _navController.setModuleIndex(0);
      appState.consumeNavigation();
      return;
    }

    final deviceId = appState.pendingNavigateDeviceId;
    if (deviceId != null) {
      final pageIdx = appState.sortedDevices.indexWhere(
        (d) => d.id == deviceId,
      );
      if (pageIdx >= 0) {
        _navController.setModuleIndex(_devicesModuleIndex, notify: false);
        _navController.setPageIndex(_devicesModuleIndex, 0, pageIdx);
      }
      appState.consumeNavigation();
    }
  }

  Future<void> _initialize(AppState appState, Strworks strworks) async {
    await appState.init();
    await strworks.init();
  }

  Widget _buildAddDeviceDropdown(BuildContext context) {
    final appState = context.watch<AppState>();
    final controller = FlyoutController();
    final availableByCategory = appState.availablePresetsByCategory;

    if (availableByCategory.isEmpty) {
      return IconButton(
        icon: const Icon(FluentIcons.add, size: 12),
        onPressed: null, // Disabled when no devices available
      );
    }

    return FlyoutTarget(
      controller: controller,
      child: IconButton(
        icon: const Icon(FluentIcons.add, size: 12),
        onPressed: () {
          controller.showFlyout(
            barrierDismissible: true,
            dismissOnPointerMoveAway: true,
            placementMode: FlyoutPlacementMode.bottomCenter,
            barrierColor: Colors.transparent,
            builder: (flyoutCtx) {
              return MenuFlyout(
                items: availableByCategory.entries
                    .map(
                      (category) => MenuFlyoutSubItem(
                        text: Text(category.key),
                        items: (flyoutContext) => category.value.map((preset) {
                          final remaining = appState.getAvailableSlots(
                            preset.id,
                          );
                          return MenuFlyoutItem(
                            leading: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: preset.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            text: Text('${preset.name} ($remaining left)'),
                            onPressed: () async {
                              await appState.addDevice(preset.id);
                              if (flyoutContext.mounted) {
                                Flyout.maybeOf(flyoutContext)?.close();
                              }
                            },
                          );
                        }).toList(),
                      ),
                    )
                    .toList(),
              );
            },
          );
        },
      ),
    );
  }

  /// Build a single device navigation item
  FluentPageData _buildDevicePageData(NetDevice device, AppState appState) {
    return FluentPageData(
      title: device.hostname,
      hideBackground: true,
      icon: device.category == NetDeviceCategory.Switch
          ? FluentIcons.switch_widget
          : FluentIcons.branch_fork2,
      trailing: FluentWidgets.chip(text: device.sku, color: device.color),
      child: DeviceDetails(device: device),
      onSecondaryTap: (context, position) {
        _showDeviceContextMenu(context, position, device, appState);
      },
    );
  }

  void _showDeviceContextMenu(
    BuildContext context,
    Offset globalPosition,
    NetDevice device,
    AppState appState,
  ) {
    final position = appState.getDevicePositionInGroup(device.id);
    final total = appState.getDeviceCountInGroup(device.deviceGroup);

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: globalPosition.dx,
            top: globalPosition.dy,
            child: FlyoutContent(
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HoverButton(
                      onPressed: position > 1
                          ? () {
                              Navigator.of(context).pop();
                              appState.moveDeviceUp(device.id);
                            }
                          : null,
                      builder: (context, states) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: states.isHovered
                              ? Colors.white.withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FluentIcons.chevron_up,
                              size: 14,
                              color: position > 1 ? null : Colors.grey[100],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Move Up',
                              style: TextStyle(
                                color: position > 1 ? null : Colors.grey[100],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    HoverButton(
                      onPressed: position < total
                          ? () {
                              Navigator.of(context).pop();
                              appState.moveDeviceDown(device.id);
                            }
                          : null,
                      builder: (context, states) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: states.isHovered
                              ? Colors.white.withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FluentIcons.chevron_down,
                              size: 14,
                              color: position < total ? null : Colors.grey[100],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Move Down',
                              style: TextStyle(
                                color: position < total
                                    ? null
                                    : Colors.grey[100],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build device navigation items grouped by device group
  /// Devices are sorted by group name first, then by sort order, then by hostname
  List<FluentPageData> _buildDeviceNavigationItems(AppState appState) {
    final devicesByGroup = appState.devicesByGroup;
    final items = <FluentPageData>[];

    // Sort devices within each group by sortOrder, then hostname
    List<NetDevice> sortDevices(List<NetDevice> devices) {
      return devices.toList()..sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) return orderCompare;
        return a.hostname.compareTo(b.hostname);
      });
    }

    // First, add ungrouped devices (devices with no group)
    final ungroupedDevices = sortDevices(devicesByGroup[null] ?? []);
    for (final device in ungroupedDevices) {
      items.add(_buildDevicePageData(device, appState));
    }

    // Then add grouped devices with headers
    final sortedGroups =
        devicesByGroup.keys.where((g) => g != null).cast<String>().toList()
          ..sort();

    for (int i = 0; i < sortedGroups.length; i++) {
      final groupName = sortedGroups[i];
      final groupDevices = sortDevices(devicesByGroup[groupName]!);

      // Add a separator before each group (acts as visual divider)
      items.add(FluentPageData.separator);

      // Add a header item showing the group name
      items.add(FluentPageData.header(groupName, icon: FluentIcons.folder));

      for (final device in groupDevices) {
        items.add(_buildDevicePageData(device, appState));
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final chatState = context.watch<AiChatState>();

    return FluentApp(
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        navigationPaneTheme: NavigationPaneThemeData(
          backgroundColor: Colors.transparent,
        ),
      ),

      home: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: ProgressRing());
          }

          // Show update dialog if an update is available
          context.read<Strworks>().showUpdateDialogIfAvailable(context);

          return Stack(
            children: [
              Column(
                children: [
                  // Title bar - always full width
                  FluentWidgets.titleBar(
                    title: "KTracer Center",
                    content: TitleBarContent(
                      menus: appState.projects.map((e) => e.name).toList(),
                      selectedMenu: appState.selectedProject?.name,
                      onMenuChanged: (v) {
                        final project = appState.projects
                            .where((p) => p.name == v)
                            .firstOrNull;
                        if (project != null) {
                          context.read<AppState>().selectProject(project);
                        }
                      },
                    ),
                  ),
                  // Main content row with navigation and chat panel
                  Expanded(
                    child: Row(
                      children: [
                        // Main content area
                        Expanded(
                          child: FluentWidgets.navigationApp(
                            controller: _navController,
                            orientation: FluentNavigationOrientation.vertical,
                            items: [
                              FluentPageData(
                                child: HomePage(),
                                title: "Project",
                                icon: FluentIcons.fabric_folder,
                              ),
                              FluentPageData(
                                child: TopologyPage(),
                                title: "Topology",
                                icon: FluentIcons.org,
                              ),
                              FluentPageData(
                                child: NetworkServicesPage(),
                                hideBackground: true,
                                title: "Network Services",
                                icon: FluentIcons.server_enviroment,
                              ),
                              FluentPageData(
                                children: _buildDeviceNavigationItems(appState),
                                headerActionBuilder: _buildAddDeviceDropdown,
                                isAction: true,
                                title: "Devices",
                                icon: FluentIcons.virtual_network,
                              ),
                            ],
                            footerItems: [
                              FluentPageData.separator,
                              FluentPageData(
                                child: SettingsPage(),
                                title: "Settings",
                                icon: FluentIcons.settings,
                              ),
                            ],
                          ),
                        ),
                        // AI Chat panel (slides in from right)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          width: chatState.isOpen ? 420 : 0,
                          child: chatState.isOpen
                              ? const AiChatPanel()
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Supabase unavailable overlay
              if (!appState.isSupabaseConnected)
                _buildLockedOverlay(context, appState),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLockedOverlay(BuildContext context, AppState appState) {
    final isConnecting = appState.supabaseStatus == ConnectionStatus.connecting;

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnecting
                      ? FluentIcons.sync_folder
                      : FluentIcons.plug_disconnected,
                  size: 48,
                  color: isConnecting ? Colors.orange : Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  isConnecting
                      ? 'Connecting to Database...'
                      : 'Database Unavailable',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
                const SizedBox(height: 8),
                Text(
                  isConnecting
                      ? 'Please wait while we establish a connection.'
                      : 'Unable to connect to the database. The app cannot function without it.',
                  style: FluentTheme.of(context).typography.body,
                  textAlign: TextAlign.center,
                ),
                if (appState.supabaseError != null) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Text(
                      appState.supabaseError!,
                      style: FluentTheme.of(
                        context,
                      ).typography.caption?.copyWith(color: Colors.grey[100]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (isConnecting)
                  const ProgressRing()
                else
                  FilledButton(
                    onPressed: () => appState.retrySupabaseConnection(),
                    child: const Text('Retry Connection'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
