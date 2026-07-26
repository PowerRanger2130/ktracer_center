import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/widgets/device_details/tests/current_device_card.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

enum RouteType {
  bgp('B', 'BGP'),
  connected('C', 'Connected'),
  local('L', 'Local'),
  staticRoute('S', 'Static'),
  ospf('O', 'OSPF');

  const RouteType(this.code, this.label);

  final String code;
  final String label;

  static RouteType? fromCode(String code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

Color _routeColor(RouteType? type) {
  return switch (type) {
    RouteType.bgp => const Color(0xffca5010),
    RouteType.connected => const Color(0xff107c10),
    RouteType.local => const Color(0xff008272),
    RouteType.staticRoute => const Color(0xff0078d4),
    RouteType.ospf => const Color(0xff8764b8),
    null => const Color(0xff616161),
  };
}

class IpRoute {
  const IpRoute({
    required this.typeCode,
    required this.prefix,
    this.ad,
    this.metric,
    this.via,
    this.iface,
    this.age,
    this.isDefaultCandidate = false,
  });

  final String typeCode; // B, C, L, S, S, O …
  final String prefix;
  final int? ad; // administrative distance
  final int? metric;
  final String? via;
  final String? iface;
  final String? age;
  final bool isDefaultCandidate;

  RouteType? get routeType => RouteType.fromCode(typeCode.replaceAll('*', ''));
}

class SubnetGroup {
  const SubnetGroup({required this.routes});

  final List<IpRoute> routes;
}

// ---------------------------------------------------------------------------
// Site routing tables
// ---------------------------------------------------------------------------

enum RouterSite {
  s1r1('S1R1'),
  s2r1('S2R1'),
  s3r1('S3R1');

  const RouterSite(this.label);
  final String label;
}

List<SubnetGroup> _groupsFor(RouterSite site) => switch (site) {
  RouterSite.s1r1 => _s1r1Groups,
  RouterSite.s2r1 => _s2r1Groups,
  RouterSite.s3r1 => _s3r1Groups,
};

// S1R1 (AS 65001) ─────────────────────────────────────────────────────────

final _s1r1Groups = <SubnetGroup>[
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'S',
        prefix: '0.0.0.0/0',
        ad: 254,
        metric: 0,
        via: '10.224.55.250',
        isDefaultCandidate: true,
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(typeCode: 'C', prefix: '10.0.1.0/30', iface: 'Tunnel0'),
      IpRoute(typeCode: 'L', prefix: '10.0.1.1/32', iface: 'Tunnel0'),
      IpRoute(typeCode: 'C', prefix: '10.0.2.0/30', iface: 'Tunnel1'),
      IpRoute(typeCode: 'L', prefix: '10.0.2.1/32', iface: 'Tunnel1'),
      IpRoute(
        typeCode: 'C',
        prefix: '10.224.52.0/22',
        iface: 'GigabitEthernet0/0/1',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '10.224.55.37/32',
        iface: 'GigabitEthernet0/0/1',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'C',
        prefix: '192.168.10.0/24',
        iface: 'GigabitEthernet0/0/0.10',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '192.168.10.2/32',
        iface: 'GigabitEthernet0/0/0.10',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'C',
        prefix: '192.168.20.0/24',
        iface: 'GigabitEthernet0/0/0.20',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '192.168.20.2/32',
        iface: 'GigabitEthernet0/0/0.20',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.32.0/24',
        ad: 20,
        metric: 0,
        via: '10.0.2.2',
        age: '19:49:58',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'C',
        prefix: '192.168.81.0/27',
        iface: 'GigabitEthernet0/0/0.81',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '192.168.81.1/32',
        iface: 'GigabitEthernet0/0/0.81',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.82.0/27',
        ad: 20,
        metric: 0,
        via: '10.0.1.2',
        age: '21:55:19',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.83.0/27',
        ad: 20,
        metric: 0,
        via: '10.0.2.2',
        age: '19:49:58',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'C',
        prefix: '192.168.99.0/24',
        iface: 'GigabitEthernet0/0/0.99',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '192.168.99.2/32',
        iface: 'GigabitEthernet0/0/0.99',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.199.0/24',
        ad: 20,
        metric: 0,
        via: '10.0.1.2',
        age: '21:55:19',
      ),
    ],
  ),
];

// S2R1 (AS 65002) ─────────────────────────────────────────────────────────

final _s2r1Groups = <SubnetGroup>[
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'S',
        prefix: '0.0.0.0/0',
        ad: 254,
        metric: 0,
        via: '10.224.55.250',
        isDefaultCandidate: true,
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(typeCode: 'C', prefix: '10.0.1.0/30', iface: 'Tunnel0'),
      IpRoute(typeCode: 'L', prefix: '10.0.1.2/32', iface: 'Tunnel0'),
      IpRoute(
        typeCode: 'C',
        prefix: '10.224.52.0/22',
        iface: 'GigabitEthernet0/0/0',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '10.224.55.35/32',
        iface: 'GigabitEthernet0/0/0',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.10.0/24',
        ad: 20,
        metric: 0,
        via: '10.0.1.1',
        age: '21:55:19',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.20.0/24',
        ad: 20,
        metric: 0,
        via: '10.0.1.1',
        age: '21:55:19',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.81.0/27',
        ad: 20,
        metric: 0,
        via: '10.0.1.1',
        age: '21:55:19',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.32.0/24',
        ad: 20,
        metric: 0,
        via: '10.0.1.1',
        age: '19:49:58',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'C',
        prefix: '192.168.82.0/27',
        iface: 'GigabitEthernet0/0/0.82',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '192.168.82.1/32',
        iface: 'GigabitEthernet0/0/0.82',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.83.0/27',
        ad: 20,
        metric: 0,
        via: '10.0.1.1',
        age: '19:49:58',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.99.0/24',
        ad: 20,
        metric: 0,
        via: '10.0.1.1',
        age: '21:55:19',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'C',
        prefix: '192.168.199.0/24',
        iface: 'GigabitEthernet0/0/0.199',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '192.168.199.1/32',
        iface: 'GigabitEthernet0/0/0.199',
      ),
    ],
  ),
];

// S3R1 (AS 65003) ─────────────────────────────────────────────────────────

final _s3r1Groups = <SubnetGroup>[
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'S',
        prefix: '0.0.0.0/0',
        ad: 254,
        metric: 0,
        via: '10.224.55.250',
        isDefaultCandidate: true,
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(typeCode: 'C', prefix: '10.0.2.0/30', iface: 'Tunnel0'),
      IpRoute(typeCode: 'L', prefix: '10.0.2.2/32', iface: 'Tunnel0'),
      IpRoute(
        typeCode: 'C',
        prefix: '10.224.52.0/22',
        iface: 'GigabitEthernet0/0/1',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '10.224.55.36/32',
        iface: 'GigabitEthernet0/0/1',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.10.0/24',
        ad: 20,
        metric: 0,
        via: '10.0.2.1',
        age: '19:49:58',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.20.0/24',
        ad: 20,
        metric: 0,
        via: '10.0.2.1',
        age: '19:49:58',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'C',
        prefix: '192.168.32.0/24',
        iface: 'GigabitEthernet0/0/0',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '192.168.32.1/32',
        iface: 'GigabitEthernet0/0/0',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.81.0/27',
        ad: 20,
        metric: 0,
        via: '10.0.2.1',
        age: '19:49:58',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.82.0/27',
        ad: 20,
        metric: 0,
        via: '10.0.2.1',
        age: '21:55:19',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'C',
        prefix: '192.168.83.0/27',
        iface: 'GigabitEthernet0/0/0.83',
      ),
      IpRoute(
        typeCode: 'L',
        prefix: '192.168.83.1/32',
        iface: 'GigabitEthernet0/0/0.83',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.99.0/24',
        ad: 20,
        metric: 0,
        via: '10.0.2.1',
        age: '19:49:58',
      ),
    ],
  ),
  SubnetGroup(
    routes: [
      IpRoute(
        typeCode: 'B',
        prefix: '192.168.199.0/24',
        ad: 20,
        metric: 0,
        via: '10.0.2.1',
        age: '21:55:19',
      ),
    ],
  ),
];

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class IpRoutesTest extends StatefulWidget {
  const IpRoutesTest({required this.device, required this.site, super.key});
  final NetDevice device;
  final RouterSite site;

  @override
  State<IpRoutesTest> createState() => _IpRoutesTestState();
}

class _IpRoutesTestState extends State<IpRoutesTest> {
  /// Which route types are currently highlighted (null = all shown normally).
  final Set<RouteType> _highlighted = {};

  // All route types present in the mock data
  static const _filterableTypes = RouteType.values;

  void _toggleHighlight(RouteType type) {
    setState(() {
      if (_highlighted.contains(type)) {
        _highlighted.remove(type);
      } else {
        _highlighted.add(type);
      }
    });
  }

  bool get _hasHighlight => _highlighted.isNotEmpty;

  bool _isHighlighted(IpRoute route) {
    if (!_hasHighlight) return false;
    final t = route.routeType;
    return t != null && _highlighted.contains(t);
  }

  bool _isDimmed(IpRoute route) {
    if (!_hasHighlight) return false;
    return !_isHighlighted(route);
  }

  // -------------------------------------------------------------------------
  // Builders
  // -------------------------------------------------------------------------

  Widget _filterBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _filterableTypes.map((type) {
        final active = _highlighted.contains(type);
        final color = _routeColor(type);
        return GestureDetector(
          onTap: () => _toggleHighlight(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: .85)
                  : color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? color : color.withValues(alpha: .4),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: .25)
                        : color.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type.code,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: active ? Colors.white : color,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  type.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : color,
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 4),
                  Icon(FluentIcons.check_mark, size: 10, color: Colors.white),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _routeCard(IpRoute route, {IpRoute? localRoute}) {
    final type = route.routeType;
    final color = _routeColor(type);
    final highlighted = _isHighlighted(route);
    final dimmed = _isDimmed(route);
    final isDirect = type == RouteType.connected || type == RouteType.local;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dimmed ? 0.3 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: highlighted
              ? Border.all(color: color, width: 1.5)
              : Border.all(color: Colors.transparent),
          color: highlighted ? color.withValues(alpha: .08) : null,
        ),
        child: Card(
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: isDirect ? 6 : 9,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Route type badge
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDirect ? .10 : .18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  route.typeCode,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: isDirect ? 11 : 13,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Prefix
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      route.prefix,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: isDirect ? 12 : 13,
                        fontWeight: highlighted
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (localRoute != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'L  ${localRoute.prefix}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: _routeColor(RouteType.local),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(),

              // Via
              if (route.via != null) ...[
                const Text('via', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                FluentWidgets.chip(
                  child: Text(
                    route.via!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  color: color.withValues(alpha: .6),
                ),
                const SizedBox(width: 8),
              ],

              // Interface chip
              if (route.iface != null)
                FluentWidgets.chip(
                  child: Text(
                    route.iface!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  color: _routeColor(RouteType.connected),
                ),

              // Default route badge
              if (route.isDefaultCandidate) ...[
                const SizedBox(width: 6),
                FluentWidgets.chip(
                  child: const Text('default', style: TextStyle(fontSize: 11)),
                  color: const Color(0xff0078d4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _routeTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._groupsFor(widget.site).expand((group) sync* {
          final routes = group.routes;
          final consumed = <int>{};
          for (int i = 0; i < routes.length; i++) {
            if (consumed.contains(i)) continue;
            final route = routes[i];
            // Pair a C route with the next L /32 on the same interface
            IpRoute? paired;
            if (route.routeType == RouteType.connected) {
              final j = i + 1;
              if (j < routes.length) {
                final next = routes[j];
                if (next.routeType == RouteType.local &&
                    next.prefix.endsWith('/32') &&
                    next.iface == route.iface) {
                  paired = next;
                  consumed.add(j);
                }
              }
            }
            yield _routeCard(route, localRoute: paired);
          }
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 600),
      title: TestDialogHeaderRow(
        title: 'IP Routes',
        device: widget.device,
        afterTitle: _hasHighlight
            ? Padding(
                padding: const EdgeInsets.only(left: 10),
                child: FluentWidgets.chip(
                  child: Text(
                    '${_highlighted.map((t) => t.label).join(', ')} highlighted',
                    style: const TextStyle(fontSize: 11),
                  ),
                  color: const Color(0xffca5010),
                ),
              )
            : null,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _filterBar(),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 1000),
            child: SingleChildScrollView(child: _routeTable()),
          ),
        ],
      ),
    );
  }
}
