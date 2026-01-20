// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:ui';

import 'package:ktracer_center/devices/switchport.dart';
import 'package:ktracer_center/network/port.dart';

enum NetDeviceCategory { Switch, Router, AccessPoint, Firewall, Server, PC }

/// A preset defines a type of device (e.g., Catalyst 2950 24-port).
/// Physical devices in the lab reference these presets by ID.
class DevicePreset {
  final int id;
  final String name;
  final String sku;
  final NetDeviceCategory category;
  final Color? color;
  final bool hasSsh;
  final List<String> capabilities;

  /// Maximum number of interfaces in an EtherChannel/Port-channel.
  /// Default is 8 for physical switches.
  /// EVE-NG IOL/IOU images have a limit of 4.
  final int etherchannelLimit;

  /// Default ports for this device type
  final List<Port> Function() defaultInterfaces;

  /// Default config (VLANs, settings, etc.)
  final Map<String, dynamic> Function() defaultConfig;

  /// Patterns for interfaces that are locked/unavailable on this preset.
  /// Can be exact match (e.g., "FastEthernet 0/0") or pattern:
  /// - Ends with pattern: "/24" matches any interface ending in /24
  /// - Type pattern: "Serial" matches any Serial interface
  final List<String> lockedInterfacePatterns;

  /// VLAN IDs that are locked/reserved on this preset
  final List<int> lockedVlans;

  /// Reason why certain interfaces are locked (for tooltip display)
  final String? lockedInterfaceReason;

  const DevicePreset({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    this.color,
    this.hasSsh = false,
    required this.defaultInterfaces,
    required this.defaultConfig,
    required this.capabilities,
    this.etherchannelLimit = 8,
    this.lockedInterfacePatterns = const [],
    this.lockedVlans = const [],
    this.lockedInterfaceReason,
  });

  /// Check if an interface is locked for this preset
  bool isInterfaceLocked(String interfaceName) {
    final nameLower = interfaceName.toLowerCase();
    for (final pattern in lockedInterfacePatterns) {
      final patternLower = pattern.toLowerCase();
      if (patternLower.startsWith('/')) {
        // Ends with pattern
        if (nameLower.endsWith(patternLower)) return true;
      } else if (nameLower.contains(patternLower)) {
        // Contains match
        return true;
      }
    }
    return false;
  }

  /// Check if a VLAN is locked for this preset
  bool isVlanLocked(int vlanId) => lockedVlans.contains(vlanId);

  /// Validate EtherChannel member count
  /// Returns (isValid, errorMessage)
  (bool, String?) validateEtherchannelMembers(int memberCount) {
    if (etherchannelLimit == 0) {
      if (memberCount > 0) {
        return (false, 'Device $name does not support EtherChannel');
      }
      return (true, null);
    }

    if (memberCount > etherchannelLimit) {
      return (
        false,
        'EtherChannel member count ($memberCount) exceeds limit ($etherchannelLimit) for $name',
      );
    }

    return (true, null);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'category': category.name,
    'hasSsh': hasSsh,
    'etherchannelLimit': etherchannelLimit,
  };
}

/// All available device presets in the system
class DevicePresets {
  static final c2950_24 = DevicePreset(
    id: 1,
    name: 'Catalyst 2950 24-port',
    sku: 'Catalyst 2950',
    category: NetDeviceCategory.Switch,
    color: const Color.fromARGB(80, 102, 187, 106),
    defaultInterfaces: () =>
        List.generate(24, (i) => Switchport(name: "FastEthernet 0/${i + 1}")) +
        [
          Switchport(name: "GigabitEthernet 0/1"),
          Switchport(name: "GigabitEthernet 0/2"),
        ],
    defaultConfig: () => {
      'vlans': [
        {
          'vlan_id': 1,
          'name': 'Default',
          'description': 'Default VLAN',
          'enabled': true,
        },
      ],
      'domain_lookup': true,
    },
    capabilities: [
      'vlan', //
      'vtp-v1', //
      'vtp-v2', //
      'etherchannel',
      'lacp',
      'pagp',
      'stp-pvst',
    ],
  );

  static final c2950_48 = DevicePreset(
    id: 2,
    name: 'Catalyst 2950 48-port',
    sku: 'Catalyst 2950',
    category: NetDeviceCategory.Switch,
    color: const Color.fromARGB(80, 102, 187, 106),
    defaultInterfaces: () =>
        List.generate(48, (i) => Switchport(name: "FastEthernet 0/${i + 1}")) +
        [
          Switchport(name: "GigabitEthernet 0/1"),
          Switchport(name: "GigabitEthernet 0/2"),
        ],
    defaultConfig: () => {
      'vlans': [
        {
          'vlan_id': 1,
          'name': 'Default',
          'description': 'Default VLAN',
          'enabled': true,
        },
      ],
      'domain_lookup': true,
    },
    capabilities: [
      'vlan',
      'vtp-v1',
      'vtp-v2',
      'etherchannel',
      'lacp',
      'pagp',
      'stp-pvst',
    ],
  );

  static final c2960 = DevicePreset(
    id: 3,
    name: 'Catalyst 2960',
    sku: 'Catalyst 2960',
    category: NetDeviceCategory.Switch,
    color: const Color.fromARGB(80, 38, 198, 218),
    defaultInterfaces: () =>
        List.generate(24, (i) => Switchport(name: "FastEthernet 0/${i + 1}")) +
        [
          Switchport(name: "GigabitEthernet 0/1"),
          Switchport(name: "GigabitEthernet 0/2"),
        ],
    defaultConfig: () => {
      'vlans': [
        {
          'vlan_id': 1,
          'name': 'Default',
          'description': 'Default VLAN',
          'enabled': true,
        },
      ],
      'domain_lookup': true,
    },
    hasSsh: true,
    capabilities: [
      'vtp-v1',
      'vtp-v2',
      'vlan',
      'etherchannel',
      'lacp',
      'pagp',
      'stp-pvst',
      'stp-rapid-pvst',
      'protected-port',
    ],
  );

  static final c3550 = DevicePreset(
    id: 4,
    name: 'Catalyst 3550',
    sku: 'Catalyst 3550',
    category: NetDeviceCategory.Switch,
    color: const Color.fromARGB(80, 92, 107, 192),
    defaultInterfaces: () =>
        List.generate(24, (i) => Switchport(name: "FastEthernet 0/${i + 1}")) +
        [
          Switchport(name: "GigabitEthernet 0/1"),
          Switchport(name: "GigabitEthernet 0/2"),
        ],
    defaultConfig: () => {
      'vlans': [
        {
          'vlan_id': 1,
          'name': 'Default',
          'description': 'Default VLAN',
          'enabled': true,
        },
      ],
      'domain_lookup': true,
    },
    capabilities: [
      'vtp-v1',
      'vtp-v2',
      'vlan',
      'etherchannel',
      'lacp',
      'pagp',
      'stp-pvst',
      'stp-rapid-pvst',
      'stp-mst',
      'rip',
      'ospf',
      'eigrp',
      'hsrp',
      'vrf', // VRF-Lite supported
      'acl',
      'dhcp-server',
      'subinterfaces',
    ],
  );

  static final c3560x = DevicePreset(
    id: 5,
    name: 'Catalyst 3560X',
    sku: 'Catalyst 3560X',
    category: NetDeviceCategory.Switch,
    color: const Color.fromARGB(80, 149, 117, 205),
    defaultInterfaces: () =>
        List.generate(
          24,
          (i) => Switchport(name: "GigabitEthernet 0/${i + 1}"),
        ) +
        [
          Switchport(name: "TenGigabitEthernet 0/1"), // ?
          Switchport(name: "TenGigabitEthernet 0/2"), // ?
        ],
    defaultConfig: () => {
      'vlans': [
        {
          'vlan_id': 1,
          'name': 'Default',
          'description': 'Default VLAN',
          'enabled': true,
        },
      ],
      'domain_lookup': true,
    },
    capabilities: [
      'vtp-v1',
      'vtp-v2',
      'vtp-v3',
      'vlan',
      'etherchannel',
      'lacp',
      'stp-pvst',
      'stp-rapid-pvst',
      'stp-mst',
      'rip',
      'ospf',
      'eigrp',
      'bgp',
      'hsrp',
      'vrf',
      'acl',
      'acl-v6',
      'dhcp-server',
      'subinterfaces',
    ],
  );

  static final c4948 = DevicePreset(
    id: 6,
    name: 'Catalyst 4948',
    sku: 'Catalyst 4948',
    category: NetDeviceCategory.Switch,
    color: const Color.fromARGB(80, 126, 87, 194),
    defaultInterfaces: () =>
        List.generate(
          48,
          (i) => Switchport(name: "GigabitEthernet 1/${i + 1}"),
        ) +
        [
          Switchport(name: "TenGigabitEthernet 1/49"),
          Switchport(name: "TenGigabitEthernet 1/50"),
        ],
    defaultConfig: () => {
      'vlans': [
        {
          'vlan_id': 1,
          'name': 'Default',
          'description': 'Default VLAN',
          'enabled': true,
        },
      ],
      'domain_lookup': true,
    },
    capabilities: [
      'vtp-v1',
      'vtp-v2',
      'vtp-v3',
      'vlan',
      'etherchannel',
      'lacp',
      'stp-pvst',
      'stp-rapid-pvst',
      'stp-mst',
      'rip',
      'ospf',
      'eigrp',
      'bgp',
      'hsrp',
      'vrf',
      'acl',
      'acl-v6',
      'dhcp-server',
      'subinterfaces',
    ],
  );

  static final me3400 = DevicePreset(
    id: 7,
    name: 'ME 3400E',
    sku: 'ME 3400E',
    category: NetDeviceCategory.Router,
    color: const Color.fromARGB(80, 255, 179, 0),
    defaultInterfaces: () =>
        List.generate(24, (i) => Port(name: "FastEthernet 0/${i + 1}")) +
        [Port(name: "GigabitEthernet 0/1"), Port(name: "GigabitEthernet 0/2")],
    defaultConfig: () => {
      'vlans': [
        {
          'vlan_id': 1,
          'name': 'Default',
          'description': 'Default VLAN',
          'enabled': true,
        },
      ],
      'domain_lookup': true,
    },
    capabilities: [
      'vtp-v1',
      'vtp-v2',
      'vlan',
      'etherchannel',
      'lacp',
      'pagp',
      'stp-pvst',
      'stp-rapid-pvst',
      'protected-port',
      'subinterfaces',
      'dhcp-server',
      'dhcp-relay',
      'hsrp',
      'vrf', // ME switches support VRF-Lite for metro ethernet
      'acl',
    ],
  );

  static final i2800 = DevicePreset(
    id: 12,
    name: 'ISR 2800',
    sku: 'ISR 2800',
    category: NetDeviceCategory.Router,
    color: const Color.fromARGB(80, 79, 195, 247),
    defaultInterfaces: () => [
      Port(name: "FastEthernet 0/0"),
      Port(name: "FastEthernet 0/1"),
      Port(name: "FastEthernet 0/1.80"), // Management subinterface (dot1q 80)
    ],
    defaultConfig: () => {'domain_lookup': true},
    capabilities: [
      'rip',
      'ospf',
      'eigrp',
      'bgp',
      'hsrp',
      'vrf',
      'acl',
      'acl-v6',
      'dhcp-server',
      'dhcp-relay',
      'nat',
      'vpn',
      'voip',
      'pppoe',
      'aaa',
      'radius',
      'tacacs',
      'subinterfaces',
      'static-routing',
    ],
    // Fa0/1 is reserved for switch connection (trunk), Fa0/1.80 is management subinterface
    lockedInterfacePatterns: const ['FastEthernet 0/1'],
    lockedInterfaceReason: 'Reserved for switch trunk connection (management)',
  );

  static final i2800_serial = DevicePreset(
    id: 13,
    name: 'ISR 2800 + Serial',
    sku: 'ISR 2800',
    category: NetDeviceCategory.Router,
    color: const Color.fromARGB(80, 174, 213, 129),
    defaultInterfaces: () => [
      Port(name: "FastEthernet 0/0"),
      Port(name: "FastEthernet 0/1"),
      Port(name: "FastEthernet 0/1.80"), // Management subinterface (dot1q 80)
      Port(name: "Serial 0/1/0"),
      Port(name: "Serial 0/1/1"),
    ],
    defaultConfig: () => i2800.defaultConfig(),
    capabilities: i2800.capabilities,
    // Fa0/1 is reserved for switch connection (trunk), Fa0/1.80 is management subinterface
    lockedInterfacePatterns: const ['FastEthernet 0/1'],
    lockedInterfaceReason: 'Reserved for switch trunk connection (management)',
  );

  static final i2811 = DevicePreset(
    id: 8,
    name: 'ISR 2811',
    sku: 'ISR 2811',
    category: NetDeviceCategory.Router,
    color: const Color.fromARGB(80, 239, 83, 80),
    defaultInterfaces: () => [
      Port(name: "FastEthernet 0/0"),
      Port(name: "FastEthernet 0/1"),
      Port(name: "FastEthernet 0/1.80"), // Management subinterface (dot1q 80)
    ],
    defaultConfig: () => {'domain_lookup': true},
    capabilities: [
      'rip',
      'ospf',
      'eigrp',
      'bgp',
      'hsrp',
      'vrf',
      'acl',
      'acl-v6',
      'dhcp-server',
      'dhcp-relay',
      'nat',
      'vpn',
      'voip',
      'pppoe',
      'aaa',
      'radius',
      'tacacs',
      'subinterfaces',
      'static-routing',
    ],
    // Fa0/1 is reserved for switch connection (trunk), Fa0/1.80 is management subinterface
    lockedInterfacePatterns: const ['FastEthernet 0/1'],
    lockedInterfaceReason: 'Reserved for switch trunk connection (management)',
  );

  static final i2811_serial = DevicePreset(
    id: 9,
    name: 'ISR 2811 + Serial',
    sku: 'ISR 2811',
    category: NetDeviceCategory.Router,
    color: const Color.fromARGB(80, 239, 83, 80),
    defaultInterfaces: () => [
      Port(name: "FastEthernet 0/0"),
      Port(name: "FastEthernet 0/1"),
      Port(name: "FastEthernet 0/1.80"), // Management subinterface (dot1q 80)
      Port(name: "Serial 0/0/0"),
      Port(name: "Serial 0/0/1"),
    ],
    defaultConfig: () => i2811.defaultConfig(),
    capabilities: i2811.capabilities,
    // Fa0/1 is reserved for switch connection (trunk), Fa0/1.80 is management subinterface
    lockedInterfacePatterns: const ['FastEthernet 0/1'],
    lockedInterfaceReason: 'Reserved for switch trunk connection (management)',
  );

  static final i2811_switch = DevicePreset(
    id: 10,
    name: 'ISR 2811 + Switch Module',
    sku: 'ISR 2811',
    category: NetDeviceCategory.Router,
    color: const Color.fromARGB(80, 239, 83, 80),
    defaultInterfaces: () => [
      Port(name: "FastEthernet 0/0"),
      Port(name: "FastEthernet 0/1"),
      Switchport(name: "FastEthernet 0/3/0"),
      Switchport(name: "FastEthernet 0/3/1"),
      Switchport(name: "FastEthernet 0/3/2"),
      Switchport(name: "FastEthernet 0/3/3"),
    ],
    defaultConfig: () => i2811.defaultConfig(),
    capabilities: i2811.capabilities,
    lockedInterfacePatterns: const ['FastEthernet 0/3/3'],
    lockedInterfaceReason: 'Reserved for management',
  );

  static final i2811_switch_serial = DevicePreset(
    id: 11,
    name: 'ISR 2811 + Switch + Serial',
    sku: 'ISR 2811',
    category: NetDeviceCategory.Router,
    color: const Color.fromARGB(80, 239, 83, 80),
    defaultInterfaces: () => [
      Port(name: "FastEthernet 0/0"),
      Port(name: "FastEthernet 0/1"),
      Switchport(name: "FastEthernet 0/3/0"),
      Switchport(name: "FastEthernet 0/3/1"),
      Switchport(name: "FastEthernet 0/3/2"),
      Switchport(name: "FastEthernet 0/3/3"),
      Port(name: "Serial 0/0/0"),
      Port(name: "Serial 0/0/1"),
    ],
    defaultConfig: () => i2811.defaultConfig(),
    capabilities: i2811.capabilities,
    // Only 2 ports - need at least one for management, leaving only one usable
    lockedInterfacePatterns: const ['FastEthernet 0/3/3'],
    lockedInterfaceReason: 'Reserved for management',
  );

  static final i4431 = DevicePreset(
    id: 14,
    name: 'ISR 4431',
    sku: 'ISR 4431',
    category: NetDeviceCategory.Router,
    color: const Color.fromARGB(80, 120, 144, 156),
    defaultInterfaces: () => [
      Port(name: "GigabitEthernet 0/0/0"),
      Port(name: "GigabitEthernet 0/0/1"),
      Port(name: "GigabitEthernet 0/0/2"),
      Port(name: "GigabitEthernet 0/0/3"),
    ],
    defaultConfig: () => {'domain_lookup': true},
    capabilities: [
      'rip',
      'ospf',
      'eigrp',
      'bgp',
      'hsrp',
      'vrf',
      'acl',
      'acl-v6',
      'dhcp-server',
      'dhcp-relay',
      'nat',
      'vpn',
      'voip',
      'pppoe',
      'aaa',
      'radius',
      'tacacs',
      'subinterfaces',
      'netconf',
      'restconf',
      'static-routing',
    ],
  );
  // ============ ASA Firewall Presets ============

  /// Cisco ASA 5550
  static final asa5550 = DevicePreset(
    id: 15,
    name: 'ASA 5550',
    sku: 'ASA 5550',
    category: NetDeviceCategory.Firewall,
    color: const Color.fromARGB(80, 244, 67, 54),
    hasSsh: true,
    etherchannelLimit: 0, // ASA doesn't support EtherChannel in standard mode
    defaultInterfaces: () => [
      Port(name: "Management 0/0"),
      Port(name: "GigabitEthernet 0/0"),
      Port(name: "GigabitEthernet 0/1"),
      Port(name: "GigabitEthernet 0/2"),
      Port(name: "GigabitEthernet 0/3"),
      Port(name: "GigabitEthernet 1/0"),
      Port(name: "GigabitEthernet 1/1"),
      Port(name: "GigabitEthernet 1/2"),
      Port(name: "GigabitEthernet 1/3"),
    ],
    defaultConfig: () => {'domain_lookup': false},
    capabilities: [
      'rip',
      'ospf',
      'eigrp',
      'bgp',
      'hsrp',
      'vrf',
      'acl',
      'acl-v6',
      'dhcp-server',
      'dhcp-relay',
      'nat',
      'vpn',
      'voip',
      'pppoe',
      'aaa',
      'radius',
      'tacacs',
      'subinterfaces',
      'netconf',
      'restconf',
      'static-routing',
    ],
    lockedInterfacePatterns: const ['Management 0/0'],
    lockedInterfaceReason: 'Reserved for management access',
  );

  // ============ EVE-NG Virtual Presets ============

  /// EVE-NG Switch (IOL/IOU L2 image)
  static final evengSwitch = DevicePreset(
    id: 100,
    name: 'EVE-NG Switch',
    sku: 'IOL L2',
    category: NetDeviceCategory.Switch,
    color: const Color.fromARGB(80, 233, 30, 99),
    hasSsh: true,
    etherchannelLimit: 4, // IOL/IOU limitation
    defaultInterfaces: () => List.generate(
      16,
      (i) => Switchport(name: "Ethernet ${i ~/ 4}/${i % 4}"),
    ),
    defaultConfig: () => {
      'vlans': [
        {
          'vlan_id': 1,
          'name': 'Default',
          'description': 'Default VLAN',
          'enabled': true,
        },
      ],
      'domain_lookup': true,
    },
    capabilities: [
      'vlan',
      'vtp-v1',
      'vtp-v2',
      'vtp-v3',
      'etherchannel',
      'lacp',
      'pagp',
      'stp-pvst',
      'stp-rapid-pvst',
      'stp-mst',
    ],
    lockedInterfacePatterns: const ['Ethernet 3/3'],
    lockedVlans: const [1],
    lockedInterfaceReason: 'Reserved for EVE-NG management',
  );

  /// EVE-NG Router (IOL/IOU L3 image)
  static final evengRouter = DevicePreset(
    id: 101,
    name: 'EVE-NG Router',
    sku: 'IOL L3',
    category: NetDeviceCategory.Router,
    color: const Color.fromARGB(80, 156, 39, 176),
    hasSsh: true,
    etherchannelLimit: 4, // IOL/IOU limitation
    defaultInterfaces: () =>
        List.generate(16, (i) => Port(name: "Ethernet ${i ~/ 4}/${i % 4}")),
    defaultConfig: () => {'domain_lookup': true},
    capabilities: [
      'rip',
      'ospf',
      'eigrp',
      'bgp',
      'hsrp',
      'vrf',
      'acl',
      'acl-v6',
      'dhcp-server',
      'dhcp-relay',
      'nat',
      'subinterfaces',
      'static-routing',
    ],
    lockedInterfacePatterns: const ['Ethernet 3/3'],
    lockedInterfaceReason: 'Reserved for EVE-NG management',
  );

  /// Get preset by ID
  static DevicePreset getById(int id) => all.where((p) => p.id == id).first;

  /// All available presets
  static List<DevicePreset> get all => [
    c2950_24,
    c2950_48,
    c2960,
    c3550,
    c3560x,
    c4948,
    me3400,
    i2811,
    i2811_serial,
    i2811_switch,
    i2811_switch_serial,
    i2800,
    i2800_serial,
    i4431,
    evengSwitch,
    evengRouter,
    asa5550,
  ];

  /// Get presets grouped by category for UI dropdowns
  static Map<String, List<DevicePreset>> get byCategory => {
    'Switch': [c2950_24, c2950_48, c2960],
    'L3 Switch': [c3550, c3560x, c4948],
    'Router': [
      me3400,
      i2811,
      i2811_serial,
      i2811_switch,
      i2811_switch_serial,
      i2800,
      i2800_serial,
      i4431,
    ],
    'Firewall': [asa5550],
    'EVE-NG': [evengSwitch, evengRouter],
  };

  /// Get all category names
  static List<String> get categories => byCategory.keys.toList();

  /// Get presets for a specific category
  static List<DevicePreset> getByCategory(String category) =>
      byCategory[category] ?? [];
}
