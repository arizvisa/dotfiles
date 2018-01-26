import logging, user
logging.root=logging.RootLogger(logging.WARNING)

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

def memberFromOp(st, ea, opnum):
    sizelookup = {1:'b',2:'w',4:'d',8:'',16:'q'}
    offset, size = ins.op(ea, opnum).offset, ins.op_size(ea, opnum)
    name = 'v'+sizelookup[size]
    return st.members.add((name,offset), (int, size), offset)
mop = memberFromOp

dbname = fcompose(fap(fbox, fcompose(fboxed, first, fcondition(finstance(int))(db.offset, fdiscard(db.offset)), fboxed)), funbox(itertools.chain), funbox(db.name))
fnname = fcompose(fap(fbox, fcompose(fboxed, first, fcondition(finstance(int))(func.offset, fdiscard(func.offset)), fboxed)), funbox(itertools.chain), funbox(func.name))
selectall = fcompose(db.selectcontents, partial(imap, unbox(func.select)), unbox(itertools.chain))

has_immediate_ops = fcompose(fap(partial(partial, ins.op_type), ins.ops_read), unbox(map), set, fap(fcompose(len,fpartial(operator.eq, 1)), frev(operator.contains, 'immediate')), all)
has_register_ops = fcompose(fap(partial(partial, ins.op_type), ins.ops_read), unbox(map), set, fap(fcompose(len,fpartial(operator.eq, 1)), frev(operator.contains, 'register')), all)
previous_written = fcompose(fap(fid, fcompose(fap(partial(partial, ins.op), ins.ops_read), unbox(map), set)), tuple, fap(compose(first,box), compose(second,list)), unbox(zip), iget(1), funbox(db.a.prevreg, write=1))
