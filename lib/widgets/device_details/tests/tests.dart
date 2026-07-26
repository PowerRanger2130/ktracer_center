import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/devices/device_preset.dart';
import 'package:ktracer_center/models/models.dart';
import 'package:ktracer_center/widgets/device_details/tests/bgp.dart';
import 'package:ktracer_center/widgets/device_details/tests/etherchannel.dart';
import 'package:ktracer_center/widgets/device_details/tests/hsrp.dart';
import 'package:ktracer_center/widgets/device_details/tests/ip_routes.dart';
import 'package:ktracer_center/widgets/device_details/tests/ospf.dart';
import 'package:ktracer_center/widgets/device_details/tests/ping.dart';
import 'package:ktracer_center/widgets/device_details/tests/portsecurity.dart';
import 'package:ktracer_center/widgets/device_details/tests/vlan.dart';
import 'package:ktracer_center/widgets/device_details/tests/traceroute.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class TestsTab extends StatefulWidget {
  const TestsTab({required this.device, super.key});
  final NetDevice device;

  @override
  State<TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends State<TestsTab> {
  @override
  Widget build(BuildContext context) {
    void testDialog(Widget child) {
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Color(0xFF1f1f1f),
        builder: (context) {
          return child;
        },
      );
    }

    return FluentWidgets.mica(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton(
                  child: Text("Ping Test"),
                  onPressed: () {
                    testDialog(PingTest(device: widget.device));
                  },
                ),
                const SizedBox(width: 12),
                FilledButton(
                  child: Text("Traceroute Test"),
                  onPressed: () {
                    testDialog(TracerouteTest(device: widget.device));
                  },
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton(
                      child: Text("HSRP Test Standby"),
                      onPressed: () {
                        testDialog(
                          HSRPTest(device: widget.device, standby: false),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      child: Text("HSRP Test Active"),
                      onPressed: () {
                        testDialog(
                          HSRPTest(device: widget.device, standby: true),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                FilledButton(
                  child: Text("Etherchannel Test"),
                  onPressed: () {
                    testDialog(EtherchannelTest(device: widget.device));
                  },
                ),
                if (widget.device.category == NetDeviceCategory.Switch) ...[
                  const SizedBox(width: 12),
                  FilledButton(
                    child: Text("Switch Port Security"),
                    onPressed: () {
                      testDialog(SwitchPortSecurityTest(device: widget.device));
                    },
                  ),
                ],
                const SizedBox(width: 12),
                FilledButton(
                  child: Text("OSPF Test"),
                  onPressed: () {
                    testDialog(OspfTest(device: widget.device));
                  },
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton(
                      child: Text("IP Routes S1R1"),
                      onPressed: () {
                        testDialog(
                          IpRoutesTest(
                            device: widget.device,
                            site: RouterSite.s1r1,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      child: Text("IP Routes S2R1"),
                      onPressed: () {
                        testDialog(
                          IpRoutesTest(
                            device: widget.device,
                            site: RouterSite.s2r1,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      child: Text("IP Routes S3R1"),
                      onPressed: () {
                        testDialog(
                          IpRoutesTest(
                            device: widget.device,
                            site: RouterSite.s3r1,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      child: Text("VLAN Brief"),
                      onPressed: () {
                        testDialog(VlanTest(device: widget.device));
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton(
                      child: Text("BGP Test AS 65001"),
                      onPressed: () {
                        testDialog(
                          BgpTest(device: widget.device, localAs: 65001),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      child: Text("BGP Test AS 65002"),
                      onPressed: () {
                        testDialog(
                          BgpTest(device: widget.device, localAs: 65002),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      child: Text("BGP Test AS 65003"),
                      onPressed: () {
                        testDialog(
                          BgpTest(device: widget.device, localAs: 65003),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
