Implement this project config:
FW1 and FW2 both connect to the internet, on Gig1/1, make them DHCP
Use subnets for
vlan 10, 192.168.10.0/24
vlan 20 192.168.20.0/24
vlan 80 192.168.88.0/24 (Management, you cannot modify this)
S1 and S2 should have pagp on f0/10-11
Server connection on f0/20-21
Wireless router connection on f0/22
f0/1 is towards the FWs
f0/2-16 are devices, use portsecurity
Make the FWs have HSRP and DHCP on the subinterfaces

Verify the config for the project with this structure:
Telephely 1:
FW1 and FW2 both connect to the internet, on Gig1/1, make them DHCP
Use subnets for
vlan 10, 192.168.10.0/24
vlan 20 192.168.20.0/24
vlan 80 192.168.88.0/24 (Management, you cannot modify this)
S1 and S2 should have pagp on f0/10-11
Server connection on f0/20-21
Wireless router connection on f0/22
f0/1 is towards the FWs
f0/2-16 are devices, use portsecurity
Make the FWs have HSRP and DHCP on the subinterfaces
Add PAT towards internet to work on vlan 10 and 20
Telephely 2:
2x 2811s, both with DHCP from internet on f0/2, and PAT towards there too
static NAT for server (HTTP, Radius, FTP servers)
2x 2950 switches, f0/10-11 as PAGP
f0/1 of router -> f0/1 of switch
f0/16, 17 of switch -> server (2 for redundancy)
Telephely 3:
2x 2811, f0/1 with dhcp towards internet with PAT
Static nat for radius towards wireless router (192.168.100.1/24 and .2/24)
2x 2950 with f0/10-11 pagp
f0/2 of switches go to wireless router

tunnel between Telephely 1 & 2