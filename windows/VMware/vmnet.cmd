set vmnet_host=172.22.22.0
set vmnet_nat=172.33.33.0
set mask=255.255.255.0

pushd "%ProgramFiles(x86)%\VMware\VMware Workstation"
c:

REM echo this shit doesnt fucking work
vnetlib.exe -- stop nat
vnetlib.exe -- stop dhcp

vnetlib.exe -- add adapter vmnet1
vnetlib.exe -- set vnet vmnet1 addr %vmnet_host%
vnetlib.exe -- set vnet vmnet1 mask %mask%
vnetlib.exe -- add dhcp vmnet1
vnetlib.exe -- update dhcp vmnet1
vnetlib.exe -- enable adapter vmnet1

vnetlib.exe -- add adapter vmnet8
vnetlib.exe -- set vnet vmnet8 addr %vmnet_nat%
vnetlib.exe -- set vnet vmnet8 mask %mask%
vnetlib.exe -- add dhcp vmnet8
vnetlib.exe -- add nat vmnet8
vnetlib.exe -- update dhcp vmnet8
vnetlib.exe -- update nat vmnet8
vnetlib.exe -- enable adapter vmnet8

vnetlib.exe -- start dhcp
vnetlib.exe -- start nat
popd
