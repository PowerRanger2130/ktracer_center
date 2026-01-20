import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/widgets/device_details/ACLs/acl_list.dart';
import 'package:ktracer_center/widgets/device_details/DHCP/dhcp_list.dart';
import 'package:ktracer_center/widgets/device_details/General/general_tab.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/Channel%20Groups/channel_group_list.dart';
import 'package:ktracer_center/widgets/device_details/Interfaces/interface_list.dart';
import 'package:ktracer_center/widgets/device_details/NAT/nat_list.dart';
import 'package:ktracer_center/widgets/device_details/Routing/static_routes_list.dart';
import 'package:ktracer_center/widgets/device_details/Tunnels/tunnel_list.dart';
import 'package:ktracer_center/widgets/device_details/VLANs/vlan_list.dart';

enum VTPMode { server, client, transparent }

enum VTPVersion { v1, v2, v3 }

class DeviceDetails extends StatefulWidget {
  const DeviceDetails({required this.device, super.key});
  final NetDevice device;

  @override
  State<DeviceDetails> createState() => _DeviceDetailsState();
}

class _DeviceDetailsState extends State<DeviceDetails> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    const noColor = WidgetStatePropertyAll(Colors.transparent);

    return TabView(
      currentIndex: _currentTab,
      onChanged: (index) => setState(() => _currentTab = index),
      header: const SizedBox(width: 12),
      tabs: [
        Tab(
          text: const Text('General'),
          body: GeneralTab(device: widget.device),
          backgroundColor: noColor,
          selectedBackgroundColor: noColor,
        ),
        Tab(
          text: const Text('Ports'),
          body: InterfaceList(device: widget.device),
          backgroundColor: noColor,
          selectedBackgroundColor: noColor,
        ),
        if (widget.device.preset.capabilities.contains('vlan'))
          Tab(
            text: const Text('VLANs'),
            body: VlanList(device: widget.device),
            backgroundColor: noColor,
            selectedBackgroundColor: noColor,
          ),
        if (widget.device.preset.capabilities.contains('etherchannel') ||
            widget.device.preset.capabilities.contains('lacp'))
          Tab(
            text: const Text('Channel Groups'),
            body: ChannelGroupList(device: widget.device),
            backgroundColor: noColor,
            selectedBackgroundColor: noColor,
          ),
        if (widget.device.preset.capabilities.contains('dhcp-server') ||
            widget.device.preset.capabilities.contains('dhcp-relay'))
          Tab(
            text: const Text('DHCP'),
            body: DhcpList(device: widget.device),
            backgroundColor: noColor,
            selectedBackgroundColor: noColor,
          ),
        if (widget.device.preset.capabilities.contains('acl'))
          Tab(
            text: const Text('ACLs'),
            body: AclList(device: widget.device),
            backgroundColor: noColor,
            selectedBackgroundColor: noColor,
          ),
        if (widget.device.preset.capabilities.contains('nat'))
          Tab(
            text: const Text('NAT'),
            body: NatList(device: widget.device),
            backgroundColor: noColor,
            selectedBackgroundColor: noColor,
          ),
        if (widget.device.preset.capabilities.contains('vpn') ||
            widget.device.preset.capabilities.contains('pppoe'))
          Tab(
            text: const Text('Tunnels'),
            body: TunnelList(device: widget.device),
            backgroundColor: noColor,
            selectedBackgroundColor: noColor,
          ),
        if (widget.device.preset.capabilities.contains('static-routing'))
          Tab(
            text: const Text('Routing'),
            body: StaticRoutesList(device: widget.device),
            backgroundColor: noColor,
            selectedBackgroundColor: noColor,
          ),
      ],
    );
  }
}
