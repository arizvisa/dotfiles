import sys,os,itertools,operator,functools,user,__builtin__ as builtin

# use the current virtualenv if it exists
builtin._=os.path.join(user.home.replace('\\',os.sep).replace('/',os.sep),'.python-virtualenv','Scripts' if __import__('platform').system() == 'Windows' else 'bin', 'activate_this.py')
if os.path.exists(builtin._): execfile(builtin._,{'__file__':builtin._})

# add ~/.python/* to python module search path
map(sys.path.append,__import__('glob').iglob(os.path.join(user.home.replace('\\',os.sep).replace('/',os.sep),'.python','*')))

## some functional primitives in the default namespace
# box any specified arguments
box = fbox = lambda *a: a
# return a closure that executes ``f`` with the arguments unboxed.
unbox = funbox = lambda f, *a, **k: lambda *ap, **kp: f(*(a + builtin.reduce(operator.add, builtin.map(builtin.tuple,ap), ())), **builtin.dict(k.items() + kp.items()))
# return a closure that will check that ``object`` is an instance of ``type``.
finstance = lambda type: lambda object: isinstance(object, type)
# return a closure that always returns ``object``.
fconstant = fconst = lambda object: lambda *a, **k: object
# a closure that returns it's argument
fpassthru = fpass = fidentity = identity = lambda object: object
# return the first, second, or third item of a box.
first, second, third = operator.itemgetter(0), operator.itemgetter(1), operator.itemgetter(2)
# return a closure that executes a list of functions one after another from left-to-right
fcompose = compose = lambda *f: builtin.reduce(lambda f1,f2: lambda *a: f1(f2(*a)), builtin.reversed(f))
# return a closure that executes function ``f`` whilst discarding any extra arguments
fdiscard = lambda f: lambda *a, **k: f()
# return a closure that executes function ``crit`` and then executes ``f`` or ``t`` based on whether or not it's successful.
fcondition = fcond = lambda crit: lambda t, f: \
    lambda *a, **k: t(*a, **k) if crit(*a, **k) else f(*a, **k)
# return a closure that takes a list of functions to execute with the provided arguments
fmaplist = fap = lambda *fa: lambda *a, **k: (f(*a, **k) for f in fa)
#lazy = lambda f, state={}: lambda *a, **k: state[(f,a,builtin.tuple(builtin.sorted(k.items())))] if (f,a,builtin.tuple(builtin.sorted(k.items()))) in state else state.setdefault((f,a,builtin.tuple(builtin.sorted(k.items()))), f(*a, **k))
#lazy = lambda f, *a, **k: lambda *ap, **kp: f(*(a+ap), **dict(k.items() + kp.items()))
# return a memoized closure that's lazy and only executes when evaluated
def lazy(f, *a, **k):
    sortedtuple, state = fcompose(builtin.sorted, builtin.tuple), {}
    def lazy(*ap, **kp):
        A, K = a+ap, sortedtuple(k.items() + kp.items())
        return state[(A,K)] if (A,K) in state else state.setdefault((A,K), f(*A, **builtin.dict(k.items()+kp.items())))
    return lazy
# return a closure that will use the specified arguments to call the provided function
fcurry = lambda *a, **k: lambda f, *ap, **kp: f(*(a+ap), **builtin.dict(k.items() + kp.items()))
# return a closure that executes function ``f`` and includes the exception or None as the first element in the boxed result.
def fcatch(f, *a, **k):
    def fcatch(*a, **k):
        try: return builtin.None, f(*a, **k)
        except: return sys.exc_info()[1], builtin.None
    return functools.partial(fcatch, *a, **k)
fexc = fexception = fcatch
# return a closure that curries the callable in it's argument with the specified args
partial = functools.partial
# converts a list to an iterator, or an iterator to a list
ilist, liter = compose(list, iter), compose(iter, list)
