/// Device Configuration Exporter
///
/// Generates Cisco IOS terminal commands from a NetDevice configuration
/// and project-level network services (HSRP, OSPF, EIGRP, etc.)
library;

import 'package:ktracer_center/devices/device_preset.dart';
import 'package:ktracer_center/devices/switchport.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/models/network_services.dart';
import 'package:ktracer_center/network/port.dart';

/// Exports device configuration to Cisco IOS commands
class ConfigExporter {
  final NetDevice device;
  final ProjectProperties? projectProperties;

  ConfigExporter({required this.device, this.projectProperties});

  /// Generate all configuration commands for the device
  List<String> generateCommands() {
    final commands = <String>[];

    // Basic configuration
    commands.addAll(_generateBasicConfig());

    // VLANs (for switches)
    commands.addAll(_generateVlanCommands());

    // Interfaces
    commands.addAll(_generateInterfaceCommands());

    // Channel groups (EtherChannel)
    commands.addAll(_generateChannelGroupCommands());

    // Static routes
    commands.addAll(_generateStaticRouteCommands());

    // ACLs
    commands.addAll(_generateAclCommands());

    // DHCP Pools
    commands.addAll(_generateDhcpPoolCommands());

    // NAT rules
    commands.addAll(_generateNatCommands());

    // Tunnels
    commands.addAll(_generateTunnelCommands());

    // Project-level network services
    if (projectProperties != null) {
      // HSRP
      commands.addAll(_generateHsrpCommands());

      // OSPF
      commands.addAll(_generateOspfCommands());

      // EIGRP
      commands.addAll(_generateEigrpCommands());

      // BGP
      commands.addAll(_generateBgpCommands());

      // Project-level static routes (that apply to this device)
      commands.addAll(_generateProjectStaticRouteCommands());
    }

    // End configuration
    commands.add('end');

    return commands;
  }

  /// Generate commands as a single string (for display/copy)
  String generateCommandString() {
    return generateCommands().join('\n');
  }

  // ===========================================================================
  // Basic Configuration
  // ===========================================================================

  List<String> _generateBasicConfig() {
    final commands = <String>[];

    // Enable mode and configure terminal
    commands.add('enable');
    commands.add('configure terminal');
    commands.add('');

    // Hostname
    commands.add('hostname ${device.hostname}');

    // Domain lookup
    if (!device.domainLookup) {
      commands.add('no ip domain-lookup');
    }

    final defaultGatewayIpv4 = device.defaultGatewayIpv4;
    if (device.category == NetDeviceCategory.Switch &&
        defaultGatewayIpv4 != null) {
      commands.add('ip default-gateway $defaultGatewayIpv4');
    }

    commands.add('');
    return commands;
  }

  // ===========================================================================
  // VLAN Configuration
  // ===========================================================================

  List<String> _generateVlanCommands() {
    final commands = <String>[];
    final vlans = device.vlans;

    if (vlans.isEmpty) return commands;

    commands.add('! ===== VLANs =====');
    for (final vlan in vlans) {
      if (vlan.vlanId == 1) continue; // Skip default VLAN

      commands.add('vlan ${vlan.vlanId}');
      commands.add(' name ${vlan.name}');
      if (!vlan.enabled) {
        commands.add(' shutdown');
      }
      commands.add('exit');
    }
    commands.add('');

    // SVI interfaces (VLAN interfaces with IP addresses)
    for (final vlan in vlans) {
      if (vlan.ipAddress != null || vlan.ipv6Address != null) {
        commands.add('interface Vlan${vlan.vlanId}');
        if (vlan.description != null) {
          commands.add(' description ${vlan.description}');
        }
        if (vlan.ipAddress != null) {
          commands.add(
            ' ip address ${vlan.ipAddress!.address} ${vlan.ipAddress!.subnetMask}',
          );
        }
        if (vlan.ipv6Address != null) {
          commands.add(' ipv6 address ${vlan.ipv6Address!.toCIDR()}');
        }
        if (!vlan.enabled) {
          commands.add(' shutdown');
        } else {
          commands.add(' no shutdown');
        }
        commands.add('exit');
      }
    }
    commands.add('');

    return commands;
  }

  // ===========================================================================
  // Interface Configuration
  // ===========================================================================

  /// Check if a switchport has been modified from defaults
  bool _isSwitchportModified(Switchport port) {
    // Check for non-default values
    if (port.description != null && port.description!.isNotEmpty) return true;
    if (!port.enabled) return true; // shutdown
    if (port.mode == SwitchportMode.trunk) return true; // default is access
    if (port.vlan != 1) return true; // non-default VLAN
    if (port.nativeVlan != null) return true;
    if (port.allowedVlans != null && port.allowedVlans!.isNotEmpty) return true;
    if (port.protectedPort) return true;
    if (port.portSecurityEnabled) return true;
    if (port.spanningTreePortfast) return true;
    if (port.spanningTreeBpduGuard) return true;
    if (port.spanningTreeBpduFilter) return true;
    if (port.spanningTreeCost != null) return true;
    if (port.spanningTreePortPriority != null) return true;
    if (port.spanningTreeGuard != SpanningTreeGuard.none) return true;
    if (port.channelGroup != null) return true;
    return false;
  }

  /// Check if a router port has been modified from defaults
  bool _isRouterPortModified(Port port) {
    if (port.description != null && port.description!.isNotEmpty) return true;
    if (!port.enabled) return true;
    if (port.ipAssignment == IpAssignmentMode.dhcp) return true;
    if (port.ipv6Assignment == Ipv6AssignmentMode.automatic) return true;
    if (port.ipAddress != null) return true;
    if (port.ipv4HelperAddress != null && port.ipv4HelperAddress!.isNotEmpty) {
      return true;
    }
    if (port.dhcpRelayInformation == DhcpRelayInformationMode.trusted) {
      return true;
    }
    if (port.ipv6Address != null) return true;
    if (port.ipv4AccessGroupIn != null && port.ipv4AccessGroupIn!.isNotEmpty) {
      return true;
    }
    if (port.ipv4AccessGroupOut != null &&
        port.ipv4AccessGroupOut!.isNotEmpty) {
      return true;
    }
    return false;
  }

  List<String> _generateInterfaceCommands() {
    final commands = <String>[];
    final interfaces = device.interfaces;

    if (interfaces.isEmpty) return commands;

    // Filter to only include modified interfaces
    final modifiedInterfaces = interfaces.where((port) {
      if (port is Switchport) {
        return _isSwitchportModified(port);
      } else {
        return _isRouterPortModified(port);
      }
    }).toList();

    if (modifiedInterfaces.isEmpty) return commands;

    commands.add('! ===== Interfaces =====');
    for (final port in modifiedInterfaces) {
      commands.add('interface ${port.name}');

      if (port.description != null && port.description!.isNotEmpty) {
        commands.add(' description ${port.description}');
      }

      if (port is Switchport) {
        commands.addAll(_generateSwitchportCommands(port));
      } else {
        commands.addAll(_generateRouterPortCommands(port));
      }

      if (!port.enabled) {
        commands.add(' shutdown');
      } else {
        commands.add(' no shutdown');
      }

      commands.add('exit');
    }
    commands.add('');

    return commands;
  }

  List<String> _generateSwitchportCommands(Switchport port) {
    final commands = <String>[];

    // Switchport mode - only output if not default (access mode with VLAN 1)
    if (port.mode == SwitchportMode.trunk) {
      commands.add(' switchport mode trunk');
      if (port.nativeVlan != null) {
        commands.add(' switchport trunk native vlan ${port.nativeVlan}');
      }
      if (port.allowedVlans != null && port.allowedVlans!.isNotEmpty) {
        commands.add(' switchport trunk allowed vlan ${port.allowedVlans}');
      }
    } else if (port.vlan != 1) {
      // Access mode with non-default VLAN
      commands.add(' switchport mode access');
      commands.add(' switchport access vlan ${port.vlan}');
    }

    // Protected port
    if (port.protectedPort) {
      commands.add(' switchport protected');
    }

    // Port security
    if (port.portSecurityEnabled) {
      commands.add(' switchport port-security');
      commands.add(
        ' switchport port-security maximum ${port.portSecurityMaximum}',
      );
      commands.add(
        ' switchport port-security violation ${port.portSecurityViolation.name}',
      );
      if (port.portSecuritySticky) {
        commands.add(' switchport port-security mac-address sticky');
      }
      if (port.portSecurityMacAddresses != null) {
        for (final mac in port.portSecurityMacAddresses!) {
          commands.add(' switchport port-security mac-address $mac');
        }
      }
    }

    // Spanning tree
    if (port.spanningTreePortfast) {
      commands.add(' spanning-tree portfast');
    }
    if (port.spanningTreeBpduGuard) {
      commands.add(' spanning-tree bpduguard enable');
    }
    if (port.spanningTreeBpduFilter) {
      commands.add(' spanning-tree bpdufilter enable');
    }
    if (port.spanningTreeCost != null) {
      commands.add(' spanning-tree cost ${port.spanningTreeCost}');
    }
    if (port.spanningTreePortPriority != null) {
      commands.add(
        ' spanning-tree port-priority ${port.spanningTreePortPriority}',
      );
    }
    if (port.spanningTreeGuard != SpanningTreeGuard.none) {
      commands.add(' spanning-tree guard ${port.spanningTreeGuard.name}');
    }

    // Channel group
    if (port.channelGroup != null) {
      commands.add(' channel-group ${port.channelGroup} mode active');
    }

    return commands;
  }

  List<String> _generateRouterPortCommands(Port port) {
    final commands = <String>[];

    if (port.ipAssignment == IpAssignmentMode.dhcp) {
      commands.add(' ip address dhcp');
    } else if (port.ipAddress != null) {
      commands.add(
        ' ip address ${port.ipAddress!.address} ${port.ipAddress!.subnetMask}',
      );
    }

    if (port.ipv4HelperAddress != null && port.ipv4HelperAddress!.isNotEmpty) {
      commands.add(' ip helper-address ${port.ipv4HelperAddress}');
    }

    if (port.dhcpRelayInformation == DhcpRelayInformationMode.trusted) {
      commands.add(' ip dhcp relay information trusted');
    }

    if (port.ipv6Assignment == Ipv6AssignmentMode.automatic) {
      commands.add(' ipv6 address autoconfig');
    } else if (port.ipv6Address != null) {
      commands.add(' ipv6 address ${port.ipv6Address!.toCIDR()}');
    }

    if (port.ipv4AccessGroupIn != null && port.ipv4AccessGroupIn!.isNotEmpty) {
      commands.add(' ip access-group ${port.ipv4AccessGroupIn} in');
    }

    if (port.ipv4AccessGroupOut != null &&
        port.ipv4AccessGroupOut!.isNotEmpty) {
      commands.add(' ip access-group ${port.ipv4AccessGroupOut} out');
    }

    return commands;
  }

  // ===========================================================================
  // Channel Group (EtherChannel) Configuration
  // ===========================================================================

  List<String> _generateChannelGroupCommands() {
    final commands = <String>[];
    final channelGroups = device.channelGroups;

    if (channelGroups.isEmpty) return commands;

    commands.add('! ===== Port-Channels =====');
    for (final group in channelGroups) {
      commands.add('interface Port-channel${group.groupNumber}');

      // Always trunk mode for port-channels
      commands.add(' switchport mode trunk');
      commands.add(' switchport trunk native vlan ${group.nativeVlan}');
      if (group.allowedVlans.isNotEmpty && group.allowedVlans != 'all') {
        commands.add(' switchport trunk allowed vlan ${group.allowedVlans}');
      }

      commands.add('exit');
    }
    commands.add('');

    return commands;
  }

  // ===========================================================================
  // Static Route Configuration
  // ===========================================================================

  List<String> _generateStaticRouteCommands() {
    final commands = <String>[];
    final routes = device.staticRoutes;

    if (routes.isEmpty) return commands;

    commands.add('! ===== Static Routes =====');
    for (final route in routes) {
      if (!route.enabled) continue;

      // Parse destination from CIDR format
      var destination = route.destinationNetwork;
      if (destination.contains('/')) {
        final parts = destination.split('/');
        final prefix = int.tryParse(parts[1]) ?? 24;
        destination = '${parts[0]} ${_cidrToMask(prefix)}';
      }

      var cmd = 'ip route $destination';

      if (route.nextHop != null) {
        cmd += ' ${route.nextHop}';
      }
      if (route.exitInterface != null) {
        cmd += ' ${route.exitInterface}';
      }
      if (route.adminDistance != null) {
        cmd += ' ${route.adminDistance}';
      }
      if (route.name != null) {
        cmd += ' name ${route.name}';
      }

      commands.add(cmd);
    }
    commands.add('');

    return commands;
  }

  /// Convert CIDR prefix to subnet mask
  String _cidrToMask(int prefix) {
    final mask = (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    return '${(mask >> 24) & 0xFF}.${(mask >> 16) & 0xFF}.${(mask >> 8) & 0xFF}.${mask & 0xFF}';
  }

  // ===========================================================================
  // ACL Configuration
  // ===========================================================================

  List<String> _generateAclCommands() {
    final commands = <String>[];
    final acls = device.acls;

    if (acls.isEmpty) return commands;

    commands.add('! ===== Access Control Lists =====');
    for (final acl in acls) {
      if (!acl.enabled) continue;

      if (acl.isNamed) {
        commands.add('ip access-list ${acl.type.name} ${acl.name}');
        for (final entry in acl.entries) {
          if (!entry.enabled) continue;
          commands.add(' ${_formatAclEntry(entry, acl.type)}');
        }
        commands.add('exit');
      } else if (acl.number != null) {
        for (final entry in acl.entries) {
          if (!entry.enabled) continue;
          commands.add(
            'access-list ${acl.number} ${_formatAclEntry(entry, acl.type)}',
          );
        }
      }
    }
    commands.add('');

    return commands;
  }

  String _formatAclEntry(AclEntry entry, AclType aclType) {
    if (entry.remark != null && entry.remark!.isNotEmpty) {
      return 'remark ${entry.remark}';
    }

    var cmd = entry.action.name;

    // For extended ACLs, add protocol
    if (aclType == AclType.extended) {
      cmd += ' ${entry.protocol.name}';
    }

    // Source
    if (entry.sourceAddress.toLowerCase() == 'any') {
      cmd += ' any';
    } else {
      cmd += ' ${entry.sourceAddress}';
      if (entry.sourceWildcard != null) {
        cmd += ' ${entry.sourceWildcard}';
      }
    }

    // Destination (extended ACL only)
    if (aclType == AclType.extended && entry.destAddress != null) {
      if (entry.destAddress!.toLowerCase() == 'any') {
        cmd += ' any';
      } else {
        cmd += ' ${entry.destAddress}';
        if (entry.destWildcard != null) {
          cmd += ' ${entry.destWildcard}';
        }
      }
    }

    // Port operators for TCP/UDP
    if (entry.destPortOperator != null && entry.destPort != null) {
      cmd += ' ${entry.destPortOperator!.name} ${entry.destPort}';
      if (entry.destPortOperator == AclPortOperator.range &&
          entry.destPortEnd != null) {
        cmd += ' ${entry.destPortEnd}';
      }
    }

    if (entry.log) {
      cmd += ' log';
    }

    return cmd;
  }

  // ===========================================================================
  // DHCP Pool Configuration
  // ===========================================================================

  List<String> _generateDhcpPoolCommands() {
    final commands = <String>[];
    final pools = device.dhcpPools;

    if (pools.isEmpty) return commands;

    commands.add('! ===== DHCP Pools =====');
    commands.add('service dhcp');

    // Excluded addresses first
    for (final pool in pools) {
      if (!pool.enabled) continue;
      if (pool.excludeStart != null && pool.excludeEnd != null) {
        commands.add(
          'ip dhcp excluded-address ${pool.excludeStart} ${pool.excludeEnd}',
        );
      } else if (pool.excludeStart != null) {
        commands.add('ip dhcp excluded-address ${pool.excludeStart}');
      }
    }

    for (final pool in pools) {
      if (!pool.enabled) continue;

      commands.add('ip dhcp pool ${pool.name}');
      commands.add(' network ${pool.network} ${pool.subnetMask}');
      if (pool.defaultRouter != null) {
        commands.add(' default-router ${pool.defaultRouter}');
      }
      if (pool.dnsServer != null) {
        var dnsCmd = ' dns-server ${pool.dnsServer}';
        if (pool.dnsServerSecondary != null) {
          dnsCmd += ' ${pool.dnsServerSecondary}';
        }
        commands.add(dnsCmd);
      }
      if (pool.domainName != null) {
        commands.add(' domain-name ${pool.domainName}');
      }
      // Convert seconds to days hours minutes
      final leaseSeconds = pool.leaseTime;
      final days = leaseSeconds ~/ 86400;
      final hours = (leaseSeconds % 86400) ~/ 3600;
      final minutes = (leaseSeconds % 3600) ~/ 60;
      if (days > 0 || hours > 0 || minutes > 0) {
        commands.add(' lease $days $hours $minutes');
      }
      commands.add('exit');
    }
    commands.add('');

    return commands;
  }

  // ===========================================================================
  // NAT Configuration
  // ===========================================================================

  List<String> _generateNatCommands() {
    final commands = <String>[];
    final natRules = device.natRules;

    if (natRules.isEmpty) return commands;

    commands.add('! ===== NAT Configuration =====');
    for (final rule in natRules) {
      if (!rule.enabled) continue;

      switch (rule.type) {
        case NatType.staticNat:
          if (rule.insideLocal != null && rule.insideGlobal != null) {
            commands.add(
              'ip nat inside source static ${rule.insideLocal} ${rule.insideGlobal}',
            );
          }
        case NatType.dynamicNat:
          // Create pool first
          if (rule.poolName != null &&
              rule.poolStart != null &&
              rule.poolEnd != null) {
            var poolCmd =
                'ip nat pool ${rule.poolName} ${rule.poolStart} ${rule.poolEnd}';
            if (rule.poolNetmask != null) {
              poolCmd += ' netmask ${rule.poolNetmask}';
            }
            commands.add(poolCmd);
          }
          if (rule.poolName != null && rule.aclNumber != null) {
            commands.add(
              'ip nat inside source list ${rule.aclNumber} pool ${rule.poolName}',
            );
          }
        case NatType.pat:
          // Create pool if specified
          if (rule.poolName != null &&
              rule.poolStart != null &&
              rule.poolEnd != null) {
            var poolCmd =
                'ip nat pool ${rule.poolName} ${rule.poolStart} ${rule.poolEnd}';
            if (rule.poolNetmask != null) {
              poolCmd += ' netmask ${rule.poolNetmask}';
            }
            commands.add(poolCmd);
            if (rule.aclNumber != null) {
              commands.add(
                'ip nat inside source list ${rule.aclNumber} pool ${rule.poolName} overload',
              );
            }
          } else if (rule.useInterfaceOverload &&
              rule.outsideInterface != null) {
            if (rule.aclNumber != null) {
              commands.add(
                'ip nat inside source list ${rule.aclNumber} interface ${rule.outsideInterface} overload',
              );
            }
          }
        case NatType.staticPat:
          if (rule.insideLocal != null &&
              rule.insideGlobal != null &&
              rule.protocol != null &&
              rule.localPort != null &&
              rule.globalPort != null) {
            commands.add(
              'ip nat inside source static ${rule.protocol} ${rule.insideLocal} ${rule.localPort} ${rule.insideGlobal} ${rule.globalPort}',
            );
          }
      }
    }
    commands.add('');

    return commands;
  }

  // ===========================================================================
  // Tunnel Configuration
  // ===========================================================================

  List<String> _generateTunnelCommands() {
    final commands = <String>[];
    final tunnels = device.tunnels;

    if (tunnels.isEmpty) return commands;

    commands.add('! ===== Tunnels =====');
    for (final tunnel in tunnels) {
      if (!tunnel.enabled) continue;

      commands.add('interface Tunnel${tunnel.tunnelNumber}');
      if (tunnel.description.isNotEmpty) {
        commands.add(' description ${tunnel.description}');
      }
      if (tunnel.tunnelIpAddress != null) {
        // Parse IP from CIDR if needed
        final ip = tunnel.tunnelIpAddress!;
        if (ip.contains('/')) {
          final parts = ip.split('/');
          final prefix = int.tryParse(parts[1]) ?? 30;
          commands.add(' ip address ${parts[0]} ${_cidrToMask(prefix)}');
        } else {
          commands.add(' ip address $ip');
        }
      }
      if (tunnel.tunnelSource != null) {
        commands.add(' tunnel source ${tunnel.tunnelSource}');
      }
      if (tunnel.tunnelDestination != null) {
        commands.add(' tunnel destination ${tunnel.tunnelDestination}');
      }
      if (tunnel.mtu != null) {
        commands.add(' ip mtu ${tunnel.mtu}');
      }

      // Tunnel mode based on type
      switch (tunnel.type) {
        case TunnelType.gre:
          commands.add(' tunnel mode gre ip');
        case TunnelType.ipsec:
          commands.add(' tunnel mode ipsec ipv4');
          if (tunnel.cryptoMapName != null) {
            commands.add(' crypto map ${tunnel.cryptoMapName}');
          }
        case TunnelType.greOverIpsec:
          commands.add(' tunnel mode gre ip');
          commands.add(
            ' tunnel protection ipsec profile ${tunnel.transformSetName ?? "IPSEC_PROFILE"}',
          );
        case TunnelType.pppoe:
          commands.add(' encapsulation ppp');
          if (tunnel.dialerPoolNumber != null) {
            commands.add(' dialer pool ${tunnel.dialerPoolNumber}');
          }
      }

      if (tunnel.keepaliveInterval != null && tunnel.keepaliveRetries != null) {
        commands.add(
          ' keepalive ${tunnel.keepaliveInterval} ${tunnel.keepaliveRetries}',
        );
      }

      commands.add(' no shutdown');
      commands.add('exit');
    }
    commands.add('');

    return commands;
  }

  // ===========================================================================
  // HSRP Configuration (Project-level)
  // ===========================================================================

  List<String> _generateHsrpCommands() {
    final commands = <String>[];
    final props = projectProperties;
    if (props == null) return commands;

    // Find HSRP groups where this device is a member
    final deviceHsrpGroups = <HsrpGroup>[];
    for (final group in props.hsrpGroups) {
      if (!group.enabled) continue;
      final member = group.members
          .where((m) => m.deviceId == device.id)
          .firstOrNull;
      if (member != null) {
        deviceHsrpGroups.add(group);
      }
    }

    if (deviceHsrpGroups.isEmpty) return commands;

    commands.add('! ===== HSRP Configuration =====');
    for (final group in deviceHsrpGroups) {
      final member = group.members.firstWhere((m) => m.deviceId == device.id);

      commands.add('interface ${member.interfaceName}');
      commands.add(' standby version ${group.version}');
      if (group.virtualIp != null) {
        commands.add(' standby ${group.groupNumber} ip ${group.virtualIp}');
      }
      commands.add(' standby ${group.groupNumber} priority ${member.priority}');
      if (member.preempt) {
        commands.add(' standby ${group.groupNumber} preempt');
      }
      if (group.helloTimer != 3 || group.holdTimer != 10) {
        commands.add(
          ' standby ${group.groupNumber} timers ${group.helloTimer} ${group.holdTimer}',
        );
      }
      if (group.authenticationKey != null) {
        commands.add(
          ' standby ${group.groupNumber} authentication ${group.authenticationKey}',
        );
      }
      if (member.trackInterface != null && member.trackDecrement != null) {
        commands.add(
          ' standby ${group.groupNumber} track ${member.trackInterface} decrement ${member.trackDecrement}',
        );
      }
      commands.add('exit');
    }
    commands.add('');

    return commands;
  }

  // ===========================================================================
  // OSPF Configuration (Project-level)
  // ===========================================================================

  List<String> _generateOspfCommands() {
    final commands = <String>[];
    final props = projectProperties;
    if (props == null) return commands;

    for (final domain in props.ospfDomains) {
      if (!domain.enabled) continue;

      // Find if this device is a member of this OSPF domain
      final member = domain.members
          .where((m) => m.deviceId == device.id)
          .firstOrNull;
      if (member == null) continue;

      commands.add('! ===== OSPF Process ${domain.processId} =====');
      commands.add('router ospf ${domain.processId}');

      if (member.routerId != null) {
        commands.add(' router-id ${member.routerId}');
      }

      if (domain.referenceBandwidth != null) {
        commands.add(
          ' auto-cost reference-bandwidth ${domain.referenceBandwidth}',
        );
      }

      // Network statements
      for (final network in member.networks) {
        commands.add(
          ' network ${network.network} ${network.wildcardMask} area ${network.areaId}',
        );
      }

      // Passive interfaces
      for (final config in member.interfaceConfigs) {
        if (config.passive) {
          commands.add(' passive-interface ${config.interfaceName}');
        }
      }

      // Default information originate
      if (member.defaultInformationOriginate) {
        if (member.defaultInformationAlways) {
          commands.add(' default-information originate always');
        } else {
          commands.add(' default-information originate');
        }
      }

      // Area configurations
      for (final area in domain.areas) {
        switch (area.type) {
          case OspfAreaType.stub:
            if (area.noSummary) {
              commands.add(' area ${area.areaId} stub no-summary');
            } else {
              commands.add(' area ${area.areaId} stub');
            }
            if (area.defaultCost != null) {
              commands.add(
                ' area ${area.areaId} default-cost ${area.defaultCost}',
              );
            }
          case OspfAreaType.nssa:
            if (area.noSummary) {
              commands.add(' area ${area.areaId} nssa no-summary');
            } else {
              commands.add(' area ${area.areaId} nssa');
            }
          case OspfAreaType.normal:
          case OspfAreaType.totallyStub:
          case OspfAreaType.totallyNssa:
            // totallyStub and totallyNssa are handled by noSummary flag
            break;
        }
      }

      commands.add('exit');

      // Interface-specific OSPF configurations
      for (final config in member.interfaceConfigs) {
        if (config.cost != null ||
            config.priority != null ||
            config.helloInterval != null ||
            config.deadInterval != null ||
            config.networkType != null ||
            config.authenticationKey != null) {
          commands.add('interface ${config.interfaceName}');

          if (config.cost != null) {
            commands.add(' ip ospf cost ${config.cost}');
          }
          if (config.priority != null) {
            commands.add(' ip ospf priority ${config.priority}');
          }
          if (config.helloInterval != null) {
            commands.add(' ip ospf hello-interval ${config.helloInterval}');
          }
          if (config.deadInterval != null) {
            commands.add(' ip ospf dead-interval ${config.deadInterval}');
          }
          if (config.networkType != null) {
            commands.add(
              ' ip ospf network ${_ospfNetworkTypeName(config.networkType!)}',
            );
          }
          if (config.authenticationKey != null) {
            if (config.authType == OspfAuthType.md5) {
              commands.add(' ip ospf authentication message-digest');
              commands.add(
                ' ip ospf message-digest-key 1 md5 ${config.authenticationKey}',
              );
            } else if (config.authType == OspfAuthType.plaintext) {
              commands.add(' ip ospf authentication');
              commands.add(
                ' ip ospf authentication-key ${config.authenticationKey}',
              );
            }
          }

          commands.add('exit');
        }
      }

      commands.add('');
    }

    return commands;
  }

  String _ospfNetworkTypeName(OspfNetworkType type) {
    switch (type) {
      case OspfNetworkType.broadcast:
        return 'broadcast';
      case OspfNetworkType.pointToPoint:
        return 'point-to-point';
      case OspfNetworkType.pointToMultipoint:
        return 'point-to-multipoint';
      case OspfNetworkType.nonBroadcast:
        return 'non-broadcast';
    }
  }

  // ===========================================================================
  // EIGRP Configuration (Project-level)
  // ===========================================================================

  List<String> _generateEigrpCommands() {
    final commands = <String>[];
    final props = projectProperties;
    if (props == null) return commands;

    for (final domain in props.eigrpDomains) {
      if (!domain.enabled) continue;

      // Find if this device is a member of this EIGRP domain
      final member = domain.members
          .where((m) => m.deviceId == device.id)
          .firstOrNull;
      if (member == null) continue;

      commands.add('! ===== EIGRP AS ${domain.asNumber} =====');
      commands.add('router eigrp ${domain.asNumber}');

      if (member.routerId != null) {
        commands.add(' eigrp router-id ${member.routerId}');
      }

      if (!member.autoSummary) {
        commands.add(' no auto-summary');
      }

      // Network statements
      for (final network in member.networks) {
        commands.add(' network $network');
      }

      // Passive interfaces
      for (final iface in member.passiveInterfaces) {
        commands.add(' passive-interface $iface');
      }

      commands.add('exit');
      commands.add('');
    }

    return commands;
  }

  // ===========================================================================
  // BGP Configuration (Project-level)
  // ===========================================================================

  List<String> _generateBgpCommands() {
    final commands = <String>[];
    final props = projectProperties;
    if (props == null) return commands;

    for (final domain in props.bgpDomains) {
      if (!domain.enabled) continue;

      // Find if this device is a member of this BGP domain
      final member = domain.members
          .where((m) => m.deviceId == device.id)
          .firstOrNull;
      if (member == null) continue;

      commands.add('! ===== BGP AS ${domain.asNumber} =====');
      commands.add('router bgp ${domain.asNumber}');

      if (member.routerId != null) {
        commands.add(' bgp router-id ${member.routerId}');
      }

      if (!member.synchronization) {
        commands.add(' no synchronization');
      }

      if (!member.autoSummary) {
        commands.add(' no auto-summary');
      }

      // Networks to advertise
      for (final bgpNetwork in member.networks) {
        var networkCmd = ' network ${bgpNetwork.network}';
        if (bgpNetwork.mask != null) {
          networkCmd += ' mask ${bgpNetwork.mask}';
        }
        if (bgpNetwork.routeMap != null) {
          networkCmd += ' route-map ${bgpNetwork.routeMap}';
        }
        commands.add(networkCmd);
      }

      // Neighbors
      for (final neighbor in member.neighbors) {
        if (!neighbor.enabled) continue;

        commands.add(
          ' neighbor ${neighbor.neighborAddress} remote-as ${neighbor.remoteAs}',
        );
        if (neighbor.description != null) {
          commands.add(
            ' neighbor ${neighbor.neighborAddress} description ${neighbor.description}',
          );
        }
        if (neighbor.updateSource != null) {
          commands.add(
            ' neighbor ${neighbor.neighborAddress} update-source ${neighbor.updateSource}',
          );
        }
        if (neighbor.ebgpMultihop && neighbor.ebgpMultihopTtl != null) {
          commands.add(
            ' neighbor ${neighbor.neighborAddress} ebgp-multihop ${neighbor.ebgpMultihopTtl}',
          );
        }
        if (neighbor.password != null) {
          commands.add(
            ' neighbor ${neighbor.neighborAddress} password ${neighbor.password}',
          );
        }
        if (neighbor.nextHopSelf) {
          commands.add(' neighbor ${neighbor.neighborAddress} next-hop-self');
        }
        if (neighbor.routeReflectorClient) {
          commands.add(
            ' neighbor ${neighbor.neighborAddress} route-reflector-client',
          );
        }
        if (neighbor.softReconfigurationInbound) {
          commands.add(
            ' neighbor ${neighbor.neighborAddress} soft-reconfiguration inbound',
          );
        }
      }

      // Redistribution
      for (final protocol in member.redistributeProtocols) {
        commands.add(' redistribute $protocol');
      }

      commands.add('exit');
      commands.add('');
    }

    return commands;
  }

  // ===========================================================================
  // Project-level Static Routes
  // ===========================================================================

  List<String> _generateProjectStaticRouteCommands() {
    final commands = <String>[];
    final props = projectProperties;
    if (props == null) return commands;

    // Find static routes that apply to this device
    final deviceRoutes = props.staticRoutes
        .where((r) => r.deviceId == device.id)
        .toList();

    if (deviceRoutes.isEmpty) return commands;

    commands.add('! ===== Project Static Routes =====');
    for (final route in deviceRoutes) {
      if (!route.enabled) continue;

      // Parse destination from CIDR format
      var destination = route.destinationNetwork;
      if (destination.contains('/')) {
        final parts = destination.split('/');
        final prefix = int.tryParse(parts[1]) ?? 24;
        destination = '${parts[0]} ${_cidrToMask(prefix)}';
      }

      var cmd = 'ip route $destination';

      if (route.nextHop != null) {
        cmd += ' ${route.nextHop}';
      }
      if (route.exitInterface != null) {
        cmd += ' ${route.exitInterface}';
      }
      if (route.adminDistance != null) {
        cmd += ' ${route.adminDistance}';
      }

      commands.add(cmd);
    }
    commands.add('');

    return commands;
  }
}
