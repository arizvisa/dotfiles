#!/usr/bin/env python
import sys, os, scapy, itertools
from scapy.base_classes import Net
from scapy.utils6 import Net6
if len(sys.argv) <= 1 and os.isatty(sys.stdin.fileno()):
    print("Usage: {:s} [ADDRESS]...".format(sys.argv[0] if sys.argv else __name__), file=sys.stderr)
    print('Consume the given address ranges specified as a CIDR or hyphenated')
    print('pair, and expand them to standard output. Addresses can be')
    print('passed as either a parameter or standard input.')
    print()
    print("Supported address types: {:s}".format(', '.join("{:s}({:d})".format(name, net.family) for name, net in zip(['AF_INET', 'AF_INET6'], [Net, Net6]))))
    sys.exit(1)

Fdetect_inetnum = lambda string: Net(string) if '.' in string else Net6(string)
Fdetect_inetpair = lambda first, second: Net(first, second) if '.' in first else Net6(first, second)
for line in itertools.chain(sys.argv[1:], [] if os.isatty(sys.stdin.fileno()) else sys.stdin):
    try:
        if '-' not in line:
            iterable = Fdetect_inetnum(line.strip().replace(' ', ''))
        elif line.count('-') == 1:
            iterable = Fdetect_inetpair(*line.strip().replace(' ', '').split('-', 1))
        else:
            raise ValueError

    except Exception:
        print("Skipping address range of unknown type: {:s}".format(line.strip()), file=sys.stderr)

    else:
        print('\n'.join(iterable))
    continue
sys.exit(0)
