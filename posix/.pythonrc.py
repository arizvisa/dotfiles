# -*- coding: utf-8 -*-
import logging
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
fdelitem = lambda *items: fcompose(fthrough(fidentity, *[fcondition(fhasitem(item))(frpartial(operator.delitem, item), None) for item in items]), builtins.iter, builtins.next)
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
fcompose = (lambda functools, builtins: lambda *Fa: functools.reduce(lambda F1, F2: lambda *a: F1(F2(*a)), builtins.reversed(Fa)))(functools, builtins)
# return a closure that executes function `F` whilst discarding any arguments passed to it.
fdiscard = lambda F, *a, **k: lambda *ap, **kp: F(*a, **k)
# return a closure using the functions in `critiques` with its parameters to return the result of the matching `truths` if any are successful or the last `truths` if not.
fcondition = lambda *critiques: lambda *truths: \
    (lambda false, critiques_and_truths=[pair for pair in zip(critiques, ((t if builtins.callable(t) else fconstant(t)) for t in truths))]: \
        lambda *a, **k: next((true for crit, true in critiques_and_truths if crit(*a, **k)), false if builtins.callable(false) else fconstant(false))(*a, **k) \
    )(false=truths[len(critiques)])
# return a closure that takes a list of functions to execute with the provided arguments
fthrough = lambda *Fa: lambda *a, **k: builtins.tuple(F(*a, **k) for F in Fa)
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
fapplyto = lambda *a, **k: lambda F, *ap, **kp: F(*(a + ap), **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that applies the initial arglist to the end of function `F`.
frpartial = lambda F, *a, **k: lambda *ap, **kp: F(*(ap + builtins.tuple(builtins.reversed(a))), **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that applies the arglist to function `F` in reverse.
freverse = lambda F, *a, **k: lambda *ap, **kp: F(*builtins.reversed(a + ap), **{ key : value for key, value in itertools.chain(k.items(), kp.items()) })
# return a closure that raises exception `E` with the given arguments.
def fthrow(E, *a, **k):
    def fraise(*ap, **kp):
        raise E(*(a + ap), **{key : value for key, value in itertools.chain(k.items(), kp.items())})
    return fraise
# return a closure that maps the given exceptions to a list of handlers which returns a closure that calls `F` with some arguments.
def fcatch(*exceptions, **map_exceptions):
    """Return a closure that calls the function `F` using the arguments `a` and keywords `k` capturing any exceptions that it raises.

    Usage:      fcatch(exceptions..., handler=exception)(traps..., handler=lambda *args, **keywords: result)(callable, ...)(*args, **keywords)
    Example:    fcatch(ValueError,    IDX=IndexError)   ('ValueError', IDX=lambda x1, x2: ('idx', x1, x2))  (callable, []) (x1, x2)
    """
    Fpartial, Fchain = functools.partial, itertools.chain
    def Fcallable(processors, F, *a, **k):
        '''Return a closure that calls the function `F` with the arguments `a` and keywords `k` while transforming any caught exceptions using `processors`.'''
        def handler(*ap, **kp):
            '''Executes the captured function with the arguments `ap` and keywords `kp` trapping any of the captured exceptions and transforming them to the captured handlers.'''
            try:
                return F(*Fchain(a, ap), **{key : value for key, value in Fchain(k.items(), kp.items())})
            except BaseException as E:
                cls, result, tb = sys.exc_info()
                processor = processors[cls] if cls in processors else processors[None] if None in processors else result
            return processor(*ap, **{key : value for key, value in kp.items()}) if callable(processor) else processor
        return handler
    def Fhandlers(*handlers, **map_handlers):
        '''Return a closure that will call a function trapping any captured exceptions with the given `handlers` and any matching exceptions with `map_handlers`.'''
        matches = {key for key in map_exceptions} & {key for key in map_handlers}
        processors = {exception : handler for exception, handler in Fchain(zip(exceptions, handlers + len(exceptions) * (None,)), [(map_exceptions[key], map_handlers[key]) for key in matches])}
        return Fpartial(Fcallable, processors)
    return Fhandlers
# boolean inversion of the result of a function
fcomplement = fnot = frpartial(fcompose, operator.not_)
# converts a list to an iterator, or an iterator to a list
ilist, liter = fcompose(builtins.iter, builtins.list), fcompose(builtins.list, builtins.iter)
# converts a tuple to an iterator, or an iterator to a tuple
ituple, titer = fcompose(builtins.iter, builtins.tuple), fcompose(builtins.tuple, builtins.iter)
# take `count` number of elements from an iterator
itake = lambda count: fcompose(builtins.iter, frpartial(itertools.islice, count), builtins.tuple)
# get the `nth` element from a thing.
iget = lambda count: fcompose(builtins.iter, frpartial(itertools.islice, count), builtins.tuple, operator.itemgetter(-1))
nth = lambda count: fcompose(builtins.iter, frpartial(itertools.islice, 1 + count), builtins.tuple, operator.itemgetter(-1))
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

def alphanumerickey(item):
    '''split a string into its alpha and numeric parts'''
    if item.isalpha():
        return item
    runs, iterable = [ch.isdigit() for ch in item], iter(item)
    consumeguide = [(isnumeric, len([item for item in items])) for isnumeric, items in itertools.groupby(runs, bool)]
    parts = []
    for numeric, length in consumeguide:
        part = ''.join(item for _, item in zip(range(length), iterable))
        if numeric:
            parts.append(int(part))
        else:
            parts.append(part)
        continue
    return parts

### define some generalized ptypes to use
try:
    import ptypes
    from ptypes import bitmap

except ImportError:
    pass

else:
    from ptypes import *

    class u8(pint.uint_t): length=1
    class u16(pint.uint_t): length=2
    class u32(pint.uint_t): length=4
    class u24(pint.uint_t): length=3
    class u64(pint.uint_t): length=8
    class u128(pint.uint_t): length=16

    class s8(pint.sint_t): length=1
    class s16(pint.sint_t): length=2
    class s32(pint.sint_t): length=4
    class s24(pint.sint_t): length=3
    class s64(pint.sint_t): length=8
    class s128(pint.sint_t): length=16

def compress(data):
    obj = zlib.compressobj(level=9, wbits=-9)
    obj.compress(data)
    return obj.flush()

def decompress(data):
    return zlib.decompress(data, wbits=-9)

p = __import__('six').print_ if sys.version_info.major <3 else eval('print')
pp, pf = __import__('pprint').pprint, __import__('pprint').pformat

# minor wolfram stuff
#__import__('atexit').register(lambda: print('stopping'))

try:
    import wolframclient
    import wolframclient.evaluation
    W = wolframclient.evaluation.WolframLanguageSession ()
    __import__('atexit').register(lambda session: session.stop(), W)

    import wolframclient.language
    wl, wlexpr = wolframclient.language.wl, wolframclient.language.wlexpr

except ImportError:
    pass

def progression(length, iterable, width=72):
    import sys, math
    write, flush = (getattr(sys.stdout, attribute) for attribute in ['write', 'flush'])
    for index, item in enumerate(iterable):
        blocks = math.trunc(width * index / length)
        bar = '█' * blocks
        spaces = ' ' * (width - blocks)
        parts = [
            "{:.2f}% ".format(100 * index / length),
            '|',
            bar,
            spaces,
            '|',
            "{:d}/{:d}".format(index, length),
        ]
        write('\033[s'), flush()
        write(''.join(parts)), flush()
        yield item
        write('\033[u'), flush()

    write('\033[s'), flush()
    write(''.join(["{:.1f}% ".format(100), '|', '█' * width, '|', "{:d}/{:d}".format(length, length)])), flush()
    write('\033[u'), flush()
    write('\n'), flush()
