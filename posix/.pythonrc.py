import sys,os,itertools,operator,functools,user,__builtin__

# use the current virtualenv if it exists
__builtin__._=os.path.join(user.home.replace('\\',os.sep).replace('/',os.sep),'.python-virtualenv','Scripts' if __import__('platform').system() == 'Windows' else 'bin', 'activate_this.py')
if os.path.exists(__builtin__._): execfile(__builtin__._,{'__file__':__builtin__._})

# add ~/.python/* to python module search path
map(sys.path.append,__import__('glob').iglob(os.path.join(user.home.replace('\\',os.sep).replace('/',os.sep),'.python','*')))

## include some functional primitives in the default namespace

# box any specified arguments
box = lambda *a: a
# return a closure that executes ``f`` with the arguments unboxed.
unbox = lambda f, *a, **k: lambda *ap, **kp: f(*(a + __builtin__.reduce(operator.add, __builtin__.map(__builtin__.tuple,ap), ())), **__builtin__.dict(k.items() + kp.items()))
# return a closure that always returns ``n``.
identity = lambda n: lambda *a, **k: n
# return the first, second, or third item of a box.
first, second, third = operator.itemgetter(0), operator.itemgetter(1), operator.itemgetter(2)
# return a closure that executes a list of functions one after another from left-to-right
fcompose = compose = lambda *f: __builtin__.reduce(lambda f1,f2: lambda *a: f1(f2(*a)), __builtin__.reversed(f))
# return a closure that executes function ``f`` whilst discarding any extra arguments
fdiscard = lambda f: lambda *a, **k: f()
# return a closure that executes function ``crit`` and then executes ``f`` or ``t`` based on whether or not it's successful.
fcondition = lambda f, t: lambda crit: lambda *a, **k: t(*a, **k) if crit(*a, **k) else f(*a, **k)
# return a closure that takes a list of functions to execute with the provided arguments
fmaplist = fap = lambda *fa: lambda *a, **k: (f(*a, **k) for f in fa)
#lazy = lambda f, state={}: lambda *a, **k: state[(f,a,__builtin__.tuple(__builtin__.sorted(k.items())))] if (f,a,__builtin__.tuple(__builtin__.sorted(k.items()))) in state else state.setdefault((f,a,__builtin__.tuple(__builtin__.sorted(k.items()))), f(*a, **k))
#lazy = lambda f, *a, **k: lambda *ap, **kp: f(*(a+ap), **dict(k.items() + kp.items()))
# return a memoized closure that's lazy and only executes when evaluated
def lazy(f, *a, **k):
    sortedtuple, state = fcompose(__builtin__.sorted, __builtin__.tuple), {}
    def closure(*ap, **kp):
        A, K = a+ap, sortedtuple(k.items() + kp.items())
        return state[(A,K)] if (A,K) in state else state.setdefault((A,K), f(*A, **__builtin__.dict(k.items()+kp.items())))
    return closure
# return a closure that will use the specified arguments to call the provided function
fcurry = lambda *a, **k: lambda f, *ap, **kp: f(*(a+ap), **__builtin__.dict(k.items() + kp.items()))
# return a closure that executes function ``f`` and includes the exception or None as the first element in the boxed result.
def fexception(f, *a, **k):
    def closure(*a, **k):
        try: return __builtin__.None, f(*a, **k)
        except: return sys.exc_info()[1], __builtin__.None
    return functools.partial(closure, *a, **k)
fexc = fexception
