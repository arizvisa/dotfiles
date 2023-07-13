import functools, itertools, types, builtins, operator, six
import sys, logging, importlib, fnmatch, re, pprint

p, pp, pf = p, pprint, pformat = six.print_, pprint.pprint, pprint.pformat

#logging.root = logging.RootLogger(logging.WARNING)

#for item in [logging.DEBUG, logging.INFO, logging.WARNING, logging.CRITICAL]:
#    logging.root._cache[item] = True
#logging.root = logging.RootLogger(logging.DEBUG)

import internal, function as fn, ui
from internal.utils import *

if sys.version_info.major < 3:
    pass

else:
    import importlib as imp

#ui.hooks.idb.disable('segm_moved')
try:
    import sys, ptypes

    ptypes.setsource(ptypes.prov.Ida)
except ImportError:
    logging.warning("{:s} : failure while trying to import external type system ({:s})".format('idapythonrc', 'ptypes'))
    logging.info("{:s} : the exception raised by the {:s} python module was".format('idapythonrc', 'ptypes'), exc_info=True)

def dump(items):
    result  = []
    for item in items:
        try:
            if isinstance(item, (tuple, list)):
                items = item
                row = '\t'.join(("{:x}".format(int(item)) for item in items))

            elif isinstance(int(item), six.integer_types):
                row = "{:x}".format(item)

        except ValueError:
            row = "{!r}".format(item)

        result.append(item)
    return '\n'.join(result)

### windbg stuff
try:
    import _PyDbgEng

    source = None
    def connect(host='tcp:port=57005,server=127.0.0.1'):
        global source
        debugger = ptypes.provider.PyDbgEng
        source = pydbgeng.connect(host)
        return ptypes.setsource(source)

    def poi(address):
        return pint.uint32_t(offset=address).l.int()

except ImportError:
    logging.warning("{:s} : failure while trying to import external debugger ({:s})".format('idapythonrc', 'pydbgeng'))
    logging.info("{:s} : the exception raised by the {:s} python module was".format('idapythonrc', 'pydbgeng'), exc_info=True)

try:
    import pykd

    source = None
    def connect(host='tcp:port=57005,server=127.0.0.1'):
        global source
        pykd.remoteConnect(host)            # because the author of pykd
        source = ptypes.provider.Pykd()     # doesn't know what oop means
        return ptypes.setsource(source)

    def poi(address):
        return pint.uint32_t(offset=address).l.int()

except ImportError:
    logging.warning("{:s} : failure while trying to import external debugger ({:s})".format('idapythonrc', 'pykd'))
    logging.info("{:s} : the exception raised by the {:s} python module was".format('idapythonrc', 'pykd'), exc_info=True)

# shortcuts
def whereami(ea=None):
    res = db.h() if ea is None else ea
    print('{:s}+{:x}'.format(db.module(), db.getoffset(res)))
    return res

def h():
    return whereami(db.h())

def top(ea=None):
    return fn.top(whereami(ea))

def memberFromOp(st, ea, opnum, name=None):
    prefixes = {1: 'b', 2: 'w', 16: 'q'}
    prefixes.update({4: 'd', 8: ''} if db.config.bits() > 32 else {4: '', 8: 'q'})
    offset, size = ins.op(ea, opnum).offset, ins.op_size(ea, opnum)
    prefix = 'v' + prefixes[size]
    packed = (prefix, name, offset) if name else (prefix, offset)
    return st.members.add(packed, (int, size), offset)
mop = memberFromOp

dbname = fcompose(fthrough(fpack(fidentity), fcompose(fpack(fidentity), first, fcondition(finstance(int))(db.offset, fdiscard(db.offset)), fpack(fidentity))), funpack(itertools.chain), funpack(db.name))
fnname = fcompose(fthrough(fpack(fidentity), fcompose(fpack(fidentity), first, fcondition(finstance(int))(func.offset, fdiscard(func.offset)), fpack(fidentity))), funpack(itertools.chain), funpack(func.name, listed=True))
selectall = fcompose(db.selectcontents, fpartial(imap, funpack(func.select)), funpack(itertools.chain))

has_immediate_ops = fcompose(ins.ops_constant, fpartial(map, ins.op), set, fthrough(fcompose(len, operator.truth), fcompose(fpartial(map, finstance(int)), any)), all)
has_register_ops = fcompose(ins.ops_register, fpartial(map, ins.op), set, fthrough(fcompose(len, operator.truth), fcompose(fpartial(map, finstance(register_t)), any)), all)
previous_written = fcompose(ins.ops_read, fthrough(fcompose(first,fgetattr('address'), fpack(list)), fcompose(fpartial(map, ins.op), tuple)), funpack(ichain), list, funpack(db.a.prevreg, write=1))
freg_written = lambda reg: lambda ea: any(reg.related(ins.op(ref)) for ref in ins.ops_write(ea) if isinstance(ins.op(ref), register_t))
freg = lambda reg: lambda ea: any(reg.related(ins.op(ref)) for ref in ins.ops_read(ea) if isinstance(ins.op(ref), symbol_t)) or any(reg.related(ins.op(ref)) for ref in ins.ops_write(ea) if isinstance(ins.op(ref), register_t)) or any(any(reg.related(r) for r in op.symbols) for op in map(fpartial(ins.op, ea), range(ins.ops_count(ea))) if isinstance(op, symbol_t))

def advise(name):
 state = [0]
 def current():
  ea = ui.current.address()
  return ea, ea
 def selected():
  return ui.current.selection()
 def fixup(items, name, message):
  res, item = next(((ea, db.tag(ea, name)) for ea in sorted(items) if name in db.tag(ea)), (None, None))
  if res is None:
   return state[0], len(items), message
  return db.tag(res, name, None)
 def tagger(bounds, message, state=state):
  items = [ea for ea in db.address.iterate(bounds)]
  count, _, _ = fixup(items, name, message)
  db.tag(min(items) if items else bounds.left, name, (count, len(items), message))
  return count
 def ask(question):
  return ui.ask.note(question)
 def closure():
  try:
   bounds = selected()
  except Exception:
   bounds = current()
  message = ask("note or message?")
  if message:
   tagger(bounds, message)
   state[0] += 1
  return
 return closure

def advisegdb(tag, outfile):
 items = {}
 for res in db.selectcontents(t):
  for ea, res in func.select(*res):
   idx, cnt, note = res[t]
   items[idx] = ea, cnt, note
  continue
 with open(rp, 'wt') as outfile:
  for idx in sorted(items):
   ea, cnt, note = items[idx]
   [ six.print_(r'echo # {!s}\n'.format(item.replace('\\', '\\\\')), file=outfile) for item in note.split('\n') ]
   six.print_("x/{:d}i {:#x}".format(cnt, ea), file=outfile)
 return outfile

def strucrefs(structure):
 for item in struc.by(structure).members:
  for ref in item.refs():
   yield ref
  continue
 return

def nameswitch(sw, translate=lambda item: item):
 res = {}
 for c in sw.cases:
  ea = sw.case(c)
  res.setdefault(ea, []).append(c)
 for ea, items in res.items():
  translated = map(translate, items)
  db.name(ea, 'case({:s})'.format(','.join(map("{:x}".format,translated))), db.offset(ea))
 return

### ripped and formatted from some py2 found in an old copy of the application.ali module.
import itertools,operator,functools

import idaapi
import database as db,function as func,instruction as ins, structure as struc
fn = func

import logging,string,collections
from internal import utils
from string import Template

## types and data structures
from ptypes import *

def complexity(G):
    edges = len(G.edges())
    nodes = len(G.nodes())
    parts = nx.components.number_strongly_connected_components(G)
    return edges - nodes + parts

def loops(G):
    for blocks in sorted(nx.simple_cycles(G), key=len):
        yield sorted(blocks)
    return

def paths(G):
    g = G.to_undirected()
    for blocks in sorted(nx.cycle_basis(g)):
        yield sorted(blocks)
    return

def path(G, start, stop):
    f = func.by(G.name)
    b1, b2 = func.block(start), func.block(stop)
    items = nx.shortest_path(G, func.block.address(b1), func.block.address(b2))
    return [func.block(item) for item in items]

def makeptr(info):
    pi = idaapi.ptr_type_data_t()
    pi.obj_type = info
    ti = idaapi.tinfo_t()
    if not ti.create_ptr(pi):
        raise ValueError
    return ti

def get_breakpoint(ea, index=None):
    inputs32 = map("{:#x}".format, itertools.accumulate(itertools.repeat(4), operator.add, initial=4))
    inputs64 = itertools.chain(['@rcx', '@rdx', '@r8', '@r9'], map("{:#x}".format, itertools.accumulate(itertools.repeat(8), operator.add, initial=0x20)))

    fname, names = func.name(ea), func.t.args.names(ea)
    inputs = {32: inputs32, 64:inputs64}[db.config.bits()]
    params = map("{:s}=%p".format, names)
    formatted = "{name:s}({params:s})".format(name=fname, params=', '.join(params))
    message = ".printf \"%p: {:s}\\n\", {:s}{:s};g".format(application.windbg.escape(formatted, 1), '@eip', ", {:s}".format(', '.join(map("poi(@esp+{:s})".format, itertools.islice(inputs, len(names))))) if names else '')
    return "bu{:s} {:s}{:+#x} \"{:s}\"".format('' if index is None else "{:d}".format(index), db.config.module()[:-1], db.offset(ea), application.windbg.escape(message, 1))

# op_t.dtype
class dtype(ptype.definition): cache = {}

@dtype.define
class dt_byte(pint.uint8_t):
    """8 bit"""
    type = idaapi.dt_byte

@dtype.define
class dt_word(pint.uint16_t):
    """16 bit"""
    type = idaapi.dt_word

@dtype.define
class dt_dword(pint.uint32_t):
    """32 bit"""
    type = idaapi.dt_dword

@dtype.define
class dt_float(pfloat.single):
    """4 byte"""
    type = idaapi.dt_float

@dtype.define
class dt_double(pfloat.double):
    """8 byte"""
    type = idaapi.dt_double

#@dtype.define   # XXX
class dt_tbyte(ptype.block):
    """variable size (ph.tbyte_size)"""
    type = idaapi.dt_tbyte

#@dtype.define    # XXX
class dt_packreal(ptype.type):
    """packed real format for mc68040"""
    type = idaapi.dt_packreal

@dtype.define
class dt_qword(pint.uint64_t):
    """64 bit"""
    type = idaapi.dt_qword

@dtype.define
class dt_byte16(pint.uint_t):
    """128 bit"""
    type = idaapi.dt_byte16
    length = 16

@dtype.define
class dt_code(ptype.pointer_t):
    """ptr to code (not used?)"""
    type = idaapi.dt_code
    _object_ = ptype.type

@dtype.define
class dt_void(ptype.undefined):
    """none"""
    type = idaapi.dt_void

@dtype.define
class dt_fword(pint.uint_t):
    """48 bit"""
    type = idaapi.dt_fword
    length = 6

#@dtype.define    # XXX
class dt_bitfild(ptype.type):
    """bit field (mc680x0)"""
    type = idaapi.dt_bitfild

@dtype.define
class dt_string(ptype.pointer_t):
    """pointer to asciiz string"""
    type = idaapi.dt_string
    _object_ = pstr.szstring

@dtype.define
class dt_unicode(ptype.pointer_t):
    """pointer to unicode string"""
    type = idaapi.dt_unicode
    _object_ = pstr.szwstring

#@dtype.define
#class dt_3byte(pint.uint_t):
#    """3-byte data"""
#    type = idaapi.dt_3byte
#    length = 3

@dtype.define
class dt_ldbl(pfloat.double):
    """long double (which may be different from tbyte)"""
    type = idaapi.dt_ldbl
    length = 8

@dtype.define
class dt_byte32(ptype.block):
    """256 bit"""
    type = idaapi.dt_byte32
    length = 32

@dtype.define
class dt_byte64(ptype.block):
    """512 bit"""
    type = idaapi.dt_byte64
    length = 64

class ninsn:
    class op_type(int):
        def get(self): return int(self)
        def __repr__(self): return '%s(%d}'%(self.__class__.__name__,int(self))
    class op_ref(op_type): pass
    class op_reg(op_type): pass
    class op_imm(op_type): pass

    @staticmethod
    def op_group(op):
        res,sz = ins.opt.value(op),ins.opt.size(op)
        if type(res) is tuple:
            offset,(base,index,scale) = res
            if base is None and scale == 1:
                base,index,scale = index,base,scale
            return ninsn.op_ref(sz),(offset,base,index,scale)
        elif type(res) is str:
            return ninsn.op_reg(sz),(res,)
        return ninsn.op_imm(sz),(res,)

    @staticmethod
    def at(ea):
        n = ins.mnem(ea)
        res = ins.operand(ea)
        try:
            res = map(ninsn.op_group, res)
        except Exception as e:
            print(hex(ea),'failed',n,res)
            raise
        return n,res

class block(object):
    def __init__(self, left, right):
        self.cache = list(db.iterate(left,right))
        self.left,self.right = left,right

    def __hash__(self):
        return hash( (self.left,self.right) )
    def __eq__(self, other):
        return (self.left,self.right) == (other.left,other.right)

    def walk(self):
        for ea in self.cache:
            res = i,_ = ninsn.at(ea)
            if i is None: continue
            yield ea,res
        return

    def calls(self):
        for res in self.walk():
            ea,(i,ops) = res
            if i.startswith('call'):
                yield res
            continue
        return

    def stack(self):
        for res in self.walk():
            ea,(i,ops) = res
            if fn.get_spdelta(ea) != fn.get_spdelta(db.next(ea)):
                yield res
            elif any(('esp' in v) or ('ebp' in v) for t, v in ops if isinstance(t, (ninsn.op_reg, ninsn.op_ref))):
                yield res
            continue
        return

    def refs(self):
        for res in self.walk():
            ea,(i,ops) = res
            if any(type(t) is ninsn.op_ref for t, _ in ops):
                yield res
            continue
        return

    def register(self, reg):
        for res in self.walk():
            ea,(i,ops) = res
            if any((reg in v) for t, v in ops if isinstance(t, (ninsn.op_reg, ninsn.op_ref))):
                yield res
            continue
        return

    def instruction(self, *mnem):
        for res in self.walk():
            ea,(i,ops) = res
            if i in mnem:
                yield res
            continue
        return

class tree(object):
    def __init__(self, *functions, **kwds):
        self.blocks = set()
        [self.collect(ea, recurse=kwds.get('recurse',True)) for ea in functions]

    def iterate_blocks(self, ea):
        for l, r in fn.chunks(ea):
            yield block(l,r)
        return

    def collect_calls(self, block):
        for ea, (i, ops) in block.calls():
            (t, v), = ops
            if not isinstance(t,ninsn.op_imm):
                #print hex(ea),'dynamic',(i,ops)
                continue
            yield v[0]
        return

    def collect(self, ea, recurse=True):
        done,result = set(),set((ea,))
        while len(result) > len(done):
            ea = result.pop()
            for b in self.iterate_blocks(ea):
                if recurse:
                    for ea in self.collect_calls(b):
                        try: fn.top(ea)
                        except: pass
                        else: result.add(ea)
                self.blocks.add(b)
            done.add(ea)
        return

    def __getattr__(self, attr):
        def everything(*args,**kwds):
            for b in self.blocks:
                for n in getattr(b, attr)(*args, **kwds):
                    yield n
                continue
            return
        everything.__name__ = attr
        return everything

#stores = [(ea,(i,(t1,st))) for ea,(i,[(t1,st),_]) in a.refs() if isinstance(t1,application.ali.ninsn.op_ref)]
#loads = [(ea,(i,(t2,ld))) for ea,(i,[(t1,st),(t2,ld)]) in a.refs() if isinstance(t2,application.ali.ninsn.op_ref)]

def __collect_ops(ea, recurse=True):
    for ea, (_, ops) in tree(ea, recurse=recurse).walk():
        for t, v in ops:
            yield t,v
        continue
    return

def __collect_refs(ea, recurse=True):
    for t, v in __collect_ops(ea, recurse=recurse):
        if isinstance(t,ninsn.op_ref):
            yield t,v
        continue
    return

def collect_fields(ea, *regs, **kwds):
    for t, (o, b, i, s) in __collect_refs(ea, recurse=kwds.get('recurse', True)):
        # FIXME: s is not the operand size
        if i is not None:
             logging.warn('{:x} : unexpected ref : {!r}'.format(ea, (t, (o, b, i, s))))
        if b not in regs: continue
        yield b,o,t.get()
    return

def collect_struct(ea, reg, name, recurse=False):
    st = struc.get(name)
    for _, o, s in collect_fields(ea, reg, recurse=recurse):
        st.members.add('v_%x'%o, o, (int, s))
    return st

#def get(ea):
#    t = db.getType(ea)

def autostruct(name, regs, left_right, base=0):
    left, right = left_right
    st = struc.get(name)
    for ea, (_, ops) in block(left, right).walk():
        for t, v in ops:
            if isinstance(t, ninsn.op_ref):
                o,b,_,_ = v
                if b in regs:
                    st.members.add('v_%x'%(base+o), base+o, (int, 4))
            continue
        continue
    return st

#def struct2dump(st):
#
#
#'.printf "[%x] {:s}\n",@$t1'.format(st.name + (' // '+st.comment if st.comment else ''))
#'.printf "[%x+{:x}] {:s}\n",@$t1'.format(m.offset, m.fullname + (' // '+m.comment if m.comment else ''))
#'
#
#
#    for m in st.members:
#
#.printf "[%x] %s",{:x},{:s}
#"[%x+%x] %s L%d'

def finddeps(ea, opt, prev=db.address.prev):
    """Walk backwards from ea finding all instructions that assign to a register that affects the current write operand"""
    def registers(operand):
        pass

    def Fgroupkey(i_n):
        i, n = i_n
        return n == 'rw' and 'r' or n

    while True:
        res = dict(itertools.groupby( enumerate(ins.ops_state(ea)), Fgroupkey))
    pass

def findprevwrite(ea):
    w = [i for i, n in enumerate(ins.ops_state(ea)) if 'r' in n]

def invertoperand(ea):
    """When given an address ``ea``, return a callable that takes an address
    which checks if the specified instruction modifies any of the registers
    that are used for the instruction passed to `invertoperand(ea)`.
    """

    def opmatch(ea, regs, opers):
        """Returns True if the instruction at ``ea`` is writing with one of
        the operations specified in ``opers`` and uses any of the registers
        specified in ``regs``.
        """
        related = lambda reg: any(r.relatedQ(reg) for r in regs)
        ops = map(functools.partial(ins.ir.op, ea), ins.ops_write(ea))
        res = filter(utils.fcompose(operator.itemgetter(0), functools.partial(operator.contains, opers)), ops)
        return any((b is not None and related(b)) or (i is not None and related(i)) for _, (o, b, i, s) in res)

    inv = {
        'value':(ins.ir.operation.assign, ins.ir.operation.load),
        'assign':(ins.ir.operation.value, ins.ir.operation.load),
        'load':(ins.ir.operation.assign, ins.ir.operation.load),
        'store':(ins.ir.operation.assign, ins.ir.operation.load),
    }

    # if 'value' is set and there's another ins.ir.operation.value,
    # then that instruction is modifying the specified register.

    ops, registers = set(), set()
    for op, val in map(functools.partial(ins.ir.op, ea), ins.ops_read(ea)):
        o,b,i,s = val
        invops = inv[op.name]
        ops.update(invops)
        if b is not None: registers.add(b)
        if i is not None: registers.add(i)
    return lambda ea: opmatch(ea, tuple(registers), tuple(ops))

import internal
def get_nonfuncs(ea):
    '''Return all the callers to ``ea`` that are not within a function.'''
    return filter(utils.fcompose(fn.within,operator.not_), fn.up(ea))
def get_top(ea):
    """Given an address ``ea`` that's not within a function, attempt to find
    it's top or entry-point by searching for either another function or an
    address that is not code.
    """
    ea = db.a.walk(ea, db.a.prev, utils.fcompose(fthrough(db.t.is_code, utils.fcompose(fn.within, operator.not_)), all))
    return ea if db.t.is_code(ea) and not fn.within(ea) else db.a.next(ea)

# Returns True if a function is only a single-block.
singleblockQ = utils.fcompose(fn.blocks, list, len, functools.partial(operator.eq, 1))

def filter_dynamic(ea, spdelta):
    f = func.by_address(ea)
    res = db.a.prevstack(ea, spdelta)
    if not func.contains(f, res):
        return False
    res = map(functools.partial(ins.op_type, res), ins.ops_read(res))
    return len(res) == 1 and res[0] != 'imm'

def find_stack(target, spdelta):
    start,end = func.block(target)
    res = db.a.prevstack(target, spdelta)
    #if res < start:
    #    raise NotImplementedError("{:x} : Previous stack delta {:d} left the basicblock({:x}:{:x}) : {:x}".format(target, spdelta, start, end, res))

    # use this to repeat searches
    f = invertoperand(res)

    # FIXME: encapsulate the block searches in a coroutine so that one can
    #        call invertoperand to then find the next register dependncy
    #        that's responsible for initializing a register

    # search the first block
    (start,_),end = func.block(res), res
    for ea in db.iterate(end, start):
        if f(ea): return ea

    if not func.contains(target, db.a.prev(start)):
        raise ValueError("{:x} : No matching instruction found. : {:x}".format(target, db.a.prev(start)))

    # if not found, then find the next previous basic bloc
    res = func.block.before(db.a.prev(start))
    while len(res) > 0:
        if len(res) > 1:
            logging.warn("{:x} : More than one basic-block was found. Traversing to {:x}. : [{:s}]".format(target, res[0], ', '.join(map('{:x}'.format, res))))
        start, end = func.block(res[0])
        for ea in db.iterate(end, start):
            if f(ea): return ea
        res = func.block.before(db.a.prev(start))
    raise ValueError("{:x} : No matching instruction found. : {:x}".format(target, ea))

def collect_functions(ea, *state):
    state, = state if state else [set()]
    children = set(filter(func.within, (ref.ea for ea, ref in func.down(ea) if 'x' in ref.access)))
    for ea in children - state:
        res = collect_functions(ea, state | children)
        state |= res
    return state

try:
    import miasm
    import miasm.analysis
    import miasm.analysis.machine
    import miasm.core.bin_stream
    import miasm.core.locationdb
    import miasm.core.utils
    import miasm.expression.expression
    import miasm.ir.symbexec #.SymbolicExecutionEngine

    class bsida(miasm.core.bin_stream.bin_stream_vm):
        def __init__(self, base=None):
            self.base_address, self.offset = base, 0
            self.endianness = miasm.core.utils.LITTLE_ENDIAN
            self.bin = bytearray()  # wtf
        def _getbytes(self, start, l=1):
            base = 0 if self.base_address is None else db.baseaddress()
            return db.read(base + start, l)
        def readbs(self, l=1):
            base = 0 if self.base_address is None else db.baseaddress()
            res = db.read(base + self.offset, l)
            self.offset += len(res)
            return res
        def __bytes__(self):
            raise NotImplementedError('what the fuck are you doing?')

    M32, M64 = (miasm.analysis.machine.Machine('x86_%d'% bits) for bits in [32, 64])
    LDB = miasm.core.locationdb.LocationDB()
    D32, D32 = (M.dis_engine(bsida(), loc_db=LDB) for M in [M32, M64])
    L32, L64 = (M.ir(LDB) for M in [M32, M64])
    S32, S64 = (miasm.ir.symbexec.SymbolicExecutionEngine(L) for L in [L32, L64])

    def expr2method(expr):
        'Expr', 'ExprCompose', 'ExprCond', 'ExprId', 'ExprInt', 'ExprLoc', 'ExprMem', 'ExprOp', 'ExprSlice'
        'eval_expr', 'eval_exprcompose', 'eval_exprcond', 'eval_exprid', 'eval_exprint', 'eval_exprloc', 'eval_exprmem', 'eval_exprop', 'eval_exprslice',

        'ExprAff', 'ExprAssign',
        'eval_updt_expr',
    #exprmap = {
    #    'eval_expr', 'eval_exprcompose', 'eval_exprcond', 'eval_exprid', 'eval_exprint', 'eval_exprloc', 'eval_exprmem', 'eval_exprop', 'eval_exprslice',
    #    'Expr', 'ExprCompose', 'ExprCond', 'ExprId', 'ExprInt', 'ExprLoc', 'ExprMem', 'ExprOp', 'ExprSlice'
    # 'eval_updt_expr',
    # 'eval_updt_assignblk',
    #    'eval_assignblk',
    #'ExprInt1', 'ExprInt16', 'ExprInt32', 'ExprInt64', 'ExprInt8',
    #'ExprInt_from',
    #}
except ImportError:
    logging.warning("{:s} : failure while trying to import the {:s} python module".format('idapythonrc', 'miasm'))
    logging.info("{:s} : the exception raised by the {:s} python module was".format('idapythonrc', 'miasm'), exc_info=True)

def exec32(ea):
    insn = D32.dis_instr(ea)
    for item in L32.get_ir(insn):
        yield item
    return
def exec64(ea):
    insn = D64.dis_instr(ea)
    for item in L64.get_ir(insn):
        yield item
    return

## temporary hexrays things
def find_expr_addr(cfunc, cexpr):
    if cexpr.ea == idaapi.BADADDR:
        while True:
            cexpr = cfunc.body.find_parent_of(cexpr)
            if cexpr is None:
                ea = cfunc.entry_ea
                break
            if cexpr.ea != idaapi.BADADDR:
                ea = cexpr.ea
                break
            continue
        return ea
    return cexpr.ea

def find_addr(vu):
    citem = vu.item
    if citem.citype in {idaapi.VDI_EXPR}:
        return find_expr_addr(vu.cfunc, citem.e)
    elif citem.citype in {idaapi.VDI_TAIL}:
        return citem.loc.ea
    elif citem.citype in {idaapi.VDI_LVAR}:
        return citem.l.defea
    elif citem.citype in {idaapi.VDI_FUNC}:
        return citem.f.entry_ea
    raise NotImplementedError(citem.citype)

class lvars(object):
    @classmethod
    def __iterate__(cls, D):
        lvars = D.get_lvars()
        for index in range(lvars.size()):
            yield lvars[index]
        return

    __matcher__ = internal.utils.matcher()
    __matcher__.boolean('name', lambda name, item: name.lower() == item.lower(), fgetattr('name'))
    __matcher__.combinator('like', utils.fcompose(fnmatch.translate, utils.fpartial(re.compile, flags=re.IGNORECASE), operator.attrgetter('match')), fgetattr('name'))
    __matcher__.predicate('predicate'), __matcher__.predicate('pred')

    @internal.utils.multicase()
    @classmethod
    def iterate(cls, **type):
        return cls.iterate(None, **type)
    @internal.utils.multicase(name=str)
    @classmethod
    def iterate(cls, name, **type):
        return cls.iterate(name, None, **type)
    @internal.utils.multicase(name=str, D=(None.__class__, idaapi.cfuncptr_t))
    @classmethod
    def iterate(cls, name, D, **type):
        type.setdefault('like', name)
        return cls.iterate(D, **type)
    @internal.utils.multicase(D=(None.__class__, idaapi.cfuncptr_t))
    @classmethod
    def iterate(cls, D, **type):
        state = D if D else idaapi.decompile(func.address())
        iterable = cls.__iterate__(state)
        for key, value in (type or {'predicate': utils.fconstant(True)}).items():
            iterable = cls.__matcher__.match(key, value, iterable)
        for item in iterable: yield item

    @internal.utils.multicase()
    @classmethod
    def list(cls, **type):
        return cls.list(None, **type)
    @internal.utils.multicase(name=str)
    @classmethod
    def list(cls, name, **type):
        return cls.list(name, None, **type)
    @internal.utils.multicase(name=str, D=(None.__class__, idaapi.cfuncptr_t))
    @classmethod
    def list(cls, name, D, **type):
        type.setdefault('like', name)
        return cls.list(D, **type)
    @internal.utils.multicase(D=(None.__class__, idaapi.cfuncptr_t))
    @classmethod
    def list(cls, D, **type):
        state = D if D else idaapi.decompile(func.address())
        res = [item for item in cls.iterate(state, **type)]

        print_t = lambda item: idaapi.print_tinfo('', 0, 0, 0, item.type(), item.name, '')

        maxdisasm = max(map(fcompose(fgetattr('defea'), db.disasm, len), res))
        maxname = max(map(fcompose(print_t, len), res))

        for item in res:
            t_s = print_t(item)
            print("{:<{:d}s} // {:<{:d}s} : {!s}".format(db.disasm(item.defea), maxdisasm, t_s, maxname, cls.vdloc(state, item)))
        return

    @internal.utils.multicase()
    @classmethod
    def by(cls, **type):
        return cls.by(None, **type)
    @internal.utils.multicase(name=str)
    @classmethod
    def by(cls, name, **type):
        return cls.by(name, None, **type)
    @internal.utils.multicase(name=str, D=(None.__class__, idaapi.cfuncptr_t))
    @classmethod
    def by(cls, name, D, **type):
        type.setdefault('like', name)
        return cls.by(D, **type)
    @internal.utils.multicase(D=(None.__class__, idaapi.cfuncptr_t))
    @classmethod
    def by(cls, D, **type):
        state = D if D else idaapi.decompile(func.address())
        return next(item for item in cls.iterate(state, **type))

    @internal.utils.multicase()
    @classmethod
    def get(cls, **type):
        return cls.get(None, **type)
    @internal.utils.multicase(name=str)
    @classmethod
    def get(cls, name, **type):
        return cls.get(name, None, **type)
    @internal.utils.multicase(name=str, D=(None.__class__, idaapi.cfuncptr_t))
    @classmethod
    def get(cls, name, D, **type):
        type.setdefault('like', name)
        return cls.get(D, **type)
    @internal.utils.multicase(D=(None.__class__, idaapi.cfuncptr_t))
    @classmethod
    def get(cls, D, **type):
        state = D if D else idaapi.decompile(func.address())
        res = cls.by(state, **type)
        return cls.vdloc(state, res)

    @internal.utils.multicase()
    @classmethod
    def name(cls, **type):
        return cls.name(None, **type)
    @internal.utils.multicase(name=str)
    @classmethod
    def name(cls, name, **type):
        return cls.name(name, None, **type)
    @internal.utils.multicase(name=str, D=(None.__class__, idaapi.cfuncptr_t))
    @classmethod
    def name(cls, name, D, **type):
        type.setdefault('like', name)
        return cls.name(D, **type)
    @internal.utils.multicase(D=(None.__class__, idaapi.cfuncptr_t))
    @classmethod
    def name(cls, D, **type):
        state = D if D else idaapi.decompile(func.address())
        res = cls.by(state, **type)
        return res.name

    @classmethod
    def vdloc(cls, state, lv):
        loc = lv.location
        atype, vtype = loc.atype(), lv.type()
        if atype in {idaapi.ALOC_REG1}:
            regname = idaapi.print_vdloc(loc, vtype.get_size())
            return ins.arch.byname(regname)
        elif atype in {idaapi.ALOC_STACK}:
            fr = func.frame(lv.defea)
            delta = state.get_stkoff_delta()
            realoffset = loc.stkoff() - delta
            return fr.members.by_realoffset(realoffset) if 0 <= realoffset < fr.size else location_t(realoffset, vtype.get_size())
        raise NotImplementedError(atype)

    @classmethod
    def collect_block_xrefs(cls, out, mlist, blk, ins, find_uses):
        p = ins
        while p and not mlist.empty():
            use = blk.build_use_list(p, ida_hexrays.MUST_ACCESS); # things used by the insn
            _def = blk.build_def_list(p, ida_hexrays.MUST_ACCESS); # things defined by the insn
            plst = use if find_uses else _def
            if mlist.has_common(plst):
                if not p.ea in out:
                    out.append(p.ea) # this microinstruction seems to use our operand
            mlist.sub(_def)
            p = p.next if find_uses else p.prev
        return

    @classmethod
    def collect_xrefs(cls, out, ctx, mop, mlist, du, find_uses):
        # first collect the references in the current block
        start = ctx.topins.next if find_uses else ctx.topins.prev;
        cls.collect_block_xrefs(out, mlist, ctx.blk, start, find_uses)

        # then find references in other blocks
        serial = ctx.blk.serial; # block number of the operand
        bc = du[serial]          # chains of that block
        voff = ida_hexrays.voff_t(mop)
        ch = bc.get_chain(voff)   # chain of the operand
        if not ch:
            return # odd
        for bn in ch:
            b = ctx.mba.get_mblock(bn)
            ins = b.head if find_uses else b.tail
            tmp = ida_hexrays.mlist_t()
            tmp.add(mlist)
            cls.collect_block_xrefs(out, tmp, b, ins, find_uses)
        return

    @classmethod
    def microcode(cls, D):
        state = D if D else idaapi.decompile(func.address())
        hf = ida_hexrays.hexrays_failure_t()
        mbr = ida_hexrays.mba_ranges_t(state)
        mba = ida_hexrays.gen_microcode(mbr, hf, None, ida_hexrays.DECOMP_WARNINGS | ida_hexrays.DECOMP_NO_CACHE, ida_hexrays.MMAT_PREOPTIMIZED)
        if not mba:
            raise Exception("{:#x}: {:s}".format(hf.errea, hf.str))
        return mba

    @classmethod
    def _refs(cls, state, lv):
        mba = cls.microcode(state)
        merr = mba.build_graph()
        if merr != ida_hexrays.MERR_OK:
            raise Exception("{:#x}: {:s}".format(errea, ida_hexrays.get_merror_desc(merr, mba)))

        gco = ida_hexrays.gco_info_t()
        if not ida_hexrays.get_current_operand(gco):
            raise Exception("No register or stkvar in operand")

        mlist = ida_hexrays.mlist_t()
        if not gco.append_to_list(mlist, mba):
            raise Exception('no microcode list')

        ctx = ida_hexrays.op_parent_info_t()
        mop = mba.find_mop(ctx, ea, gco.is_def(), mlist)
        if not mop:
            raise Exception('no operand')

        graph = mba.get_graph()
        ud = graph.get_ud(ida_hexrays.GC_REGS_AND_STKVARS)
        du = graph.get_du(ida_hexrays.GC_REGS_AND_STKVARS)

        xrefs = ida_pro.eavec_t()
        if gco.is_use():
            cls.collect_xrefs(xrefs, ctx, mop, mlist, ud, False)
        if gco.is_def():
            cls.collect_xrefs(xrefs, ctx, mop, mlist, du, True)
        return xrefs

    @classmethod
    def refs(cls, D):
        state = D if D else idaapi.decompile(func.address())
        return cls._refs(state, None)

class hxqueue(object):
    def __init__(self, hx, event=idaapi.hxe_create_hint):
        import queue
        self.Q = queue.Queue()
        self.hx = hx
        hx.add(event, self.activate)

    def activate(self, vu):
        item = ui.current.symbol(), vu
        self.Q.put(item)

    def get(self):
        return self.Q.get_nowait()

def hxhint(vu):
    cfunc, citem, mba, cpos = (getattr(vu, item) for item in ['cfunc', 'item', 'mba', 'cpos'])

    # figure out the operand instead of using this symbol name
    symbol = ui.current.symbol()

    if citem.citype in {idaapi.VDI_EXPR, idaapi.VDI_TAIL}:
        ea = find_addr(vu)
        meta = db.tag(ea)
        print(db.disasm(ea), meta)
        result = ea, meta
    elif citem.citype in {idaapi.VDI_LVAR}:
        lv = citem.l
        lvar = lvars.vdloc(vu.cfunc, lv)
        meta = lvar.tag() if hasattr(lvar, 'tag') else {}
        print(lvar, meta)
        result = lvar, meta
    elif citem.citype in {idaapi.VDI_FUNC}:
        f = citem.f
        ea = f.entry_ea
        meta = func.tag(ea)
        print(func.name(ea), func.tags(ea), meta)
        result = ea, meta
    else:
        raise NotImplementedError(citem.citype)
    global _
    _ = result

def hxinstall():
    global hx, Q
    hx = internal.interface.priorityhxevent()
    Q = hxqueue(hx)
    hx.add(idaapi.hxe_curpos, hxhint)

import bz2, pickle
def load(file):
    with open(file if file.startswith('/') else db.config.path(file), 'rb') as infile:
        data = infile.read()
    return pickle.loads(bz2.decompress(data))

def save(file, data):
    compressed = bz2.compress(pickle.dumps(data))
    with open(file if file.startswith('/') else db.config.path(file), 'xb') as outfile:
        outfile.write(compressed)
    return

import zlib
try: import dill
except ImportError: logging.warning("{:s} : unable to import third-party module for serialization ({:s})".format('idapythonrc', 'dill'))

def compress(data):
    obj = zlib.compressobj(level=9, wbits=-9)
    obj.compress(data)
    return obj.flush()

def decompress(data):
    return zlib.decompress(data, wbits=-9)

import internal, tools, application as app
interface = internal.interface
def on():
 logging.root._cache[logging.INFO] = True
def off():
 logging.root._cache[logging.INFO] = False

try:
    import pycosat
except ImportError:
    logging.warning("{:s} : unable to import solver module ({:s})".format('idapythonrc', 'pycosat'))
else:
    class structures:
        @staticmethod
        def collect(st):
            for m in st.members:
                s = m.type
                if isinstance(s, list):
                    s, _ = s
                if isinstance(s, tuple):
                    s, _ = s
                if isinstance(s, struc.structure_t):
                    for item in deps(s):
                        yield item
                    yield st, s
                elif struc.has(m.typeinfo):
                    s = struc.by(m.typeinfo)
                    for item in deps(s):
                        yield item
                    yield st, s
                else:
                    print('unknown type', m)
                continue
            return

        @staticmethod
        def dependencies(iterable):
            res = {}
            for st, dep in iterable:
                res.setdefault(dep, set())
                res.setdefault(st, set()).add(dep)
            return res

        @staticmethod
        def results(start, dependencies):
            rules = {}
            for dep, items in dependencies.items():
                [ rules.setdefault(item, set()) for item in items ]
            rules.update(dependencies)
            assert(start in rules)

            to, of, variables = {}, {}, [item for item in rules]
            for i, item in enumerate(variables):
                to[item], of[1 + i] = 1 + i, item

            clauses = []
            for item, dependencies in rules.items():
                for dependency in dependencies:
                    clauses.append([-to[item], +to[dependency]])
                continue
            clauses.append([+to[start]])

            for solution in pycosat.itersolve(clauses):
                result = [ item for item in solution ]
                yield [ of[item] for item in result ]
            return

        @staticmethod
        def makeptype(st):
            name = st.name.replace('::', '__')
            print('class {:s}(pstruct.type):'.format(name))
            print('    _fields_ = [')
            for offset, size, data in struc.members(st):
                if not data:
                    name = 'field_{:x}'.format(offset)
                    t = 'dynamic.block({:d})'.format(size)
                    print('        ({:s}, {!r}),'.format(t, name))
                    continue
                try:
                    m = st.by_realoffset(offset)
                except exceptions.OutOfBoundsError:
                    m = st.members[-1]
                mname, mtype, ti, count = m.name, m.type, m.typeinfo, 1
                if isinstance(mtype, list):
                    assert(m.typeinfo.is_array())
                    mtype, count = mtype
                    ai = idaapi.array_type_data_t()
                    assert(m.typeinfo.get_array_details(ai))
                    ti, count = ai.elem_type, ai.nelems

                elif isinstance(mtype, tuple):
                    t, sz = mtype
                    if t != type:
                        assert(t == int)
                        tname = "{:s}{:d}".format('s' if sz < 0 else 'u', 8 * abs(sz))
                        print('        ({:s}, {!r}),'.format(tname, mname))
                        continue

                    pi = idaapi.ptr_type_data_t()
                    assert(m.typeinfo.get_ptr_details(pi))
                    ti, ptr = pi.obj_type, True
                    mtype = t

                else:
                    print('        ({!s}, {!r}),'.format(struc.by(ti).name.replace('::','__'), mname))
                    continue

                if isinstance(mtype, tuple):
                    #print('        ({!s}, {!r}),'.format(ti, mname))
                    #raise Exception(m, mname, mtype)
                    t, sz = mtype
                    if t == str:
                        assert(sz in {1, 2})
                        szname = 'pstr.string' if sz == 1 else 'pstr.wstring'
                        fmt = "dyn.clone({:s}, length={count:d})"
                        tname = fmt.format(szname, count=count)
                        print('        ({:s}, {!r}),'.format(tname, mname))
                        continue

                    assert(t in {int, type})
                    tname = "{:s}{:d}".format('s' if sz < 0 else 'u', 8 * abs(sz))
                    fmt = "dyn.array({:s}, {count:d})" if count > 1 else "{:s}"
                    tname = fmt.format(tname, count=count)
                    print('        ({:s}, {!r}),'.format(tname, mname))
                    continue

                if mtype == type and not struc.has(ti):
                    assert(count == 1)
                    print('        (pointer({!s}), {!r}),'.format(ti, mname))
                    continue

                fmt = "dyn.array({:s}, {count:d})" if count > 1 else "{:s}"
                fptr = "pointer({:s})" if mtype == type else "{:s}"
                assert(struc.has(ti))

                sname = struc.by(ti).name.replace('::','__')
                tname = fptr.format(fmt.format(sname, count=count))
                print('        ({:s}, {!r}),'.format(tname, mname))
            print('    ]')

def tibase(ti):
    pi, ai = idaapi.ptr_type_data_t(), idaapi.array_type_data_t()
    while ti.is_ptr() or ti.is_array():
        if ti.is_ptr() and ti.get_ptr_details(pi):
            ti = pi.obj_type
        elif ti.is_array() and ti.get_array_details(ai):
            ti = ai.elem_type
        yield ti
    return

def tiequal(a, b):
    tinfo_equals_to = idaapi.equal_types if idaapi.__version__ < 6.8 else lambda til, t1, t2: t1.equals_to(t2)
    return tinfo_equals_to(idaapi.get_idati(), a, b)

# I was doing something here, but forgot the whole point.
if False:
    import networkx as nx
    G = nx.DiGraph()
    start = db.a.byoffset(0x698a1)
    for ea in collect_functions(start, set()):
        G.add_node(ea)

    def get_calls(f):
        for ea, ref in func.down(f):
            if 'x' in ref.access and func.has(ref.ea):
                yield f, ea, ref.ea
            continue
        return

    def recurse_calls(src, f, G):
        if f in G.nodes.keys():
            return G.add_edge(src, f)
        G.add_node(f)
        G.add_edge(src, f)

        fn, ea, iterable = f, f, get_calls(f)
        while fn == f:
            fn, x, call = next(iterable, (None, None, None))
            G.add_edge(ea, x)
            ea = x
            G.add_edge(ea, call)
            recurse_calls(call, G)

    def get_locations(f):
        locs = {ea : ref.ea for ea, ref in func.down(f) if 'x' in ref.access}
        refs = {func.block(ea) : ref for ea, ref in locs.items()}
        assert(len(locs) == len(refs))
        return refs

    def get_graph_recurse(blk, G, height=0):
        assert(blk in G.nodes)
        items = [func.block(ea, calls=True) for ea in func.block.after(blk)]
        filtered = [item for item in items if item not in G.nodes.keys()]
        [G.add_node(item, height=1+height) for item in items]
        [G.add_edge(blk, item) for item in items if item != blk]
        [get_graph_recurse(item, G, height=1+height) for item in filtered]

    def get_graph(f):
        G, blk = nx.DiGraph(), func.block(f, calls=True)
        G.add_node(blk, height=0)
        get_graph_recurse(blk, G, height=1)
        G.nodes[blk]['entry'] = 1
        for blk, tgt in get_locations(f).items():
            if blk not in G.nodes: continue
            G.nodes[blk]['target'] = tgt
        for ea in func.bottom(f):
            blk = func.block(ea)
            if blk not in G.nodes: continue
            G.nodes[blk]['exit'] = 1
        return G

    f = func.addr()
    G = get_graph(f)

    blocks = {blk : [ea for ea in func.block.iterate(blk)] for blk in func.blocks(f)}
    def unblock(G):
        g = nx.DiGraph()
        for node in G.nodes:
            assert(node.left != node.right)
            g.add_node(node.left), g.add_node(node.right)
            g.add_edge(node.left, node.right)

        for lblk, rblk in G.edges:
            g.add_edge(lblk.right, rblk.left)
        return g

    def attach(g, target, gfunc):
        G = nx.compose(g, gfunc)
        entries = [node for node in gfunc.nodes if gfunc.nodes[node].get('entry', 0)]
        exits = [node for node in gfunc.nodes if gfunc.nodes[node].get('exit', 0)]
        items = [node for node in g.nodes if g.nodes[node].get('target', None) == target]
        for node in items:
            ea = node.right
            targets = [item for item in g.successors(node)]
            [G.remove_edge(node, item) for item in targets]
            [G.add_edge(node, item) for item in entries]
            [[G.add_edge(item, target) for item in exits] for target in targets]
        return G

    ea, processed = func.addr(f), set()
    a = [ea] + [ea for ea in collect_functions(f, set()) if func.has(ea)]
    b = {ea : get_graph(ea) for ea in a}
    c = {ea : (g.copy(), [g.nodes[x]['target'] for x in g.nodes if 'target' in g.nodes[x]]) for ea, g in b.items()}
    def attach_recurse(ea, G, processed=None):
        print(hex(ea))
        processed = set() if processed is None else processed
        G, children = c[ea]
        for item in children:
            if not func.has(item): continue
            g, children = c[item]
            G = attach(G, item, g)
            attach_recurse(item, G, processed | {ea})
        return G
    G, _ = c[ea]
    G = attach_recurse(f, G, processed)

    def renderable(g):
        G, items = nx.DiGraph(), {}
        for blk in g.nodes:
            items[blk] = "n{:X}_to_{:X}".format(*blk)
            f = func.addr(func.by(blk.left))
            col = ['red', 'orange', 'yellow', 'green', 'blue', 'purple', 'violet'][hash(f) %7]
            G.add_node(items[blk], color=col)
        for start, stop in g.edges:
            G.add_edge(items[start], items[stop])
        return G

    nx.nx_pydot.write_dot(renderable(G), '/home/user/t.dot')
    if 'target' not in G.nodes[node]: raise

    def build_calls(G, f, fname=lambda fu: 'node_{:s}'.format(fu).replace('.', '_')):
        g = get_graph(f)
        refs = get_locations(f)
        G = nx.DiGraph() if G is None else G
        for item in g.nodes:
            G.add_node(fname(item))

        G.add_node("func_{:x}".format(func.top(f)))

        for edge in g.edges:
            [G.add_node(ea) for ea in map(fname, itertools.chain(edge))]

        [G.add_edge("func_{:x}".format(func.top(f)), fname(item)) for item in map(func.block, [func.addr()])]
        [G.add_node("func_{:x}".format(ea)) for ea in refs.values()]

        for item in g.nodes:
            if item in refs:
                tgt, exits = refs[item], [ea for ea in func.bottom(refs[item])]
                if func.has(tgt):
                    G.add_edge(fname(item), fname(func.block(tgt)))
                else:
                    G.add_edge(fname(item), "func_{:x}".format(tgt))
            continue

        for edge in g.edges:
            l, r = edge
            G.add_edge(*map(fname, edge))

        for blk, tgt in refs.items():
            G.add_edge(fname(blk), "func_{:x}".format(tgt))

        bottoms = [(item, func.block(item)) for item in func.bottom(f)]
        [G.add_edge(fname(item), "exit_{:x}".format(ea)) for ea, item in bottoms]
        return G

    def fuckeverything(entry):
        G, items = nx.DiGraph(), []
        for ea in collect_functions(entry, set()):
            G.add_node("func_{:x}".format(ea))
            [G.add_node("exit_{:x}".format(item) for item in func.bottom(ea))]
            items.append(ea)

        #for ea in items:
        #    if function.has(ea):
        #        G = build_calls(G, ea)
        #    else:
        #       G.add_edge(

        return G

'''
remove parameter names and types from the following funcs so that they don't propagate.
    malloc
    free
    memset
    memcpy
    memdup
    strdup
    strcpy
    wcscpy
'''
