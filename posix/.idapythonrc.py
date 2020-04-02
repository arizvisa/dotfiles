import functools, itertools, types, builtins, operator, six
import logging, user
logging.root = logging.RootLogger(logging.WARNING)

import function as fn

try:
    import sys, ptypes

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

def top(ea=None):
    return fn.top(whereami(ea))

hex = '{:x}'.format

def memberFromOp(st, ea, opnum):
    sizelookup = {1:'b',2:'w',4:'d',8:'',16:'q'}
    offset, size = ins.op(ea, opnum).offset, ins.op_size(ea, opnum)
    name = 'v'+sizelookup[size]
    return st.members.add((name,offset), (int, size), offset)
mop = memberFromOp

dbname = fcompose(fmap(fbox, fcompose(fbox, first, fcondition(finstance(int))(db.offset, fdiscard(db.offset)), fbox)), funbox(itertools.chain), funbox(db.name))
fnname = fcompose(fmap(fbox, fcompose(fbox, first, fcondition(finstance(int))(func.offset, fdiscard(func.offset)), fbox)), funbox(itertools.chain), funbox(func.name))
selectall = fcompose(db.selectcontents, fpartial(imap, funbox(func.select)), funbox(itertools.chain))

has_immediate_ops = fcompose(fmap(fpartial(fpartial, ins.op_type), ins.ops_read), funbox(map), set, fmap(fcompose(len,fpartial(operator.eq, 1)), freverse(operator.contains, 'immediate')), all)
has_register_ops = fcompose(fmap(fpartial(fpartial, ins.op_type), ins.ops_read), funbox(map), set, fmap(fcompose(len,fpartial(operator.eq, 1)), freverse(operator.contains, 'register')), all)
previous_written = fcompose(fmap(fidentity, fcompose(fmap(fpartial(fpartial, ins.op), ins.ops_read), funbox(map), set)), tuple, fmap(fcompose(first,fbox), fcompose(second,list)), funbox(zip), iget(1), funbox(db.a.prevreg, write=1))

freg_written = lambda reg: lambda ea: any(reg.relatedQ(ins.op(ea, i)) for i in ins.ops_write(ea) if ins.opt(ea, i) == 'register')
freg = lambda reg: lambda ea: any(reg.relatedQ(ins.op(ea, i)) for i in ins.ops_read(ea) if isinstance(ins.op(ea, i), symbol_t)) or any(reg.relatedQ(ins.op(ea, i)) for i in ins.ops_write(ea) if isinstance(ins.op(ea, i), symbol_t) and ins.opt(ea, i) == 'register') or any(any(r.relatedQ(reg) for r in ins.op(ea, i).symbols) for i in range(ins.ops_count(ea)) if ins.opt(ea, i) == 'phrase')

