import 'package:ktracer_center/network/ipv4.dart';
import 'package:ktracer_center/network/ipv6.dart';

class Vlan {
  int id;
  int vlanId;
  String name;
  String? description;
  bool enabled;
  IPv4? ipAddress;
  IPv6? ipv6Address;

  Vlan({
    required this.id,
    required this.vlanId,
    required this.name,
    this.description,
    this.enabled = true,
    this.ipAddress,
    this.ipv6Address,
  });
}
