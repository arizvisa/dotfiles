#!/usr/bin/env python2
import sys
sys.path.append('/usr/bin')
from scapy import Net
for l in sys.stdin.xreadlines():
 n = Net(l)
 print('\n'.join([ str(ip) for ip in n ]))
