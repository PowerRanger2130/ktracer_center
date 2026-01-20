import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/pages/network_services/bgp_tab.dart';
import 'package:ktracer_center/pages/network_services/eigrp_tab.dart';
import 'package:ktracer_center/pages/network_services/hsrp_tab.dart';
import 'package:ktracer_center/pages/network_services/ospf_tab.dart';
import 'package:ktracer_center/pages/network_services/spanning_tree_tab.dart';
import 'package:ktracer_center/pages/network_services/vrf_tab.dart';
import 'package:ktracer_center/pages/network_services/vtp_tab.dart';
import 'package:provider/provider.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class NetworkServicesPage extends StatefulWidget {
  const NetworkServicesPage({super.key});

  @override
  State<NetworkServicesPage> createState() => _NetworkServicesPageState();
}

class _NetworkServicesPageState extends State<NetworkServicesPage> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final project = appState.selectedProject;

    if (project == null) {
      return const Center(child: Text('No project selected'));
    }

    const noColor = WidgetStatePropertyAll(Colors.transparent);

    return TabView(
      currentIndex: _currentTab,
      onChanged: (index) => setState(() => _currentTab = index),
      header: const SizedBox(width: 12),
      tabs: [
        Tab(
          text: const Text('HSRP'),
          body: FluentWidgets.mica(
            child: HsrpTab(project: project, devices: appState.devices),
          ),
          backgroundColor: noColor,
          selectedBackgroundColor: noColor,
        ),
        Tab(
          text: const Text('OSPF'),
          body: FluentWidgets.mica(
            child: OspfTab(project: project, devices: appState.devices),
          ),
          backgroundColor: noColor,
          selectedBackgroundColor: noColor,
        ),
        Tab(
          text: const Text('EIGRP'),
          body: FluentWidgets.mica(
            child: EigrpTab(project: project, devices: appState.devices),
          ),
          backgroundColor: noColor,
          selectedBackgroundColor: noColor,
        ),
        Tab(
          text: const Text('BGP'),
          body: FluentWidgets.mica(
            child: BgpTab(project: project, devices: appState.devices),
          ),
          backgroundColor: noColor,
          selectedBackgroundColor: noColor,
        ),
        Tab(
          text: const Text('VRF'),
          body: FluentWidgets.mica(
            child: VrfTab(project: project, devices: appState.devices),
          ),
          backgroundColor: noColor,
          selectedBackgroundColor: noColor,
        ),
        Tab(
          text: const Text('Spanning Tree'),
          body: FluentWidgets.mica(
            child: SpanningTreeTab(project: project, devices: appState.devices),
          ),
          backgroundColor: noColor,
          selectedBackgroundColor: noColor,
        ),
        Tab(
          text: const Text('VTP'),
          body: FluentWidgets.mica(
            child: VtpTab(project: project, devices: appState.devices),
          ),
          backgroundColor: noColor,
          selectedBackgroundColor: noColor,
        ),
      ],
    );
  }
}
