echo this shit doesnt fucking work
cd "c:\Program Files\VMware\VMware Workstation"
c:

vnetlib.exe -- stop nat
vnetlib.exe -- stop dhcp

vnetlib.exe -- add adapter vmnet1
vnetlib.exe -- set vnet vmnet1 addr 172.22.22.0
vnetlib.exe -- set vnet vmnet1 mask 255.255.255.0
vnetlib.exe -- add dhcp vmnet1
vnetlib.exe -- update dhcp vmnet1
vnetlib.exe -- enable adapter vmnet1

vnetlib.exe -- add adapter vmnet8
vnetlib.exe -- set vnet vmnet8 addr 172.22.33.0
vnetlib.exe -- set vnet vmnet8 mask 255.255.255.0
vnetlib.exe -- add dhcp vmnet8
vnetlib.exe -- add nat vmnet8
vnetlib.exe -- update dhcp vmnet8
vnetlib.exe -- update nat vmnet8
vnetlib.exe -- enable adapter vmnet8

vnetlib.exe -- start dhcp
vnetlib.exe -- start nat
