import os, sys, logging
import functools, itertools, types, builtins, operator, six

# remove crlf from std{out,err} because CPython is pretty fucking stupid
if sys.platform == 'win32':
    __import__('msvcrt').setmode(sys.stdout.fileno(), os.O_BINARY) if hasattr(sys.stdout, 'fileno') else None
    __import__('msvcrt').setmode(sys.stderr.fileno(), os.O_BINARY) if hasattr(sys.stderr, 'fileno') else None

# use the current virtualenv if it exists
builtins._ = os.path.join(os.environ.get('HOME', os.path.expanduser('~')).replace('\\', os.sep).replace('/', os.sep), '.python-virtualenv', 'Scripts' if __import__('platform').system() == 'Windows' else 'bin', 'activate_this.py')
if os.path.exists(builtins._): execfile(builtins._, {'__file__':builtins._})

# add ~/.python/* to python module search path
map(sys.path.append, __import__('glob').iglob(os.path.join(os.environ.get('HOME', os.path.expanduser('~')).replace('\\', os.sep).replace('/', os.sep), '.python', '*')))

## some functional primitives in the default namespace
# box any specified arguments
fbox = lambda *a: a
# return a closure that executes `f` with the arguments unboxed.
funbox = lambda f, *a, **k: lambda *ap, **kp: f(*(a + functools.reduce(operator.add, builtins.map(builtins.tuple, ap), ())), **{ key : value for key, value in itertools.chain(k.items(), kp.items())})
# return the first argument
fcar = lambda *a: a[:1][0]
# return the rest of the arguments
fcdr = lambda *a: a[1:]
# return a closure that will check that `object` is an instance of `type`.
finstance = lambda *type: frpartial(builtins.isinstance, type)
# return a closure that will check if its argument has an item `key`.
fhasitem = fitemQ = lambda key: fcompose(fcatch(frpartial(operator.getitem, key)), builtins.iter, builtins.next, fpartial(operator.eq, None))
# return a closure that will get a particular element from an object
fgetitem = fitem = lambda item, *default: lambda object: default[0] if default and item not in object else object[item]
# return a closure that will set a particular element on an object
fsetitem = lambda item: lambda value: lambda object: operator.setitem(object, item, value) or object
# return a closure that will check if its argument has an `attribute`.
fhasattr = fattributeQ = lambda attribute: frpartial(builtins.hasattr, attribute)
# return a closure that will get a particular attribute from an object
fgetattr = fattribute = lambda attribute, *default: lambda object: getattr(object, attribute, *default)
# return a closure that will set a particular attribute on an object
fsetattr = fsetattribute = lambda attribute: lambda value: lambda object: builtins.setattr(object, attribute, value) or object
# return a closure that always returns `object`.
fconstant = fconst = falways = lambda object: lambda *a, **k: object
# a closure that returns its argument always
fidentity = lambda object: object
# a closure that returns a default value if its object is false-y
fdefault = lambda default: lambda object: object or default
# return the first, second, or third item of a box.
first, second, third, last = operator.itemgetter(0), operator.itemgetter(1), operator.itemgetter(2), operator.itemgetter(-1)
# return a closure that executes a list of functions one after another from left-to-right
fcompose = lambda *f: functools.reduce(lambda f1, f2: lambda *a: f1(f2(*a)), builtins.reversed(f))
# return a closure that executes function `f` whilst discarding any extra arguments
fdiscard = lambda f: lambda *a, **k: f()
# return a closure that executes function `crit` and then returns/executes `f` or `t` based on whether or not it's successful.
fcondition = lambda crit: lambda t, f: \
    lambda *a, **k: (t(*a, **k) if builtins.callable(t) else t) if crit(*a, **k) else (f(*a, **k) if builtins.callable(f) else f)
# return a closure that takes a list of functions to execute with the provided arguments
fmap = lambda *fa: lambda *a, **k: (f(*a, **k) for f in fa)
#lazy = lambda f, state={}: lambda *a, **k: state[(f, a, builtins.tuple(builtins.sorted(k.items())))] if (f, a, builtins.tuple(builtins.sorted(k.items()))) in state else state.setdefault((f, a, builtins.tuple(builtins.sorted(k.items()))), f(*a, **k))
#lazy = lambda f, *a, **k: lambda *ap, **kp: f(*(a + ap), **{ key : value for key, value in itertools.chain(k.items(), kp.items())})
# return a memoized closure that's lazy and only executes when evaluated
def flazy(f, *a, **k):
    sortedtuple, state = fcompose(builtins.sorted, builtins.tuple), {}
    def lazy(*ap, **kp):
        A, K = a + ap, sortedtuple(builtins.tuple(k.items()) + builtins.tuple(kp.items()))
        return state[(A, K)] if (A, K) in state else state.setdefault((A, K), f(*A, **{ key : value for key, value in itertools.chain(k.items(), kp.items())}))
    return lazy
# return a closure with the function's arglist partially applied
fpartial = functools.partial
# return a closure that applies the provided arguments to the function `f`.
fapply = lambda f, *a, **k: lambda *ap, **kp: f(*(a + ap), **{ key : value for key, value in itertools.chain(k.items(), kp.items())})
# return a closure that will use the specified arguments to call the provided function.
fcurry = lambda *a, **k: lambda f, *ap, **kp: f(*(a + ap), **{ key : value for key, value in itertools.chain(k.items(), kp.items())})
# return a closure that applies the initial arglist to the end of function `f`.
frpartial = lambda f, *a, **k: lambda *ap, **kp: f(*(ap + builtins.tuple(builtins.reversed(a))), **{ key : value for key, value in itertools.chain(k.items(), kp.items())})
# return a closure that applies the arglist to function `f` in reverse.
freverse = lambda f, *a, **k: lambda *ap, **kp: f(*builtins.reversed(a + ap), **{ key : value for key, value in itertools.chain(k.items(), kp.items())})
# return a closure that executes function `f` and includes the caught exception (or None) as the first element in the boxed result.
def fcatch(f, *a, **k):
    def fcatch(*a, **k):
        try: return None, f(*a, **k)
        except: return sys.exc_info()[1], None
    return functools.partial(fcatch, *a, **k)
# boolean inversion of the result of a function
fcomplement = fnot = frpartial(fcompose, operator.not_)
# converts a list to an iterator, or an iterator to a list
ilist, liter = fcompose(builtins.list, builtins.iter), fcompose(builtins.iter, builtins.list)
# converts a tuple to an iterator, or an iterator to a tuple
ituple, titer = fcompose(builtins.tuple, builtins.iter), fcompose(builtins.iter, builtins.tuple)
# take `count` number of elements from an iterator
itake = lambda count: fcompose(builtins.iter, fmap(*[builtins.next] * count), builtins.tuple)
# get the `nth` element from an iterator
iget = lambda count: fcompose(builtins.iter, fmap(*[builtins.next] * count), builtins.tuple, operator.itemgetter(-1))
# copy from itertools
islice, imap, ifilter, ichain, izip = itertools.islice, fcompose(builtins.map, builtins.iter), fcompose(builtins.filter, builtins.iter), itertools.chain, fcompose(builtins.zip, builtins.iter)
# count number of elements of a container
count = fcompose(builtins.iter, builtins.list, builtins.len)
