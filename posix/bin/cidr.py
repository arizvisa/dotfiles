#!/usr/bin/env python
import sys, itertools
import netaddr

for line in itertools.chain(sys.argv[1:]):
    network = netaddr.IPRange(*(item.strip() for item in line.split('-'))) if '-' in line else netaddr.IPGlob(line.strip()) if '*' in line else netaddr.IPNetwork(line.strip())
    for ip in network:
        print(ip)
    continue
sys.exit(0)
