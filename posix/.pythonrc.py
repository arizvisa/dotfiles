import sys, os
import functools, operator, itertools
import types, user
import __builtin__ as builtin

# remove crlf from std{out,err} because CPython is pretty fucking stupid
if sys.platform == 'win32':
    __import__('msvcrt').setmode(sys.stdout.fileno(), os.O_BINARY) if hasattr(sys.stdout, 'fileno') else None
    __import__('msvcrt').setmode(sys.stderr.fileno(), os.O_BINARY) if hasattr(sys.stdout, 'fileno') else None

# use the current virtualenv if it exists
builtin._ = os.path.join(user.home.replace('\\', os.sep).replace('/', os.sep), '.python-virtualenv', 'Scripts' if __import__('platform').system() == 'Windows' else 'bin', 'activate_this.py')
if os.path.exists(builtin._): execfile(builtin._, {'__file__':builtin._})

# add ~/.python/* to python module search path
map(sys.path.append, __import__('glob').iglob(os.path.join(user.home.replace('\\', os.sep).replace('/', os.sep), '.python', '*')))

## some functional primitives in the default namespace
# box any specified arguments
fbox = fboxed = box = boxed = lambda *a: a
# return a closure that executes ``f`` with the arguments unboxed.
funbox = unbox = lambda f, *a, **k: lambda *ap, **kp: f(*(a + builtin.reduce(operator.add, builtin.map(builtin.tuple, ap), ())), **builtin.dict(k.items() + kp.items()))
# return a closure that will check that its argument is an instance of ``type``.
finstance = lambda type: frpartial(builtin.isinstance, type)
# return a closure that will check if its argument has an item ``key``.
fhasitem = fitemQ = lambda key: fcompose(fcatch(frpartial(operator.getitem, key)), builtin.iter, builtin.next, fpartial(operator.eq, builtin.None))
# return a closure that will check if its argument has an ``attribute``.
fhasattr = fattrQ = lambda attribute: frpartial(builtin.hasattr, attribute)
# return a closure that always returns ``object``.
fconstant = fconst = falways = always = lambda object: lambda *a, **k: object
# a closure that returns it's argument
fpassthru = fpass = fidentity = fid = lambda object: object
# return the first, second, or third item of a box.
first, second, third, last = operator.itemgetter(0), operator.itemgetter(1), operator.itemgetter(2), operator.itemgetter(-1)
# return a closure that executes a list of functions one after another from left-to-right
fcompose = compose = lambda *f: builtin.reduce(lambda f1, f2: lambda *a: f1(f2(*a)), builtin.reversed(f))
# return a closure that executes function ``f`` whilst discarding any extra arguments
fdiscard = lambda f: lambda *a, **k: f()
# return a closure that executes function ``crit`` and then executes ``f`` or ``t`` based on whether or not it's successful.
fcondition = fcond = lambda crit: lambda t, f: \
    lambda *a, **k: t(*a, **k) if crit(*a, **k) else f(*a, **k)
# return a closure that takes a list of functions to execute with the provided arguments
fmaplist = fap = lambda *fa: lambda *a, **k: (f(*a, **k) for f in fa)
#lazy = lambda f, state={}: lambda *a, **k: state[(f, a, builtin.tuple(builtin.sorted(k.items())))] if (f, a, builtin.tuple(builtin.sorted(k.items()))) in state else state.setdefault((f, a, builtin.tuple(builtin.sorted(k.items()))), f(*a, **k))
#lazy = lambda f, *a, **k: lambda *ap, **kp: f(*(a+ap), **dict(k.items() + kp.items()))
# return a memoized closure that's lazy and only executes when evaluated
def flazy(f, *a, **k):
    sortedtuple, state = fcompose(builtin.sorted, builtin.tuple), {}
    def lazy(*ap, **kp):
        A, K = a+ap, sortedtuple(k.items() + kp.items())
        return state[(A, K)] if (A, K) in state else state.setdefault((A, K), f(*A, **builtin.dict(k.items()+kp.items())))
    return lazy
fmemo = flazy
# return a closure with the function's arglist partially applied
fpartial = partial = functools.partial
# return a closure that applies the provided arguments to the function ``f``.
fapply = lambda f, *a, **k: lambda *ap, **kp: f(*(a+ap), **builtin.dict(k.items() + kp.items()))
# return a closure that will use the specified arguments to call the provided function.
fcurry = lambda *a, **k: lambda f, *ap, **kp: f(*(a+ap), **builtin.dict(k.items() + kp.items()))
# return a closure that applies the initial arglist to the end of function ``f``.
frpartial = lambda f, *a, **k: lambda *ap, **kp: f(*(ap + builtin.tuple(builtin.reversed(a))), **builtin.dict(k.items() + kp.items()))
# return a closure that applies the arglist to function ``f`` in reverse.
freversed = frev = lambda f, *a, **k: lambda *ap, **kp: f(*builtin.reversed(a + ap), **builtin.dict(k.items() + kp.items()))
# return a closure that executes function ``f`` and includes the caught exception (or None) as the first element in the boxed result.
def fcatch(f, *a, **k):
    def fcatch(*a, **k):
        try: return builtin.None, f(*a, **k)
        except: return sys.exc_info()[1], builtin.None
    return functools.partial(fcatch, *a, **k)
fexc = fexception = fcatch
# boolean inversion of the result of a function
fcomplement = fnot = complement = frpartial(fcompose, operator.not_)
# converts a list to an iterator, or an iterator to a list
ilist, liter = compose(list, iter), compose(iter, list)
# converts a tuple to an iterator, or an iterator to a tuple
ituple, titer = compose(builtin.tuple, builtin.iter), compose(builtin.iter, builtin.tuple)
# take ``count`` number of elements from an iterator
itake = lambda count: compose(builtin.iter, fap(*(builtin.next,)*count), builtin.tuple)
# get the ``nth`` element from an iterator
iget = lambda count: compose(builtin.iter, fap(*(builtin.next,)*(count)), builtin.tuple, operator.itemgetter(-1))
# copy from itertools
imap, ifilter, ichain, izip = itertools.imap, itertools.ifilter, itertools.chain, itertools.izip
# count number of elements of a container
count = compose(iter, list, len)

__all__ = ['functools', 'operator', 'itertools', 'types', 'builtin']
__all__+= ['first', 'second', 'third', 'last']
__all__+= ['partial', 'fpartial', 'imap', 'ifilter', 'ichain', 'izip']
__all__+= filter( compose(fpartial(operator.getitem,locals()), finstance(types.FunctionType)), locals())
