################################################################################ 
# Variables
################################################################################ 
global Identity "voyager"
# global WifiPassword ""

################################################################################ 
# System
################################################################################ 
/system identity set name=$satName
/system clock set time-zone-name=Europe/Sofia
/system ntp client set enabled=yes servers=1.bg.pool.ntp.org,2.bg.pool.ntp.org

/ip cloud set ddns-enabled=yes ddns-update-interval=60m update-time=no
/ip cloud force-update

/ip dns set servers=8.8.8.8

/ip service disable api
/ip service disable api-ssl
/ip service disable ftp
/ip service disable telnet
/ip service disable www

/snmp set enabled=yes

/system scheduler add interval=1w name=Reboot_router on-event="/system reboot" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-date=2025-01-01 start-time=03:00:00

################################################################################ 
# Ethernet
################################################################################ 
/interface bridge add name=loopback
/ip address add address=10.0.0.7/16 interface=loopback network=10.0.0.0

/interface bridge add name=internal
/interface bridge port add bridge=internal interface=ether1
/interface bridge port add bridge=internal interface=ether2
# /interface bridge port add bridge=internal interface=wlan1
/ip address add address=10.7.0.1/24 interface=internal network=10.7.0.0

/interface bridge add name=external
/interface bridge port add bridge=external interface=ether3
/ip address add address=172.16.0.100/24 interface=external network=172.16.0.0

################################################################################ 
# Wireless(Disabled)
################################################################################ 
# /interface wireless set [ find default-name=wlan1 ] band=5ghz-a/n channel-width=20/40mhz-XX country=bulgaria frequency=auto installation=outdoor mode=ap-bridge security-profile=($Identity) ssid=($Identity) wps-mode=disabled
# /interface wireless security-profiles set [ find default=yes ] supplicant-identity=MikroTik
# /interface wireless security-profiles add authentication-types=wpa2-psk mode=dynamic-keys name=($Identity) supplicant-identity=MikroTik wpa2-pre-shared-key=($WifiPassword)

################################################################################ 
# DHCP
################################################################################ 
/ip pool add name=internal ranges=10.7.0.100-10.7.0.160
/ip dhcp-server network add address=10.7.0.0/24 dns-server=10.7.0.254 gateway=10.7.0.1
/ip dhcp-server add address-pool=internal interface=internal lease-time=10m name=dhcp1

######################################
# Routing
######################################
/ip route
add disabled=no distance=1 dst-address=0.0.0.0/0 gateway=172.16.0.1 pref-src="" routing-table=main scope=30 suppress-hw-offload=no target-scope=10
add disabled=no dst-address=10.7.10.0/24 gateway=10.7.0.200 routing-table=main suppress-hw-offload=no

######################################
# WireGuard
######################################
/interface wireguard add listen-port=13007 mtu=1420 name=opportunity
/ip address add address=10.255.7.1/30 interface=opportunity network=10.255.7.0

/interface wireguard add listen-port=13231 mtu=1420 name=road-warriors
/ip address add address=10.7.100.1/24 interface=road-warriors network=10.7.100.0

# RoadWarriors
/interface wireguard peers add allowed-address=10.7.100.2/32 comment=ROAD-WARRIORS interface=road-warriors name=rw-atanas-laptop public-key="vJpvPPp/Hod3jxfkyRU8BdOqnLffOOhcbw0JWRYxUQk="
/interface wireguard peers add allowed-address=10.7.100.3/32 interface=road-warriors name=rw-atanas-phone public-key="EVlLCXVbdFRUnfXF6cDVxak+6CSO6Yp64K/ec4f/RRk="
/interface wireguard peers add allowed-address=10.7.100.4/32 interface=road-warriors name=rw-tsveta-phone public-key="s+wtyFJDqb3dIqoOh0GNSuFNyMDcufN8Bb1w2QCD/2Y="

# Site-To-Site
/interface wireguard peers add allowed-address=10.0.0.0/8,224.0.0.0/24 comment=SITE-TO-SITE endpoint-address=opportunity.pentatope.co.uk endpoint-port=13007 interface=opportunity name=sts-opportunity public-key="ek1x/S6fLgbVmQBk2pwWnNvhArl5CZ3uS3dIKsfU6hk="

######################################
# OSPF
######################################
/routing ospf instance add disabled=no name=($Identity) router-id=10.0.0.7
/routing ospf area
add area-id=0.0.0.7 disabled=no instance=($Identity) name=area7
add area-id=0.0.0.0 disabled=no instance=($Identity) name=backbone
/routing ospf interface-template
add area=area7 disabled=no networks=10.7.0.0/16 type=ptp
add area=backbone disabled=no networks=10.255.7.0/30 type=ptp

######################################
# Firewall
######################################
/ip firewall address-list
add address=10.0.0.0/8 list=internal
add address=172.16.0.0/12 list=internal
add address=192.168.0.0/16 list=internal

/ip firewall filter
add action=log chain=input comment="=== Router ===" disabled=yes protocol=icmp
add action=accept chain=input dst-port=8291 in-interface=!external protocol=tcp
add action=accept chain=input connection-state="" dst-port=22 in-interface=!external protocol=tcp
add action=accept chain=input connection-state="" protocol=ospf
add action=accept chain=input protocol=icmp
add action=accept chain=output
add action=log chain=input comment="=== WireGuard ===" disabled=yes protocol=icmp
add action=accept chain=input dst-port=13007 in-interface=external protocol=udp
add action=accept chain=input dst-port=13231 in-interface=external protocol=udp
add action=log chain=forward comment="=== External ===" disabled=yes protocol=icmp
add action=accept chain=forward protocol=tcp in-interface=external dst-port=8333 
add action=log chain=forward comment="=== Internal ===" disabled=yes protocol=icmp
add action=accept chain=forward in-interface=!external protocol=icmp src-address-list=internal
add action=accept chain=forward connection-state=new in-interface=!external protocol=tcp src-address-list=internal
add action=accept chain=forward connection-state=new in-interface=!external protocol=udp src-address-list=internal
add action=fasttrack-connection chain=forward connection-state=established,related hw-offload=yes
add action=log chain=output comment="=== DROP ===" disabled=yes protocol=icmp
add action=drop chain=input in-interface=external
add action=drop chain=forward connection-nat-state=!dstnat connection-state=new in-interface=external

/ip firewall nat
add action=accept chain=srcnat comment=private-to-private dst-address-list=internal src-address-list=internal
add action=dst-nat chain=dstnat to-addresses=10.7.0.254 protocol=tcp in-interface=external dst-port=8333 
add action=masquerade chain=srcnat out-interface=external

