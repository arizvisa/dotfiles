#!/usr/bin/env python2

def do_help(argv0):
    print >> sys.stderr, 'Usage: %s duration\n'% argv0
    print >> sys.stderr, '\tWill sleep the specified number of seconds. Seconds can be represented partially via a decimal number.'

if __name__ == '__main__':
    import sys,time
    argv0,argv = sys.argv.pop(0),sys.argv

    if len(argv) == 0 or '-h' in argv or '--help' in argv:
        do_help(argv0)
        sys.exit(1)

    duration, = map(eval,argv)
    time.sleep(duration)
    sys.exit(0)
