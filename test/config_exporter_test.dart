import 'package:flutter_test/flutter_test.dart';
import 'package:ktracer_center/devices/device_preset.dart';
import 'package:ktracer_center/network/port.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:ktracer_center/utils/config_exporter.dart';

void main() {
  group('Port IPv4 assignment', () {
    test('defaults to static assignment when no mode is stored', () {
      final port = Port.fromJson({'name': 'FastEthernet 0/0'});

      expect(port.ipAssignment, IpAssignmentMode.staticAddress);
    });

    test('parses and serializes DHCP assignment mode', () {
      final port = Port.fromJson({
        'name': 'FastEthernet 0/0',
        'ip_assignment': 'dhcp',
      });

      expect(port.ipAssignment, IpAssignmentMode.dhcp);
      expect(port.toJson()['ip_assignment'], 'dhcp');
    });
  });

  group('Port IPv6 assignment', () {
    test('defaults to static assignment when no mode is stored', () {
      final port = Port.fromJson({'name': 'FastEthernet 0/0'});

      expect(port.ipv6Assignment, Ipv6AssignmentMode.staticAddress);
    });

    test('parses and serializes automatic assignment mode', () {
      final port = Port.fromJson({
        'name': 'FastEthernet 0/0',
        'ipv6_assignment': 'automatic',
      });

      expect(port.ipv6Assignment, Ipv6AssignmentMode.automatic);
      expect(port.toJson()['ipv6_assignment'], 'automatic');
    });
  });

  group('Port DHCP relay fields', () {
    test('parses and serializes IPv4 helper address', () {
      final port = Port.fromJson({
        'name': 'FastEthernet 0/0',
        'ipv4HelperAddress': '10.10.10.10',
      });

      expect(port.ipv4HelperAddress, '10.10.10.10');
      expect(port.toJson()['ipv4HelperAddress'], '10.10.10.10');
    });

    test('parses and serializes DHCP relay information mode', () {
      final port = Port.fromJson({
        'name': 'FastEthernet 0/0',
        'dhcpRelayInformation': 'trusted',
      });

      expect(port.dhcpRelayInformation, DhcpRelayInformationMode.trusted);
      expect(port.toJson()['dhcpRelayInformation'], 'trusted');
    });
  });

  group('ConfigExporter', () {
    test('exports ip address dhcp for DHCP-assigned routed ports', () {
      final device = NetDevice(
        id: 1,
        projectId: 1,
        presetId: DevicePresets.i2811.id,
        config: {
          'hostname': 'R1',
          'ports': [
            {
              'name': 'FastEthernet 0/0',
              'enabled': true,
              'is_switchport': false,
              'ip_assignment': 'dhcp',
            },
          ],
        },
      );

      final commands = ConfigExporter(device: device).generateCommands();

      expect(commands, contains('interface FastEthernet 0/0'));
      expect(commands, contains(' ip address dhcp'));
    });

    test('prefers DHCP export over any stale static IPv4 value', () {
      final device = NetDevice(
        id: 1,
        projectId: 1,
        presetId: DevicePresets.i2811.id,
        config: {
          'hostname': 'R1',
          'ports': [
            {
              'name': 'FastEthernet 0/0',
              'enabled': true,
              'is_switchport': false,
              'ip_assignment': 'dhcp',
              'ip_cidr': '10.0.0.1/24',
            },
          ],
        },
      );

      final commands = ConfigExporter(device: device).generateCommands();

      expect(commands, contains(' ip address dhcp'));
      expect(
        commands.where((command) => command.contains(' ip address 10.0.0.1')),
        isEmpty,
      );
    });

    test('exports ipv6 address autoconfig for automatic IPv6 ports', () {
      final device = NetDevice(
        id: 1,
        projectId: 1,
        presetId: DevicePresets.i2811.id,
        config: {
          'hostname': 'R1',
          'ports': [
            {
              'name': 'FastEthernet 0/0',
              'enabled': true,
              'is_switchport': false,
              'ipv6_assignment': 'automatic',
            },
          ],
        },
      );

      final commands = ConfigExporter(device: device).generateCommands();

      expect(commands, contains('interface FastEthernet 0/0'));
      expect(commands, contains(' ipv6 address autoconfig'));
    });

    test('prefers automatic IPv6 export over any stale static IPv6 value', () {
      final device = NetDevice(
        id: 1,
        projectId: 1,
        presetId: DevicePresets.i2811.id,
        config: {
          'hostname': 'R1',
          'ports': [
            {
              'name': 'FastEthernet 0/0',
              'enabled': true,
              'is_switchport': false,
              'ipv6_assignment': 'automatic',
              'ipv6_cidr': '2001:db8::1/64',
            },
          ],
        },
      );

      final commands = ConfigExporter(device: device).generateCommands();

      expect(commands, contains(' ipv6 address autoconfig'));
      expect(
        commands.where(
          (command) => command.contains(' ipv6 address 2001:db8::1/64'),
        ),
        isEmpty,
      );
    });

    test(
      'exports helper-address and trusted relay information for routed ports',
      () {
        final device = NetDevice(
          id: 1,
          projectId: 1,
          presetId: DevicePresets.i2811.id,
          config: {
            'hostname': 'R1',
            'ports': [
              {
                'name': 'FastEthernet 0/0',
                'enabled': true,
                'is_switchport': false,
                'ip_cidr': '192.168.1.1/24',
                'ipv4HelperAddress': '10.10.10.10',
                'dhcpRelayInformation': 'trusted',
              },
            ],
          },
        );

        final commands = ConfigExporter(device: device).generateCommands();

        expect(commands, contains(' ip helper-address 10.10.10.10'));
        expect(commands, contains(' ip dhcp relay information trusted'));
      },
    );

    test('exports ipv4 default gateway for switches', () {
      final device = NetDevice(
        id: 1,
        projectId: 1,
        presetId: DevicePresets.c2960.id,
        config: {'hostname': 'SW1', 'default_gateway_ipv4': '192.168.1.1'},
      );

      final commands = ConfigExporter(device: device).generateCommands();

      expect(commands, contains('ip default-gateway 192.168.1.1'));
    });

    test('does not export ipv4 default gateway for routers', () {
      final device = NetDevice(
        id: 1,
        projectId: 1,
        presetId: DevicePresets.i2811.id,
        config: {'hostname': 'R1', 'default_gateway_ipv4': '192.168.1.1'},
      );

      final commands = ConfigExporter(device: device).generateCommands();

      expect(commands, isNot(contains('ip default-gateway 192.168.1.1')));
    });
  });
}
