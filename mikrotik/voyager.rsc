# 2026-10-26 19:26:23 by RouterOS 7.25
# software id = T30K-L6UC
#
# model = RBM33G
# serial number = HCK086HNW9H
#
##################################################################################################
# Generic
##################################################################################################
# Identity
/system identity set name=voyager

# Time
/system clock set time-zone-name=Europe/Sofia
/system ntp client set enabled=yes
/system ntp client servers
add address=1.bg.pool.ntp.org
add address=2.bg.pool.ntp.org

# Services
/ip service
set ftp disabled=yes
set telnet disabled=yes
set api disabled=yes
set api-ssl disabled=yes

# IPv6
/ipv6 settings set disable-ipv6=yes max-neighbor-entries=8192

# SSH
/ip ssh set known-hosts-validation=no

# DNS
/ip dns set servers=8.8.8.8
/ip cloud set ddns-enabled=yes ddns-update-interval=5m update-time=no

# SNMP
/snmp set enabled=yes

# DHCP
/ip dhcp-server network add address=10.7.0.0/24 dns-server=8.8.8.8 gateway=10.7.0.1

# Samba
/ip smb users set [ find default=yes ] disabled=yes

# Scheduler
/system scheduler add !days interval=1w name=reboot on-event="/system reboot" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-date=2026-01-01 start-time=03:00:00

##################################################################################################
# Ethernet
##################################################################################################
# Ports
/interface ethernet
set [ find default-name=ether1 ] name=eth1
set [ find default-name=ether2 ] name=eth2
set [ find default-name=ether3 ] name=eth3

# Bridges
/interface bridge
add name=external port-cost-mode=short
add name=internal port-cost-mode=short
add name=loopback port-cost-mode=short
/interface bridge port
add bridge=external ingress-filtering=no interface=eth1 internal-path-cost=10 path-cost=10
add bridge=internal ingress-filtering=no interface=eth2 internal-path-cost=10 path-cost=10
add bridge=internal ingress-filtering=no interface=eth3 internal-path-cost=10 path-cost=10

# Addresses
/ip address
add address=10.7.0.1/24 interface=internal network=10.7.0.0
add address=10.0.0.7/16 interface=loopback network=10.0.0.0
add address=172.16.0.100/24 interface=external network=172.16.0.0
add address=192.168.0.100/24 interface=external network=192.168.0.0

# DHCP Client 
/ip dhcp-client add !dhcp-options interface=external name=external

# DHCP Server
/ip pool add name=internal ranges=10.7.0.192-10.7.0.254
/ip dhcp-server add address-pool=internal interface=internal lease-time=60m name=internal
# Network(Routers-switches-APs-networkServers) 1-29
# Servers 30-99
/ip dhcp-server lease add comment=NAS address=10.7.0.30 mac-address=00:11:32:96:CE:41 server=internal
/ip dhcp-server lease add comment=k3s01 address=10.7.0.71 mac-address=2C:CF:67:5C:C8:35 server=internal
/ip dhcp-server lease add comment=k3s02 address=10.7.0.72 mac-address=D8:3A:DD:E4:09:18 server=internal
/ip dhcp-server lease add comment=k3s03 address=10.7.0.73 mac-address=2C:CF:67:13:8B:11 server=internal
# Sensors 100-180
/ip dhcp-server lease add comment=shelly-ht-f0-1 address=10.7.0.100 mac-address=08:3A:F2:D0:C6:A4 server=internal
/ip dhcp-server lease add comment=shelly-ht-f1-1 address=10.7.0.101 mac-address=08:3A:F2:D0:C6:A4 server=internal
/ip dhcp-server lease add comment=shelly-ht-f2-1 address=10.7.0.102 mac-address=08:3A:F2:D1:35:C4 server=internal
# /ip dhcp-server lease add comment=bitcoin address=10.7.0.80 mac-address=2C:CF:67:13:8B:11 server=internal

##################################################################################################
# Firewall
##################################################################################################
# Basics
/ip firewall connection tracking set udp-timeout=10s
/ip firewall address-list
add address=10.0.0.0/8 list=internal
add address=172.16.0.0/12 list=internal
add address=192.168.0.0/16 list=internal

# Access
/ip firewall filter
add action=accept chain=input comment="Management" disabled=yes in-interface=external protocol=icmp
add action=accept chain=input dst-port=8291 in-interface=!external protocol=tcp 
add action=accept chain=input dst-port=22 in-interface=!external protocol=tcp
add action=accept chain=input protocol=icmp
add action=accept chain=output
add action=log chain=forward comment="External" disabled=yes protocol=icmp
add action=accept chain=forward connection-state=new dst-port=8333 in-interface=external log=yes protocol=tcp
add action=log chain=forward comment="Internal" disabled=yes protocol=icmp
add action=accept chain=forward in-interface=!external protocol=icmp src-address-list=internal
add action=accept chain=forward connection-state=new in-interface=!external protocol=tcp src-address-list=internal
add action=accept chain=forward connection-state=new in-interface=!external protocol=udp src-address-list=internal
add action=log chain=output comment="Running" disabled=yes
add action=accept chain=input connection-state=established,related
add action=fasttrack-connection chain=forward connection-state=established,related
add action=log chain=output comment="DROP" disabled=yes protocol=icmp
add action=drop chain=input in-interface=external

# NAT
/ip firewall nat
add action=accept chain=srcnat comment=internal-to-internal dst-address-list=internal src-address-list=internal
add action=dst-nat chain=dstnat comment=external-to-bitcoin dst-port=8333 in-interface=external protocol=tcp to-addresses=10.7.0.253
add action=masquerade chain=srcnat comment=internal-to-external out-interface=external

##################################################################################################
# VPN WireGuards
##################################################################################################
# Interfaces
/interface wireguard add listen-port=13007 mtu=1420 name=opportunity
/ip address add address=10.255.7.1/30 interface=opportunity network=10.255.7.0
/interface wireguard add listen-port=13231 mtu=1420 name=mobile
/ip address add address=10.7.16.1/24 interface=mobile network=10.7.16.0

# Peers
/interface wireguard peers 
add interface=opportunity name=opportunity endpoint-address=opportunity.pentatope.co.uk \
    public-key="ek1x/S6fLgbVmQBk2pwWnNvhArl5CZ3uS3dIKsfU6hk=" \
    allowed-address=10.0.0.0/8,224.0.0.0/24 client-allowed-address=::/0 \
    endpoint-port=13007
/interface wireguard peers
add allowed-address=10.7.16.2/32 interface=mobile name=atanas-laptop public-key="yqzv9lRoouf88utQlGcYosZveB7CppF9WEYDU3fUQ3c="
add allowed-address=10.7.16.3/32 interface=mobile name=atanas-phone public-key="EVlLCXVbdFRUnfXF6cDVxak+6CSO6Yp64K/ec4f/RRk="
add allowed-address=10.7.16.4/32 interface=mobile name=tsveta-phone public-key="s+wtyFJDqb3dIqoOh0GNSuFNyMDcufN8Bb1w2QCD/2Y="

# Firewall
/ip firewall filter
add action=log chain=input comment="WireGuard" disabled=yes protocol=icmp place-before=[find where comment="DROP"]
add action=accept chain=input dst-port=13007 in-interface=external protocol=udp place-before=[find where comment="DROP"]
add action=accept chain=input dst-port=13231 in-interface=external protocol=udp place-before=[find where comment="DROP"]

#################################################################################################
# OSPF
#################################################################################################
# Identity
/routing bfd configuration add disabled=no
/routing ospf instance add disabled=no name=voyager router-id=10.0.0.7 version=2 vrf=main

# Areas
/routing ospf area
add area-id=0.0.0.7 disabled=no instance=voyager name=area7 type=default
add area-id=0.0.0.0 disabled=no instance=voyager name=backbone type=default

# Interfaces
/routing ospf interface-template
add area=area7 disabled=no networks=10.7.0.0/16 type=ptp use-bfd=yes
add area=backbone disabled=no networks=10.255.7.0/30 type=ptp use-bfd=yes

# Firewall
/ip firewall filter
add action=log chain=input comment="OSPF" disabled=yes protocol=icmp place-before=[find where comment="DROP"]
add action=accept chain=input protocol=ospf place-before=[find where comment="DROP"]
add chain=input action=accept in-interface=!external protocol=udp dst-port=3784,3785 place-before=[find where comment="DROP"] #bfd

##################################################################################################
# WiFi controller
##################################################################################################
/interface wireless set [find default-name=wlan1] disabled=yes
# Manage CAPs through the LAN only
/interface wifi capsman set enabled=yes interfaces=internal upgrade-policy=none

# Channels
/interface wifi channel
add name=channel-2g frequency=2412 width=20mhz
add name=channel-5g frequency=5180 width=20/40mhz

# DHCP
/ip dhcp-server lease add comment=cap3 address=10.7.0.151 mac-address=18:FD:74:54:3D:C0 server=internal
# /ip dhcp-server lease add comment=cap2 address=10.7.0.152 mac-address= server=internal
# /ip dhcp-server lease add comment=cap3 address=10.7.0.153 mac-address= server=internal

# Shared authentication
/interface wifi security add name=voyager authentication-types=wpa2-psk passphrase="REPLACE_WITH_YOUR_WIFI_PASSWORD" wps=disable

# Network profiles
/interface wifi configuration
add name=voyager-2g mode=ap country=Bulgaria channel=channel-2g security=voyager ssid=voyager-x-2g
add name=voyager-5g mode=ap country=Bulgaria channel=channel-5g security=voyager ssid=voyager-x-5g

# CAP 1
/interface wifi
add name=cap-1-wifi-2g radio-mac=18:FD:74:2A:6F:A0 configuration=voyager-2g disabled=no
add name=cap-1-wifi-5g radio-mac=18:FD:74:2A:6F:A1 configuration=voyager-5g disabled=no
# CAP 2
/interface wifi
add name=cap-2-wifi-2g radio-mac=18:FD:74:54:3E:DE configuration=voyager-2g disabled=no
add name=cap-2-wifi-5g radio-mac=18:FD:74:54:3E:DF configuration=voyager-5g disabled=no
# CAP 3
/interface wifi
add name=cap-3-wifi-2g radio-mac=18:FD:74:54:3D:C2 configuration=voyager-2g disabled=no
add name=cap-3-wifi-5g radio-mac=18:FD:74:54:3D:C3 configuration=voyager-5g disabled=no
