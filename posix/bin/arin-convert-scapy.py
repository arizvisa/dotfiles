#!/usr/bin/env python2
import sys
sys.path.append('/usr/bin')
from scapy import Net
for l in sys.stdin.xreadlines():
 left, right = l.split(' - ')
 left_octets = left.split('.')
 right_octets = right.split('.')
 res = '.'.join(['%s-%s'%(a,b) for a,b in zip(left_octets, right_octets)])
print(res.strip())
