import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/tests/current_device_card.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class HSRPTest extends StatefulWidget {
  const HSRPTest({required this.device, required this.standby, super.key});
  final NetDevice device;
  final bool standby;

  @override
  State<HSRPTest> createState() => _HSRPTestState();
}

class _HSRPTestState extends State<HSRPTest> {
  @override
  Widget build(BuildContext context) {
    Widget buildStandbyExpander(int vlan, bool active) => Expander(
      initiallyExpanded: true,
      header: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FluentWidgets.chip(
            child: Text(active ? "Active" : "Standby"),
            color: active ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Text("HSRP_VLAN$vlan"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Priority: ${active ? '110' : '100'} (configured ${active ? '110' : '100'})",
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Interface:"),
                  const SizedBox(height: 4),
                  Card(
                    child: Text(
                      "GigabitEthernet0/0/0.$vlan - Group $vlan\n192.168.$vlan.${active ? '2' : '3'}",
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Virtual IP address:"),
                    const SizedBox(height: 4),
                    TextBox(
                      controller: TextEditingController(
                        text: "192.168.$vlan.1",
                      ),
                      readOnly: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Active router:"),
                    const SizedBox(height: 4),
                    Card(
                      child: Row(
                        children: [
                          Icon(FluentIcons.branch_fork2),
                          SizedBox(width: 8),
                          Text("S1R1"),
                          Spacer(),
                          FluentWidgets.chip(
                            child: Text(active ? "Local" : ""),
                            color: active ? Colors.grey : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Standby router:"),
                    const SizedBox(height: 4),
                    Card(
                      child: Row(
                        children: [
                          Icon(FluentIcons.branch_fork2),
                          SizedBox(width: 8),
                          Text("S1R2"),
                          Spacer(),
                          FluentWidgets.chip(
                            child: Text(active ? "" : "Local"),
                            color: active ? Colors.transparent : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return ContentDialog(
      constraints: BoxConstraints(maxWidth: 700),
      title: TestDialogHeaderRow(title: 'HSRP Test', device: widget.device),
      /*
        FastEthernet/0.10 - Group 10
          State is Active
            3 state changes, last state change 00:01:12
          Virtual IP address is 192.168.10.1
          Active virtual MAC address is 0000.0c07.ac0a
            Local virtual MAC address is 0000.0c07.ac0a (v1 default)
          Hello time 3 sec, hold time 10 sec
          Next hello sent in 1.024 secs
          Preemption enabled
          Active router is local
          Standby router is 192.168.10.3, priority 100 (expires in 9.568 sec)
          Priority 110 (configured 110)
          Group name is "HSRP_VLAN10" (default)

        FastEthernet/0.20 - Group 20
          State is Standby
            2 state changes, last state change 00:00:45
          Virtual IP address is 192.168.20.1
          Active virtual MAC address is 0000.0c07.ac14
            Local virtual MAC address is 0000.0c07.ac14 (v1 default)
          Hello time 3 sec, hold time 10 sec
          Next hello sent in 2.012 secs
          Preemption enabled
          Active router is 192.168.20.2, priority 110 (expires in 9.568 sec)
          Standby router is local
          Priority 100 (configured 100)
          Group name is "HSRP_VLAN20" (default)
      */
      content: ListView(
        shrinkWrap: true,
        children: [
          buildStandbyExpander(10, widget.standby),
          SizedBox(height: 12),
          buildStandbyExpander(20, widget.standby),
          SizedBox(height: 12),
          buildStandbyExpander(99, widget.standby),
        ],
      ),
    );
  }
}
