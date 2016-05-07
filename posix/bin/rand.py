#!/usr/bin/env python
import sys,random

def do_help_sequence(argv0):
    print >> sys.stderr, 'Usage: %s [-s] {min} {max} {step}\n'% argv0
    print >> sys.stderr, '\tWill output numbers from the range {min} - {max} with the step {step}'
    print >> sys.stderr, '\tif -s is specified, will shuffle the output'

def do_help_random(argv0):
    print >> sys.stderr, 'Usage: %s {min} {max} {count}\n'% argv0
    print >> sys.stderr, '\tWill output {count} random numbers from the range {min} - {max}'
    print >> sys.stderr, '\tif -f is specified, will output floating point numbers'

def do_random_float(argv0, argv):
    min,max,count = map(eval, argv)
    while count > 0:
        print random.uniform(min,max)
        count -= 1
    return

# we're not using list comprehensions so that output happens one row at a time
def do_random(argv0, argv):
    if len(sys.argv) < 3 or '-h' in argv or '--help' in argv:
        do_help_random(argv0)
        sys.exit(1)

    if '-f' in argv:
        argv.pop( argv.index('-f') )
        do_random_float(argv0, argv)
        sys.exit(0)

    min,max,count = map(eval, argv)
    while count > 0:
        print random.randrange(min,max+1)
        count -= 1
    sys.exit(0)

def do_sequence_shuffle(argv0, argv):
    min,max,step = map(eval,argv)

    result = range(min,max,step)
    random.shuffle(result)

    for x in result:
        print x
    return

def do_sequence(argv0, argv):
    if len(sys.argv) < 3 or '-h' in argv or '--help' in argv:
        do_help_sequence(argv0)
        sys.exit(1)

    if '-s' in argv:
        argv.pop( argv.index('-s') )
        do_sequence_shuffle(argv0, argv)
        sys.exit(0)

    min,max,step = map(eval,argv)
    n = min
    if step > 0:
        while n < max:
            print n
            n += step
        sys.exit(0)

    elif step < 0:
        while n > max:
            print n
            n += step
        sys.exit(0)

    print >> sys.stderr, '%s: ignoring request for infinite loop'% argv0
    sys.exit(1)

if __name__ == '__main__':
    argv = sys.argv

    if argv[0].endswith('rand.py'):
        do_random(argv.pop(0), argv)
        sys.exit(0)

    elif argv[0].endswith('seq.py'):
        do_sequence(argv.pop(0), argv)
        sys.exit(0)

    raise NotImplementedError(argv[0])
