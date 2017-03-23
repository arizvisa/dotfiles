import logging, user
logging.root=logging.RootLogger(logging.WARNING)

from user import *

try:
    import sys,ptypes
    from ptypes import *
    ptypes.setsource(ptypes.prov.Ida)
except ImportError:
    logging.info('idapythonrc : ignoring external type system')

def dump(l):
    result  = []
    for n in l:
        try:
            if type(n) is tuple:
                n = '\t'.join((hex(int(x)) for x in list(n)))

            elif type(int(n)) is int:
                n = hex(n)

        except ValueError:
            n = repr(n)

        result.append(n)
    return '\n'.join(result)

### windbg stuff
try:
    import _PyDbgEng
    localhost = 'tcp:port=57005,server=127.0.0.1'

    z = None
    def connect(host=localhost):
        import _PyDbgEng
        global z
        z = ali.windbg(_PyDbgEng.Connect(localhost))
        return z

    def poi(address):
        return pint.uint32_t(offset=address).l.int()

except ImportError:
    logging.warning('idapythonrc : ignoring external debugger')

# shortcuts
def whereami(ea=None):
    res = db.h() if ea is None else ea
    print '{:s}+{:x}'.format(db.module(), db.getoffset(res))
    return res

def h():
    return whereami(db.h())

import function as fn
def top(ea=None):
    return fn.top(whereami(ea))

hex = '{:x}'.format
