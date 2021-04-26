import logging, six
import builtins, os, operator, math, functools, itertools, sys, types   # boomfist

# remove crlf from std{out,err} because CPython is pretty fucking stupid
if sys.platform == 'win32':
    __import__('msvcrt').setmode(sys.stdout.fileno(), os.O_BINARY) if hasattr(sys.stdout, 'fileno') else None
    __import__('msvcrt').setmode(sys.stderr.fileno(), os.O_BINARY) if hasattr(sys.stderr, 'fileno') else None

# use the current virtualenv if it exists
builtins._ = os.path.join(os.environ.get('HOME', os.path.expanduser('~')).replace('\\', os.sep).replace('/', os.sep), '.python-virtualenv', 'Scripts' if __import__('platform').system() == 'Windows' else 'bin', 'activate_this.py')
if os.path.exists(builtins._): execfile(builtins._, {'__file__':builtins._})

# add ~/.python/* to python module search path
map(sys.path.append, __import__('glob').iglob(os.path.join(os.environ.get('HOME', os.path.expanduser('~')).replace('\\', os.sep).replace('/', os.sep), '.python', '*')))

## some functional programming combinators in the default namespace

# return a closure that executes `F` with the arguments boxed and concatenated.
fpack = lambda F, *a, **k: lambda *ap, **kp: F(a + ap, **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that executes `F` with all of its arguments concatenated and unboxed.
funpack = lambda F, *a, **k: lambda *ap, **kp: F(*(a + functools.reduce(operator.add, builtins.map(builtins.tuple, ap), ())), **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that executes `F` with only its first argument.
fcar = lambda F, *a, **k: lambda *ap, **kp: F(*(a + ap[:1]), **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that executes `F` with all of it arguments but the first.
fcdr = lambda F, *a, **k: lambda *ap, **kp: F(*(a + ap[1:]), **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that will check that `object` is an instance of `type`.
finstance = lambda *type: frpartial(builtins.isinstance, type)
# return a closure that will check if its argument has an item `key`.
fhasitem = fitemQ = lambda key: frpartial(operator.contains, key)
# return a closure that will get a particular element from an object.
fgetitem = fitem = lambda item, *default: lambda object: default[0] if default and item not in object else object[item]
# return a closure that will set a particular element on an object.
fsetitem = lambda item: lambda value: lambda object: operator.setitem(object, item, value) or object
# return a closure that will remove a particular element from an object and return the modified object
fdelitem = lambda *items: fcompose(fmap(fidentity, *[fcondition(fhasitem(item))(frpartial(operator.delitem, item), None) for item in items]), builtins.iter, builtins.next)
# return a closure that will check if its argument has an `attribute`.
fhasattr = fattributeQ = lambda attribute: frpartial(builtins.hasattr, attribute)
# return a closure that will get a particular attribute from an object.
fgetattr = fattribute = lambda attribute, *default: lambda object: getattr(object, attribute, *default)
# return a closure that will set a particular attribute on an object.
fsetattr = fsetattribute = lambda attribute: lambda value: lambda object: builtins.setattr(object, attribute, value) or object
# return a closure that always returns `object`.
fconstant = fconst = falways = lambda object: lambda *a, **k: object
# a closure that returns its argument always.
fidentity = lambda object: object
# a closure that returns a default value if its object is false-y
fdefault = lambda default: lambda object: object or default
# return the first, second, or third item of a box.
first, second, third, last = operator.itemgetter(0), operator.itemgetter(1), operator.itemgetter(2), operator.itemgetter(-1)
# return a closure that executes a list of functions one after another from left-to-right.
fcompose = lambda *Fa: functools.reduce(lambda F1, F2: lambda *a: F1(F2(*a)), builtins.reversed(Fa))
# return a closure that executes function `F` whilst discarding any arguments passed to it.
fdiscard = lambda F, *a, **k: lambda *ap, **kp: F(*a, **k)
# return a closure that executes function `crit` and then returns/executes `f` or `t` based on whether or not it's successful.
fcondition = lambda crit: lambda t, f: \
    lambda *a, **k: (t(*a, **k) if builtins.callable(t) else t) if crit(*a, **k) else (f(*a, **k) if builtins.callable(f) else f)
# return a closure that takes a list of functions to execute with the provided arguments
fmap = lambda *Fa: lambda *a, **k: builtins.tuple(F(*a, **k) for F in Fa)
#lazy = lambda F, state={}: lambda *a, **k: state[(F, a, builtins.tuple(builtins.sorted(k.items())))] if (F, a, builtins.tuple(builtins.sorted(k.items()))) in state else state.setdefault((F, a, builtins.tuple(builtins.sorted(k.items()))), F(*a, **k))
#lazy = lambda F, *a, **k: lambda *ap, **kp: F(*(a + ap), **{ key : value for key, value in itertools.chain(k.items(), kp.items())})
# return a memoized closure that's lazy and only executes when evaluated
def flazy(F, *a, **k):
    sortedtuple, state = fcompose(builtins.sorted, builtins.tuple), {}
    def lazy(*ap, **kp):
        A, K = a + ap, sortedtuple(builtins.tuple(k.items()) + builtins.tuple(kp.items()))
        return state[(A, K)] if (A, K) in state else state.setdefault((A, K), F(*A, **{ key : value for key, value in itertools.chain(k.items(), kp.items()) }))
    return lazy
# return a closure with the function's arglist partially applied
fpartial = functools.partial
# return a closure that applies the provided arguments to the function `F`.
fapply = lambda F, *a, **k: lambda *ap, **kp: F(*(a + ap), **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that will use the specified arguments to call the provided function.
fcurry = lambda *a, **k: lambda F, *ap, **kp: F(*(a + ap), **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that applies the initial arglist to the end of function `F`.
frpartial = lambda F, *a, **k: lambda *ap, **kp: F(*(ap + builtins.tuple(builtins.reversed(a))), **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that applies the arglist to function `F` in reverse.
freverse = lambda F, *a, **k: lambda *ap, **kp: F(*builtins.reversed(a + ap), **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that executes function `F` and includes the caught exception (or None) as the first element in the boxed result.
def fcatch(F, *a, **k):
    def fcatch(*a, **k):
        try: return None, F(*a, **k)
        except: return sys.exc_info()[1], None
    return functools.partial(fcatch, *a, **k)
# boolean inversion of the result of a function
fcomplement = fnot = frpartial(fcompose, operator.not_)
# converts a list to an iterator, or an iterator to a list
ilist, liter = fcompose(builtins.iter, builtins.list), fcompose(builtins.list, builtins.iter)
# converts a tuple to an iterator, or an iterator to a tuple
ituple, titer = fcompose(builtins.iter, builtins.tuple), fcompose(builtins.tuple, builtins.iter)
# take `count` number of elements from an iterator
itake = lambda count: fcompose(builtins.iter, fmap(*[builtins.next] * count), builtins.tuple)
# get the `nth` element from an iterator
iget = lambda count: fcompose(builtins.iter, fmap(*[builtins.next] * count), builtins.tuple, operator.itemgetter(-1))
# copy from itertools
islice, imap, ifilter, ichain, izip = itertools.islice, fcompose(builtins.map, builtins.iter), fcompose(builtins.filter, builtins.iter), itertools.chain, fcompose(builtins.zip, builtins.iter)
# restoration of the Py2-compatible list types
lslice, lmap, lfilter, lzip = fcompose(itertools.islice, builtins.list), fcompose(builtins.map, builtins.list), fcompose(builtins.filter, builtins.list), fcompose(builtins.zip, builtins.list)
# count number of elements of a container
count = fcompose(builtins.iter, builtins.list, builtins.len)

# some miscellaneous utilities
def scan(source, pattern):
    position, state = 0, source[:]
    while len(state):
        current, position = len(source) - len(state), state.find(pattern)
        rest = slice(1 + position or len(state), None)
        if position >= 0:
            yield current + position
        state = state[rest]
    return

def entropy(bytes):
    length = len(bytes)

    count = {}
    for octet in bytearray(bytes):
        count.setdefault(octet, 0)
        count[octet] += 1

    frequency = []
    for item in count.values():
        frequency.append(float(item) / float(length))

    res = 0.0
    for item in frequency:
        res = res + item * math.log(item, 2)
    return -res / 8
