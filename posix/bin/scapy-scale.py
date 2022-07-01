#!/usr/bin/env python
import sys, itertools
from scapy.base_classes import Net
from scapy.utils6 import Net6

for line in itertools.chain(sys.argv[1:]):
    network = Net6(line) if ':' in line else Net(line)
    for ip in network:
        print(ip)
    continue
sys.exit(0)
