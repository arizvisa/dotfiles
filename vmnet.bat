REM set vmnet_host=172.22.22.100
REM set vmnet_nat=172.33.33.100
REM set mask=255.255.255.0

REM echo this shit doesnt fucking work
REM cd "c:\Program Files\VMware\VMware Workstation"
REM c:

vnetlib.exe -- stop nat
vnetlib.exe -- stop dhcp

vnetlib.exe -- add adapter vmnet1
vnetlib.exe -- set vnet vmnet1 addr 172.16.100.0
vnetlib.exe -- set vnet vmnet1 mask 255.255.255.0
vnetlib.exe -- add dhcp vmnet1
vnetlib.exe -- update dhcp vmnet1
vnetlib.exe -- enable adapter vmnet1

vnetlib.exe -- add adapter vmnet8
vnetlib.exe -- set vnet vmnet8 addr 172.16.200.0
vnetlib.exe -- set vnet vmnet8 mask 255.255.255.0
vnetlib.exe -- add dhcp vmnet8
vnetlib.exe -- add nat vmnet8
vnetlib.exe -- update dhcp vmnet8
vnetlib.exe -- update nat vmnet8
vnetlib.exe -- enable adapter vmnet8

vnetlib.exe -- start dhcp
vnetlib.exe -- start nat
