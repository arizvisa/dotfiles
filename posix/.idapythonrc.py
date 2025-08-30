import functools, itertools, types, builtins, operator, six
import sys, logging, importlib, fnmatch, re, pprint, ctypes

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
def dbname(ea, *args, **kwds):
    if not isinstance(ea, int):
        return db.name(*ichain([ea], args, [db.offset()]), **kwds)
    return db.name(ea, *ichain(args, [db.offset(ea)]), **kwds)

fnname = fcompose(fthrough(fpack(fidentity), fcompose(fpack(fidentity), first, fcondition(finstance(int))(func.offset, fdiscard(func.offset)), fpack(fidentity))), funpack(itertools.chain), funpack(func.name, listed=True))
def fnname(ea, *args, **kwds):
    kwds.setdefault('listed', True)
    if not isinstance(ea, int):
        res = func.name(*ichain([ea], args, [func.offset()]), **kwds)
        args = func.args.names([])
    else:
        res = func.name(ea, *ichain(args, [func.offset(ea)]), **kwds)
        args = func.args.names(ea, [])
    return res, args

selectall = fcompose(db.selectcontents, fpartial(imap, funpack(func.select)), funpack(itertools.chain))
def selectall(*required, **kwds):
    F = lambda item: [item] if isinstance(item, str) else item
    required = {k for k in required}
    required |= {k for k in ichain(*map(F, (kwds.get(k, []) for k in ['And', 'require', 'requires', 'required'])))}
    included = {k for k in ichain(*map(F, (kwds.get(k, []) for k in ['Or', 'include', 'includes', 'included'])))}
    contents = {'required':required} if required else {'included':included}
    for f, res in db.selectcontents(**contents):
        for item in func.select(f, required=required, included=included):
            yield item
        continue
    return

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

import hook, ida_hexrays #, hexrays
def on_hint_function(vu, comment=__import__('internal').comment):
    excluded = {'__typeinfo__', '__name__', '__color__'}
    if not vu.get_current_item(ida_hexrays.USE_MOUSE):
        return
    citem = vu.item
    if citem.citype not in {ida_hexrays.VDI_EXPR, ida_hexrays.VDI_FUNC}:
        return

    if citem.citype == ida_hexrays.VDI_EXPR:
        cexpr = citem.e
        if cexpr.op != ida_hexrays.cot_obj:
            return

        elif not func.has(cexpr.obj_ea):
            return

        f = cexpr.obj_ea

    elif citem.citype == ida_hexrays.VDI_FUNC:
        cfunc = citem.f
        f = cfunc.entry_ea

    tags, used = func.tag(f), func.tags(f)
    filtered = {name : value for name, value in tags.items() if name not in excluded}
    encoded = comment.encode(filtered).split('\n') if filtered else []
    contents = "(contents) {!r}".format(used)
    lines = [ item for item in itertools.chain(map("// {:s}".format, encoded), [contents] if used else []) ]
    return (0, "{:s}\n".format('\n'.join(lines)), len(lines)) if lines else 0

def on_hint_global(vu, comment=__import__('internal').comment):
    excluded = {'__typeinfo__', '__name__', '__color__'}
    if not vu.get_current_item(ida_hexrays.USE_MOUSE):
        return
    citem = vu.item
    if citem.citype != ida_hexrays.VDI_EXPR:
        return

    cexpr = citem.e
    if cexpr.op != ida_hexrays.cot_obj:
        return
    if func.has(cexpr.obj_ea):
        return

    ea = cexpr.obj_ea
    ti, tags = db.type(ea), db.tag(ea)
    filtered = {name : value for name, value in tags.items() if name not in excluded}
    encoded = comment.encode(filtered).split('\n') if filtered else []
    data_description = [ item for item in itertools.chain(map("// {:s}".format, encoded)) ]

    if ti and struc.has(ti):
        type = struc.by(ti).tag()
        filtered = {name : value for name, value in type.items() if name not in excluded}
        type_description = map(fpartial("({!s}) {:s}".format, ti), comment.encode(filtered).split('\n')) if filtered else []

    else:
        type_description = []

    lines = [line for line in itertools.chain(data_description, type_description)]
    return (0, "{:s}\n".format('\n'.join(lines)), len(lines)) if lines else 0

def on_hint_lvar(vu, comment=__import__('internal').comment):
    excluded = {'__name__', '__typeinfo__'}
    if not vu.get_current_item(ida_hexrays.USE_MOUSE):
        return
    citem = vu.item
    if citem.citype != ida_hexrays.VDI_EXPR:
        return

    cexpr = citem.e
    if cexpr.op != ida_hexrays.cot_var:
        return

    var_ref = cexpr.v
    mba, lvar = var_ref.mba, var_ref.getv()
    ti, storage = hexrays.variable.type(lvar), hexrays.variable.storage(lvar)
    tags = hexrays.variable.tag(lvar)
    filtered = {name : value for name, value in tags.items() if name not in excluded}

    # if there weren't any tags, then look in the frame for some.
    frame = func.frame(mba.entry_ea) if func.t.frame(mba.entry_ea) else None
    try:
        if not filtered and frame:
            member = frame.by(storage)
            tags = member.tag()
            ti = ti if struc.has(ti) else member.typeinfo

    except LookupError:
        pass

    filtered = {name : value for name, value in tags.items() if name not in excluded}
    member_description = comment.encode(filtered).split('\n') if filtered else []

    if struc.has(ti):
        type = struc.by(ti).tag()
        filtered = {name : value for name, value in type.items() if name not in excluded}
        type_description = map(fpartial("({!s}) {:s}".format, ti), comment.encode(filtered).split('\n')) if filtered else []

    else:
        type_description = []

    lines = [line for line in itertools.chain(member_description, type_description)]
    return (0, "{:s}\n".format('\n'.join(map("// {:s}".format, lines))), len(lines)) if lines else 0

def on_hint_vardecl(vu, comment=__import__('internal').comment):
    excluded = {'__name__', '__typeinfo__'}
    if not vu.get_current_item(ida_hexrays.USE_MOUSE):
        return
    citem = vu.item
    if citem.citype != ida_hexrays.VDI_LVAR:
        return
    lvar = citem.l
    ti, storage = hexrays.variable.type(lvar), hexrays.variable.storage(lvar)
    tags = hexrays.variable.tag(lvar)
    filtered = {name : value for name, value in tags.items() if name not in excluded}

    # if there weren't any tags, then look in the frame for some.
    frame = func.frame(lvar.defea) if func.type.frame(lvar.defea) else None
    try:
        if not filtered and frame:
            member = frame.by(storage)
            tags = member.tag()
            ti = ti if struc.has(ti) else member.typeinfo

    except LookupError:
        pass

    filtered = {name : value for name, value in tags.items() if name not in excluded}
    member_description = comment.encode(filtered).split('\n') if filtered else []

    if struc.has(ti):
        type = struc.by(ti).tag()
        filtered = {name : value for name, value in type.items() if name not in excluded}
        type_description = map(fpartial("({!s}) {:s}".format, ti), comment.encode(filtered).split('\n')) if filtered else []

    else:
        type_description = []

    lines = [line for line in itertools.chain(member_description, type_description)]
    return (0, "{:s}\n".format('\n'.join(map("// {:s}".format, lines))), len(lines)) if lines else 0

def on_hint_memref(vu, comment=__import__('internal').comment):
    excluded = {'__typeinfo__', '__name__', '__color__'}
    if not vu.get_current_item(ida_hexrays.USE_MOUSE):
        return

    citem = vu.item
    if citem.citype != ida_hexrays.VDI_EXPR:
        return

    cexpr = citem.e
    if cexpr.op == ida_hexrays.cot_memptr:
        memptr = cexpr
    elif cexpr.op == ida_hexrays.cot_memref:
        memref = cexpr
    else:
        return

    res, item = [], cexpr
    while item.op in {ida_hexrays.cot_memptr, ida_hexrays.cot_memref}:
        res.append((item.x, item.m))
        item = item.x

    # FIXME: item.opname == 'idx'
    # FIXME: item.opname == 'ptr'
    # FIXME: item.opname == 'obj'
    assert(item.op in {ida_hexrays.cot_var, ida_hexrays.cot_call, ida_hexrays.cot_idx, ida_hexrays.cot_obj, ida_hexrays.cot_ptr}), "unexpected op: {:s}".format(item.opname)

    if item.op == ida_hexrays.cot_idx:
        idx = item
        var, num = idx.x, idx.y
        var_ref = var.v
        if not var_ref:
            print("Variable has no type: {:s}".format(hexrays.repr(item)))
            return

        ti = hexrays.variable.type(var_ref)

    elif item.op == ida_hexrays.cot_obj:
        obj_ea = item.obj_ea
        if not db.t.struc.has(obj_ea):
            ti = db.t(obj_ea)
            assert(struc.has(ti)), (hex(obj_ea), 'not a structure (cot_obj)', "{!r}".format("{!s}".format(ti)))
            st = struc.by(ti)
        else:
            st = db.t.struc(obj_ea)
        ti = db.types.by(st)

    elif item.op == ida_hexrays.cot_var:
        var = item
        var_ref = var.v
        ti = hexrays.variable.type(var_ref)

    elif item.op == ida_hexrays.cot_call and item.x.op in {ida_hexrays.cot_helper}:
        assert(item.x.op in {ida_hexrays.cot_obj, ida_hexrays.cot_helper}), "unexpected cot_call.x op: {:s}".format(item.x.opname)

        # helpers are like platform-specific placeholders, so we can't do
        # anything generic with them.
        call = item
        target = call.x
        helper = target.helper

        # cexpr_t
        cfunc = vu.cfunc
        print("Skipping an unsupported helper: {:s}".format(hexrays.repr(cfunc, item)))
        return

    elif item.op == ida_hexrays.cot_call:
        assert(item.x.op in {ida_hexrays.cot_obj}), "unexpected cot_call.x op: {:s}".format(item.x.opname)
        call = item
        obj = call.x
        ti = func.result(obj.obj_ea)

    # FIXME: item.opname == 'ptr'
    elif item.op == ida_hexrays.cot_ptr:
        target, offset = item.x, item.m
        var_ref = target.v
        ti = hexrays.variable.type(var_ref)
        print("Detected a cot_ptr with type: {!s}".format(ti))

    st = struc.by(ti)
    if not res or not st.has(res[-1][1]):
        raise AssertionError('badly implemented op ({:s})'.format(item.opname), item.op, "{!s}".format(ti), st, [x[-1] for x in res[::-1]])

    for _, moffset in res[::-1]:
        if not st.has(moffset):
            break
        member = st.members.by_realoffset(moffset)
        if not struc.has(member.typeinfo):
            break
        st = struc.by(member.typeinfo)

    tags = member.tag()
    filtered = {name : value for name, value in tags.items() if name not in excluded}
    member_description = comment.encode(filtered).split('\n') if filtered else []

    owner = member.parent.tag()
    filtered = {name : value for name, value in owner.items() if name not in excluded}
    owner_description = map(fpartial("({!s}) {:s}".format, ti), comment.encode(filtered).split('\n')) if filtered else []

    lines = [line for line in itertools.chain(member_description, owner_description)]
    return (0, "{:s}\n".format('\n'.join(map("// {:s}".format, lines))), len(lines)) if lines else 0

def on_hint_address(vu, comment=__import__('internal').comment):
    excluded = {}
    if not vu.get_current_item(ida_hexrays.USE_MOUSE):
        return

    citem = vu.item
    if citem.citype != ida_hexrays.VDI_EXPR:
        return

    ea = citem.e.ea
    if ea == idaapi.BADADDR:
        return

    if function.has(ea):
        b = function.block(ea)
        print(b)
        print(db.disasm(b, comments=True))

    tags = db.tag(ea)
    filtered = {name : value for name, value in tags.items() if name not in excluded}
    item_description = comment.encode(filtered).split('\n') if filtered else []
    lines = [line for line in itertools.chain(item_description)]
    return (0, "{:s}\n".format('\n'.join(map("// {:s}".format, lines))), len(lines)) if lines else 0

hook.hx.add(ida_hexrays.hxe_create_hint, on_hint_function)
hook.hx.add(ida_hexrays.hxe_create_hint, on_hint_global)
hook.hx.add(ida_hexrays.hxe_create_hint, on_hint_lvar)
hook.hx.add(ida_hexrays.hxe_create_hint, on_hint_vardecl)
hook.hx.add(ida_hexrays.hxe_create_hint, on_hint_memref)
hook.hx.add(ida_hexrays.hxe_create_hint, on_hint_address)

def hexrays_by_default(plugin):
    if plugin.name == 'Hex-Rays Decompiler':
        import hexrays
        sys.modules['__main__'].hexrays = sys.modules['__main__'].hx = hexrays
    return
hook.ui.add('plugin_loaded', hexrays_by_default)

def reset_args(ea):
    frame, regs = func.frame(ea), func.frame.regs.size(ea)
    for v in hexrays.variables(ea, args=False, like="a*"):
        print(hexrays.repr(v))
        print(hexrays.variable.name(v, None))
    for v in hexrays.variables(ea, local=True, register=False, regex="v[0-9]+$|a.*"):
        ti, store = hexrays.variable.type(v), hexrays.variable.storage(v)
        matches = frame.members(store)
        if len(matches) == 1 and matches[0].location == store:
            matches[0].name = None
        if len(matches) == 1 and int(matches[0].location) == int(store):
            matches[0].typeinfo = ti
        if len(matches) == 1 and matches[0].location == store:
            hexrays.variable.name(v, None)
        if len(matches) != 1 or matches[0].location != store:
            print("skipped ({:d})".format(len(matches)), hexrays.repr(v))
        continue
    for v in hexrays.variables(ea, regex="a[0-9]+$|arg_[0-9A-F]+$", register=False, args=True, user=False):
        print('unnamed', hexrays.variable.name(v, None))
        ti = hexrays.variable.type(v)
        store = hexrays.variable.storage(v)
        assert(not(isinstance(store,register_t))), "{!r}".format(store)
        if ti.is_ptr(): hexrays.variable.name(v, 'ap', int(store-regs))
    return

def type_formatter(storage, t, delta=4):
    Fstackloc = lambda loc: "poi(@{:s}{:+x})".format(ins.reg.esp.name if db.information.bits() < 64 else ins.reg.rsp.name, int(loc+delta))
    Fregister = lambda reg: "@{:s}".format(reg.name)
    Flocation = Fregister if isinstance(storage,register_t) else Fstackloc
    loc, mask, totalmask = Flocation(storage), pow(2, 8 * storage.size) - 1, pow(2, db.information.bits()) - 1

    if not t.is_ptr():
        if mask < totalmask:
            formats = ['%#010p', "%#0{:d}x".format(2+2*storage.size)]
            vals = ["{:s}&~{:#x}".format(loc, mask)]
            vals.append("{:s}&{:#x}".format(loc, mask))
            return '|'.join(formats), vals
        return '%p', ["{:s}".format(loc)]

    target = db.types.dereference(t)
    if target.is_char():
        return r'(%p) \"%ma\"', [loc, loc]
    elif target.get_size() == 2 and target.equals_to(db.types.parse('wchar_t')):
        return r'(%p) \"%mu\"', [loc, loc]
    return '%p', [loc]

def dbg_prototype(ea, delta=4):
    res=[]
    for i, t in enumerate(func.args(ea)):
        res.append((t, func.arg.storage(ea, i), func.arg.name(ea, i)))
    adescs, avals = [], []
    for t, store, n in res:
        aname = ' '.join(["{!s}".format(t).replace(' ',''), n][:2 if n else 1])
        fmt, vals = type_formatter(store, t, delta)
        adescs.append('='.join([aname, fmt])), avals.append(vals)
    descr = ' '.join(["{!s}".format(func.result(ea)).replace(' ',''), func.name(ea)])
    message = "{:s}({:s})".format(descr, ', '.join(adescs))
    pc = "@{:s}".format(arch.promote(ins.reg.ip, db.information.bits()) if delta < db.information.size() else arch.promote(ins.reg.sp, db.information.bits()))
    pcloc = pc if delta < db.information.size() else "poi({:s}{:+x})".format(pc, delta - db.information.size())
    return ".printf\"(%p) {:s}\",{:s}{:s};g".format(app.windbg.escape(message + '\n'), pcloc, ",{:s}".format(','.join(itertools.chain(*avals))) if avals else '')

def regs_written(ea):
    iterable = ichain(*map(fcompose(fthrough(lambda ea: [ea] * ins.ops_count(ea), ins.ops, ins.ops_access), utils.funpack(zip)), func.iterate()))
    iterable = ((ea, op) for ea, op, ax in iterable if isinstance(op, register_t) and 'w' in ax)
    for ea_op in iterable:
        yield ea_op
    return

def fuck(k, *ea):
    axs = tuple(internal.interface.instruction.access(*ea if ea else [ui.current.address()]))
    print('access', axs)
    x = ins.ops_register(*ea, **{k:True})
    print('true', x)
    x = ins.ops_register(*ea, **{k:False})
    print('false', x)

def findtypes(ti, *types):
    collection = internal.interface.typematch(types)
    for index, (k,v) in enumerate(collection.items()):
        print('Collection[{:d}]:'.format(1+index), k, [x for x in map("{!s}".format, v)])
    for index, (type, candidates) in enumerate(internal.interface.typematch.iterate(collection, ti)):
        print("Candidate[{:d}] : {!r} has the following {:d} candidate{:s}: {!r}".format(1 + index, "{!s}".format(type), len(candidates), '' if len(candidates) == 1 else 's', ["{!s}".format(item) for item in candidates]))
    return internal.interface.typematch.use(collection, ti)

def test_typematcher():
    items = ['char','byte','uint8_t']
    goals = [db.types.parse(item) for item in items]
    collection = interface.typematch(goals)

    print('candy', interface.typematch.candidates(collection, db.types.parse('BOOLEAN')))

    s='''
    struct
    {
      unsigned int Data1;
      unsigned __int16 Data2;
      unsigned __int16 Data3;
      unsigned __int8 Data4[8];
    }
    '''

    items = [
            s, 'signed __int8', 'uint8_t', '__int16',
            'unsigned __int8 meh[20]', '_BYTE',
            'unsigned __int8 meh[0]', '_BYTE',
            'unsigned __int8 meh[1]', '_BYTE',
    ]

    tis = [db.types.parse(s) for s in items]
    print('parsed', ["{!s}".format(ti) for ti in tis])
    for item, subs in interface.typematch.select(collection, tis):
        p(item, lmap("{!s}".format, subs))
    return

def selectmembers(**boolean):
    boolean = {key : {item for item in value} if isinstance(value, internal.types.unordered) else {value} for key, value in boolean.items()}
    if not boolean:
        for st in struc.iterate():
            for m in st.members.iterate():
                contents = internal.tags.member.get(m)
                if contents: yield m, contents
            continue
        return

    included, required = ({item for item in itertools.chain(*(boolean.get(B, []) for B in Bs))} for Bs in [['include', 'included', 'includes', 'Or'], ['require', 'required', 'requires', 'And']])
    for st in struc.iterate():
        for m in st.members.iterate():
            contents = internal.tags.member.get(m)
            if not contents:
                continue

            collected, names = {item for item in []}, {tag for tag in contents}
            collected.update(included & names)

            if required:
                if required & names == required:
                    collected.update(required)
                else: continue

            if collected:
                yield m, {tag : contents[tag] for tag in collected}
            continue
        continue
    return

def genvftable():
    bnds = db.a.bounds()
    start, _ =  bnds
    assert(db.unmangled(start).startswith('const ') and "`vftable'" in db.unmangled(start))
    argh = db.get.array(bnds)

    for i, ea in enumerate(argh):
     if 'method.type' in fn.tag(ea) and fn.tag(ea, 'method.type') == 'purecall':
      n = "purecall_{:x}".format(i * 8)
     else:
      n = fn.tag(ea, 'prototype.name')
     ti = db.types.pointer(fn.t(ea))
     p("{:s};".format(idaapi.print_tinfo('', 0, 0, 0, ti, n, '')))

def genvftable():
    bnds = db.a.bounds()
    start, _ =  bnds
    assert(db.unmangled(start).startswith('const ') and "`vftable'" in db.unmangled(start)), 'are you sure this is a vftable?'
    argh = db.get.array(bnds)

    res1, res2={},{}
    for ea, f in zip(db.a(bnds), db.get.array(bnds)):
     n = func.name(f) if '__name__' in fn.tag(f) else fn.tag(f, 'prototype.name') if 'prototype.name' in fn.tag(f) else func.name(f)
     res1.setdefault(n, []).append(ea)
     res2[f] = n

    for ea, f in zip(db.a(bnds), db.get.array(bnds)):
     n = res2[f]
     n = "{:s}_{:x}".format(n, ea - start) if len(res1[n]) > 1 else n
     ti = db.types.pointer(fn.t(f))
     p("{:s};".format(idaapi.print_tinfo('', 0, 0, 0, ti, n, '')))

def fixprototypes():
    candidates = [x for x in func.up(a[0]) if '&' in x and db.unmangled(x)]
    assert(len(candidates) == 1)
    start, = candidates
    assert(db.unmangled(start).startswith('const ') and "`vftable'" in db.unmangled(start))
    stop = db.a.nextlabel(start)
    argh = db.get.array(bounds_t(*map(int,[start, stop])))

    ok = True
    for ea in argh:
     parmesan = fn.tag(ea, 'prototype.parameters')
     gene = fn.args(ea)
     if len(parmesan)+ 1 != len(gene):
      ok = False
      print(hex(ea), len(gene), len(parmesan))

    assert(ok)

    for ea in argh:
     p('from', "{!s}".format(fn.type(ea)))
     fn.result(ea, fn.tag(ea, 'prototype.result'))
     [fn.arg(ea, 1 + i, item) for i, item in enumerate(fn.tag(ea,'prototype.parameters'))]
     p('to', "{!s}".format(fn.type(ea)))
     p()

#def goto_offset_or_address():
#    ea, bounds = ui.ask.address('~Jump address or offset'), database.info.bounds()
#    if bounds.contains(ea):
#        return database.go(ea)
#    elif bounds.contains(database.address.byoffset(ea)):
#        return database.goof(ea)
#    try:
#        res = R.go(ea)
#    except NameError:
#        raise NameError("Could not find translation class `R` in the globals.")
#    return res
##ui.keyboard.map('G', goto_offset_or_address)

def goto_offset_or_address_form(*ctx):
    form = '''
    Jump to address\n\n
    <~J~ump address:$::32::>'
    '''.strip()

    # FIXME: probably better to use a string argument so that we can attempt to
    #        resolve symbols, evaluate expressions, and most importantly...strip
    #        the '`' that windbg includes in its addresses.
    here = database.here()
    address = idaapi.Form.NumericArgument('$', here)
    ok = idaapi.ask_form(form, address.arg)
    if not ok:
        print('''Command "JumpAsk" failed''')
        return here

    ea, bounds = address.value, database.info.bounds()
    if bounds.contains(ea):
        return database.go(ea)
    elif bounds.contains(database.address.byoffset(ea)):
        return database.goof(ea)

    try:
        res = R.go(ea)
    except NameError:
        '''Command "JumpAsk" failed'''
        #raise NameError("Could not find translation class `R` in the globals.")
        logging.error("Could not find translation class `R` in the globals.")
    if not ctx:
        return here
    [context] = ctx
    return context.cur_ea
#ui.keyboard.map('G', goto_offset_or_address_form)
ui.hook.action.add(
    ui.hook.action.new('minsc:goto_address', 'application', dict(
        widget_type={idaapi.BWN_DISASM, idaapi.BWN_PSEUDOCODE},
    ), shortcut = ['G']),
    goto_offset_or_address_form
)

    #s='title\n%A\n%$\n<~J~ump address:$::32::>\n'
    #s = "Sample dialog box\n\n\nThis is sample dialog box for %A\nusing address %$\n<~E~nter value:N::18::>"
    #num = idaapi.Form.NumericArgument('N', value=123)
    #ok = idaapi.ask_form(s, idaapi.Form.StringArgument("PyAskform").arg, idaapi.Form.NumericArgument('$', 0x401000).arg, num.arg)

def test_combobox_form():
    form = '''
    Test combobox\n\n
    <~T~ag name:b:1:::>
    '''.strip()

    qstrvec_t = getattr(idaapi, 'ida_pro')._qstrvec_t if not hasattr(idaapi, '_qstrvec_t') else idaapi._qstrvec_t
    strvec, names = qstrvec_t(), 'a b c d e f g'.split(' ')
    [strvec.add(item) for item in names]
    names = 'a b c d e f g'.split(' ')
    combo = idaapi.Form.DropdownListControl([name for name in names], readonly=False, selval='a')
    ok = idaapi.ask_form(form, *itertools.chain(combo.arg, []))
    return ok, combo.value

class TestEmbeddedChooserClass(idaapi.Choose):
    # XXX: embedded choosers need to be refreshed via Form.RefreshField() in
    #      order for their elements to be updated sufficiently. this can be used
    #      to display the address of each available tag within a function.
    #      perhaps we can display them on the navigation bar too?
    def __init__(self, title, flags=0):
        idaapi.Choose.__init__(self,
                        title,
                        [ ["Address", 10], ["Name", 30] ],
                        flags=flags,
                        embedded=True, width=30, height=6)
        self.items = [
            ["{:#x}".format(i), "func_{:04x}".format(x)]
            for i, x in enumerate(range(4*0x10, 5*0x10))
        ]
        self.icon = 5

    def OnGetLine(self, n):
        print("getline %d" % n)
        return self.items[n]

    def OnGetSize(self):
        n = len(self.items)
        print("getsize -> %d" % n)
        return n

    def OnSelectionChange(self, sel):
        print('selected', sel)
        if 0 in sel:
            self.items = [
                ["{:#x}".format(i), "func_{:04x}".format(x)]
                for i, x in enumerate(range(1*0x10, 2*0x10))
            ]
            print('go', self.Refresh())
        return 1

class MyForm(idaapi.Form):
    def __init__(self):
        #self.invert = False
        #self.EChooser = TestEmbeddedChooserClass("E1", flags=Choose2.CH_MULTI)

        names = 'a b c d e f g'.split(' ')
        combo = idaapi.Form.DropdownListControl([name for name in names], readonly=False, selval='a', width=32, swidth=32)

        controls = self.controls = {}
        controls['ctrlCombobox'] = combo
        controls['ctrlFormchange'] = idaapi.Form.FormChangeCb(self.OnFormChange)
        controls['ctrlInput'] = idaapi.Form.StringInput(width=32, swidth=32)
        controls['ctrlContents'] = idaapi.Form.MultiLineTextControl('', width=32, swidth=32)
        controls['ctrlActivate'] = idaapi.Form.ButtonInput(self.OnClickity)

        self._chooser = chooser = TestEmbeddedChooserClass("Chooser", flags=idaapi.Choose.CH_MULTI|idaapi.Choose.CH_CAN_REFRESH)
        controls['ctrlChooser'] = idaapi.Form.EmbeddedChooserControl(chooser)

        # would be cool to list the addresses of everything tagged using a
        # chooser class.

        description = r"""
        {ctrlFormchange}
        <Dropdown list:{ctrlCombobox}>
        <Text box:{ctrlContents}>
        <Fuck box:{ctrlInput}>
        <Click:{ctrlActivate}>
        <Choose:{ctrlChooser}>
        """

        idaapi.Form.__init__(self, description, controls)

    def OnFormChange(self, fid):
        print('formchange', fid)
        return 1

    def OnClickity(self, button_code):
        print('clik', button_code)

        text = self.GetControlValue(self.ctrlContents)
        text.text = 'whyyy'
        print('current?', text)

        target = idaapi.textctrl_info_t(text='bitchup', flags=32, tabsize=0)
        ok = self.SetControlValue(self.ctrlContents, target)
        print('contents', ok)

        ok = self.SetControlValue(self.ctrlCombobox, 'why')
        print('combo', ok)

        ok = self.SetControlValue(self.ctrlInput, 'fuckingstupid')
        print('inp', ok)


        newitems = [
            ["{:#x}".format(i), "func_{:04x}".format(x)]
            for i, x in enumerate(range(1*0x50, 2*0x60))
        ]
        self.ctrlChooser.chooser.items[:] = newitems
        ok = self.RefreshField(self.ctrlChooser)
        print('choose', ok)
        print('choosing', self.ctrlChooser.value)

        return 1

def test_new_form():
    f = MyForm()
    f, args = f.Compile()
    if True:
        ok = f.Execute()
    else:
        print(args[0])
        print(args[1:])
        ok = 0

    if ok == 1:
        print("Editable: {!s}".format(f.controls))
        print("Editable: {!s}".format({(k,v.value if hasattr(v, 'value') else v) for k, v in f.controls.items()}))
    #f.Free()

    return f

class TagContentsEditFormTabbed(idaapi.Form):
    r'''
    STARTITEM {id:ctrlTagSelection2}
    BUTTON YES* Apply
    BUTTON NO NONE
    BUTTON CANCEL Cancel
    Edit tags for address in function

    {ctrlFormChange}
    <~T~ag:{ctrlTagSelection1}>
    <~V~alue:{ctrlTagValue1}>
    <~R~endered:{ctrlRenderedTags1}>
    <=:R~e~peatable>

    <~T~ag:{ctrlTagSelection2}>
    <~V~alue:{ctrlTagValue2}>
    <~R~endered:{ctrlRenderedTags2}>
    <=:N~o~n-repeatable>
    '''

    def __init__(self, fn, ea):
        controls = {}
        #available = function.tags(fn)
        available = 'synopsis note object prototype original.name'.split(' ')

        formChangeEvent = idaapi.Form.FormChangeCb(self.OnFormChange)
        controls['ctrlFormChange'] = formChangeEvent

        controls['ctrlTagSelection1'] = idaapi.Form.DropdownListControl([name for name in available], readonly=False, selval='a')
        controls['ctrlTagValue1'] = idaapi.Form.StringInput(swidth=72)
        controls['ctrlRenderedTags1'] = idaapi.Form.MultiLineTextControl('', width=900)

        controls['ctrlTagSelection2'] = idaapi.Form.DropdownListControl([name for name in available], readonly=False, selval='a')
        controls['ctrlTagValue2'] = idaapi.Form.StringInput(swidth=72)
        controls['ctrlRenderedTags2'] = idaapi.Form.MultiLineTextControl('', width=900)

        idaapi.Form.__init__(self, self.__doc__.lstrip(), controls)

    def OnFormChange(self, fid):
        print('changed')
        ctrl = self.FindControlById(fid)
        print('control', ctrl)
        return 1

import contextlib
class TagContentsEditForm(idaapi.Form):
    r'''
    STARTITEM {id:ctrlTagSelection}
    BUTTON YES* Apply
    BUTTON NO NONE
    BUTTON CANCEL Cancel
    %s
    {ctrlFormChange}

    <~T~ag:{ctrlTagSelection}>
    <~V~alue:{ctrlTagValue}>
    <~A~dd:{ctrlTagAdd}> <~D~el:{ctrlTagDelete}>

    <R~e~ndered:{ctrlRenderedTags}>
    <##Comment##~R~epeatable:{ctrlCheckRepeatable}>
    <H~i~dden:{ctrlCheckHidden}>{ctrlCheckBoxes}>

    <=:T~a~gs>

    <Choose:{ctrlChooser}>
    <Reload:{ctrlChooserReload}>
    Address: {ctrlAddressLabel}
    <Comment:{ctrlAddressComment}>
    <=:~U~sage>
    '''

    class TagEditorObject(object):
        def __init__(self, cmt, rpt, repeatable):
            #cmt, rpt = (idaapi.get_cmt(ea, boolean) or u'' for boolean in [False, True])
            self._comment = {False: cmt or u'', True: rpt or u''}
            self._repeatable = True if repeatable else False
            self._state = self.decode()
            self._modified = {name for name in []}

        def decode_line(self, line):
            result = internal.interface.collect_t(unicode if sys.version_info.major < 3 else str, operator.add)
            iterable = iter(line)
            try:
                internal.comment.tag.name.decode(iterable, result)
                space = next(iterable)
                return result.get(), str().join(iterable if space == u' ' else itertools.chain(space, iterable))
            except internal.exceptions.InvalidFormatError:
                return '', line

        def decode(self):
            res = {}
            for boolean, value in self._comment.items():
                iterable = map(self.decode_line, filter(None, value.split(u'\n')))
                res[boolean] = {key : value for key, value in iterable}
            return res

        def render(self, repeatable):
            # FIXME: add support for hidden tags
            res = self._state[True if repeatable else False]

            collection = internal.interface.collect_t(unicode if sys.version_info.major < 3 else str, operator.add)
            for key, value in res.items():
                internal.comment.tag.name.encode(iter(key), collection)
                collection.send(u' ')
                collection.send(value)
                collection.send(u'\n')
            return collection.get()

        def sync(self, repeatable):
            encoded = self.render(repeatable)
            self._comment[repeatable] = encoded
            return encoded

        def comment(self, repeatable):
            res = self._comment[True if repeatable else False]
            return res

        def get(self, name, repeatable):
            state = self._state[True if repeatable else False]
            return state.get(name, None)

        def set(self, name, value, repeatable):
            state = self._state[True if repeatable else False]
            res, state[name] = state.get(name, None), value
            self._modified.add(name)
            return res

        def delete(self, name, repeatable):
            state = self._state[True if repeatable else False]
            res = state.pop(name, None)
            self._modified.add(name)
            return res

        def has(self, name, repeatable):
            state = self._state[True if repeatable else False]
            return name in state

        def names(self, repeatable):
            res = self._state[True if repeatable else False]
            return [name for name in sorted(res)]

        def modified(self):
            return [name for name in self._modified]

    def __CommentsOfAddress(self, ea):
        cmt, rpt = (idaapi.get_cmt(ea, boolean) for boolean in [False, True])
        return cmt, rpt

    def __CommentsOfFunction(self, ea):
        cmt, rpt = (idaapi.get_func_cmt(ea, boolean) for boolean in [False, True])
        return cmt, rpt

    def ReadComments(self, ea):
        if self._is_function:
            return self.__CommentsOfFunction(ea)
        return self.__CommentsOfAddress(ea)

    def __init__(self, ea):
        controls = {}

        self._contents, self._global = function.has(ea), not function.has(ea) or function.address(ea) == ea
        self._in_function = function.has(ea)
        self._is_function = function.has(ea) and function.address(ea) == ea
        self._is_address = self._in_function and not self._is_function or not self._in_function

        repeatable = self._is_function or not self._in_function
        cmt, rpt = self.ReadComments(ea)
        self._editor = editor = self.TagEditorObject(cmt, rpt, repeatable)

        self._available = available = sorted(function.tags(ea) if self._in_function and not self._is_function else database.tags())
        default_tag = available[0]

        self._lastchanged = -1

        formChangeEvent = idaapi.Form.FormChangeCb(self.OnFormChange)
        controls['ctrlFormChange'] = formChangeEvent

        # Current View
        controls['ctrlTagSelection'] = idaapi.Form.DropdownListControl([name for name in available], readonly=False, selval=default_tag)
        controls['ctrlTagValue'] = idaapi.Form.StringInput(editor.get(default_tag, repeatable), swidth=72)
        controls['ctrlTagAdd'] = idaapi.Form.ButtonInput(self.OnTagAdd)
        controls['ctrlTagDelete'] = idaapi.Form.ButtonInput(self.OnTagDelete)

        # Rendering
        controls['ctrlRenderedTags'] = idaapi.Form.MultiLineTextControl(editor.comment(repeatable), width=0x60)
        controls['ctrlCheckBoxes'] = idaapi.Form.ChkGroupControl(("ctrlCheckRepeatable", "ctrlCheckHidden"))

        chooser_t = self.TagContentsChooser if self._in_function and not self._is_function else self.TagGlobalsChooser
        self._chooser = chooser = chooser_t(self, ea, embedded=True)
        controls['ctrlChooser'] = idaapi.Form.EmbeddedChooserControl(chooser)
        controls['ctrlChooserReload'] = idaapi.Form.ButtonInput(functools.partial(self.LoadChooser, ea))
        controls['ctrlAddressLabel'] = idaapi.Form.StringLabel("{:+#x}".format(ea))
        controls['ctrlAddressComment'] = idaapi.Form.MultiLineTextControl(rpt if repeatable else cmt, width=0x60)

        title = "Edit tags for address {:#x}{:s}".format(ea, '' if self._in_function and not self._is_function else ' in function')
        idaapi.Form.__init__(self, self.__doc__.lstrip() % title, controls)

    def LoadChooser(self, ea, btn):
        self._chooser.Load(ea)
        self.RefreshField(self.ctrlChooser)

    def GetRepeatable(self):
        ctrl = self.FindControlById(self.ctrlCheckRepeatable.id)
        return ctrl.checked

    def UpdateTagSelection(self):
        editor, repeatable = self._editor, self.GetRepeatable()
        olditems = self._available
        newitems = {item for item in itertools.chain(olditems, editor.names(repeatable))}
        self.ctrlTagSelection.set_items(sorted(newitems))
        ok = self.RefreshField(self.ctrlTagSelection)
        ok = self.RefreshField(self.ctrlChooser)
        return 1

    def UpdateRenderedTags(self, contents):
        flags = [getattr(idaapi.textctrl_info_t, attribute) for attribute in ['TXTF_MODIFIED', 'TXTF_FIXEDFONT']]
        content = idaapi.textctrl_info_t(text=contents, flags=functools.reduce(operator.or_, flags))
        return self.SetControlValue(self.ctrlRenderedTags, content)

    def UpdateCurrentView(self, repeatable):
        editor = self._editor
        ok = self.UpdateRenderedTags(editor.render(repeatable))

        tag = self.GetControlValue(self.ctrlTagSelection)
        value = editor.get(tag, repeatable)

        ok = self.SetControlValue(self.ctrlTagValue, value or u'')
        return 1

    def ClearCurrentView(self):
        ok = self.SetControlValue(self.ctrlTagSelection, '')
        ok = self.SetControlValue(self.ctrlTagValue, '')
        return 1

    def ApplyIndividualTag(self, repeatable):
        editor = self._editor
        tag = self.GetControlValue(self.ctrlTagSelection)
        value = self.GetControlValue(self.ctrlTagValue)
        res = editor.set(tag, value, repeatable)
        ok = self.ClearCurrentView()
        ok = self.UpdateRenderedTags(editor.render(repeatable))

    def RemoveIndividualTag(self, repeatable):
        editor = self._editor
        tag = self.GetControlValue(self.ctrlTagSelection)
        res = editor.delete(tag, repeatable)
        ok = self.ClearCurrentView()
        ok = self.UpdateRenderedTags(editor.render(repeatable))

    def OnTagAdd(self, button_code):
        repeatable = self.GetRepeatable()
        ok = self.ApplyIndividualTag(repeatable)
        ok = self.UpdateTagSelection()
        ok = self.UpdateCurrentView(repeatable)
        return 1

    def OnTagDelete(self, button_code):
        repeatable = self.GetRepeatable()
        ok = self.RemoveIndividualTag(repeatable)
        ok = self.UpdateTagSelection()
        ok = self.UpdateCurrentView(repeatable)
        return 1

    def OnFormChange(self, cid):
        repeatable = self.GetControlValue(self.ctrlCheckRepeatable)
        ctrl, editor = self.FindControlById(cid), self._editor

        # the following doesn't let you do shit to the form on startup because
        # ida is fucking retarded.
        if cid == -1:
            pass

            #repeatable = self._is_function or not self._in_function
            #self.ctrlCheckRepeatable.checked = repeatable
            #self.RefreshField(self.ctrlCheckRepeatable)

        elif cid == self.ctrlTagSelection.id:
            ok = self.UpdateCurrentView(repeatable)

        elif cid == self.ctrlCheckBoxes.id:
            checked, self.ctrlCheckRepeatable.checked = self.ctrlCheckRepeatable.checked, not self.ctrlCheckRepeatable.checked
            self.RefreshField(self.ctrlCheckBoxes)
            ok = self.UpdateCurrentView(not checked)

        elif cid in {self.ctrlTagAdd.id, self.ctrlTagDelete.id}:
            ok = self.SetFocusedField(self.ctrlTagSelection)

        return 1

    def GetComments(self):
        editor = self._editor
        rendered = self.FindControlById(self.ctrlRenderedTags.id)
        repeatable = True if self.GetRepeatable() else False

        res = {}
        res[not repeatable] = editor.render(not repeatable)
        res[repeatable] = rendered.text
        return res

    def UpdateAddressComment(self, ea):
        cmt, rpt = self.ReadComments(ea)
        cmt = cmt or rpt or u''

        flags = [getattr(idaapi.textctrl_info_t, attribute) for attribute in ['TXTF_MODIFIED', 'TXTF_FIXEDFONT']]
        content = idaapi.textctrl_info_t(text=cmt, flags=functools.reduce(operator.or_, flags))
        return self.SetControlValue(self.ctrlAddressComment, content)

    class TagChooser(idaapi.Choose):
        def __init__(self, parent, title, fields, **attributes):
            self._parent = parent
            attributes.setdefault('flags', idaapi.Choose.CH_CAN_REFRESH)
            idaapi.Choose.__init__(self, title, fields, **attributes)
            self.locations = []

        def Update(self, locations):
            self.locations[:] = [
                (ea, sorted(database.tag(ea)))
                for ea in sorted(locations)
            ]

        def OnGetLine(self, index):
            ea, tags = self.locations[index]
            return (
                "{:+#}".format(database.offset(ea)),
                database.disasm(ea),
                "{!s}".format(tags)
            )

        def OnGetSize(self):
            return len(self.locations)

        def OnSelectionChange(self, selected):
            ea, _ = self.locations[selected]
            self._parent.UpdateAddressComment(ea)
            return 1

    class TagContentsChooser(TagChooser):
        def __init__(self, parent, fn, **attributes):
            ea = function.address(fn)
            title = "Contents of function {:#x} : {:s}".format(ea, function.name(fn))
            fields = [
                ['Offset', 10],
                ['Instruction', 16],
                ['Tags', 24],
            ]

            super(TagContentsEditForm.TagContentsChooser, self).__init__(parent, title, fields, **attributes)
            self.Load(fn)

        def Load(self, fn):
            self.icon = 38  # ASM
            self.locations = [(ea, sorted(tags)) for ea, tags in function.select(fn)]

        def Update(self, locations):
            self.locations[:] = [
                (ea, sorted(database.tag(ea)))
                for ea in sorted(locations)
            ]

    class TagGlobalsChooser(TagChooser):
        def __init__(self, parent, fn, **attributes):
            title = 'Tags in database'
            fields = [
                ['Offset', 10],
                ['Instruction', 16],
                ['Tags', 24],
            ]

            super(TagContentsEditForm.TagGlobalsChooser, self).__init__(parent, title, fields, **attributes)
            self.icon = 0
            self.locations = []

        def Load(self, fn):
            iterable = ((ea, idaapi.get_func(ea)) for ea, _ in internal.comment.globals.iterate())
            iterable = ((ea, sorted(function.tag(ea) if f else database.tag(ea))) for ea, f in iterable)
            size = seg.size(fn) // 0x40
            filtered = ((ea, tags) for ea, tags in iterable if fn - size <= ea < fn + size)
            self.locations = [item for item in filtered]

        def Update(self, locations):
            self.locations[:] = [
                (ea, sorted(function.tag(ea) if function.has(ea) and function.address(ea) == ea else database.tag(ea)))
                for ea in sorted(locations)
            ]

    def OnCompile(self, args):
        repeatable = self._is_function or not self._in_function
        self.ctrlCheckRepeatable.checked = repeatable

    @contextlib.contextmanager
    def Modal(self):
        form, args = self.Compile()
        form.OnCompile(args)

        ok = form.Execute()
        try:
            yield form.GetComments() if ok else ()
        finally:
            form.Free()
        return

    # XXX: it would be handy to model all the keys or whatever being
    #      loaded and differentiating the ones that were modified.

def test_tag_form(*a, **k):
    f = TagContentsEditForm(*a, **k)
    with f.Modal() as state:
        if state:
            print('modified', state)
        else:
            print('cancelled')
        return
    return

#class MyAction(idaapi.action_handler_t):
#    def __init__(self, **attributes):
#        idaapi.action_handler_t.__init__(self)
#
#    # ctx = action_activation_ctx_t (action_ctx_base_t)
#    # ['cur_extracted_ea', 'cur_flags']
#    # deprecated: ['form', 'form_title', 'form_type']
#    #TWidget *widget;
#    #twidget_type_t widget_type;     ///< type of current widget
#    #qstring widget_title;           ///< title of current widget
#    #sizevec_t chooser_selection;    ///< current chooser selection (0-based)
#    #const char *action;             ///< action name
#    #ea_t cur_ea;           ///< the current EA of the position in the view
#    #uval_t cur_value;      ///< the possible address, or value the cursor is positioned on
#    #func_t *cur_func;      ///< the current function
#    #func_t *cur_fchunk;    ///< the current function chunk
#    #struc_t *cur_struc;    ///< the current structure
#    #member_t *cur_strmem;  ///< the current structure member
#    #enum_t cur_enum;       ///< the current enum
#    #segment_t *cur_seg;    ///< the current segment
#    #action_ctx_base_cur_sel_t cur_sel; ///< the currently selected range. also see #ACF_HAS_SELECTION
#    #const char *regname;   ///< register name (if widget_type == BWN_CPUREGS and context menu opened on register)
#    #TWidget *focus;        ///< The focused widget in case it is not the 'form' itself (e.g., the 'quick filter' input in choosers.)
#    #screen_graph_selection_t *graph_selection; ///< the current graph selection (if in a graph view)
#    #const_t cur_enum_member;
#    #dirtree_selection_t *dirtree_selection; ///< the current dirtree_t selection (if applicable)
#    #action_ctx_base_source_t source; ///< the underlying chooser_base_t (if 'widget' is a chooser widget)
#    #til_type_ref_t *type_ref; ///< a reference to the current type (if 'widget' is a types listing widget; nullptr otherwise)
#
#    def activate(self, ctx):
#        print('activate', [ctx.widget_type, ctx.widget_title])
#        #print('activate', 'form', [ctx.form_type, ctx.form_title])
#        return 1
#
#    def update(self, ctx):
#        print('update', [ctx.widget_type, ctx.widget_title])
#        #print('update', 'form', [ctx.form_type, ctx.form_title])
#
#        targets = [
#            idaapi.BWN_STRUCTS,
#            idaapi.BWN_ENUMS,
#            idaapi.BWN_LOCTYPS,
#            idaapi.BWN_PSEUDOCODE,
#            idaapi.BWN_TILIST,
#        ]
#
#        if ctx.widget_type in targets:
#            return ida_kernwin.AST_ENABLE_FOR_WIDGET
#        #return ida_kernwin.AST_ENABLE_ALWAYS
#        #return ida_kernwin.AST_ENABLE_FOR_IDB
#        return ida_kernwin.AST_DISABLE_FOR_WIDGET

#def test_action(*a, **k):
#    action_name = 'sample:action_name'
#    shortcut = 'Z'
#    icon = 38
#    flags = [idaapi.ADF_OWN_HANDLER, idaapi.ADF_OT_PLUGIN]
#
#    callback = MyAction()
#
#    act = idaapi.action_desc_t(
#        action_name,
#        'this is a label',
#        None,
#        shortcut,
#        'this is a tooltip',
#        icon,
#        functools.reduce(operator.or_, flags),
#    )
#
#    if not idaapi.register_action(act):
#        raise DisassemblerError('unable to register action')
#
#    # idaapi.SETMENU_INS - insert
#    # idaapi.SETMENU_APP - append
#    # idaapi.SETMENU_FIRST - beginning
#    # idaapi.SETMENU_ENSURE_SEP - (flag) separator
#    if not idaapi.attach_action_to_menu('Windows/Sample', action_name, idaapi.SETMENU_APP):
#        print('failed attaching menu')
#    if not idaapi.attach_action_to_toolbar('AnalysisToolbar', action_name):
#        print('failed attaching toolbar')
#
#    widget = ui.widget.form(ui.widget.by('IDA View-A'))
#    popup_handle = popup_path = None
#    setmenu_flags = 0
#    #if not idaapi.attach_action_to_popup(widget, popup_handle, action_name, popup_path, setmenu_flags):
#    #    print('failed attaching to popup')
#
#    return
#    if not idaapi.unregister_action(action_name):
#        print('failed to unregister action')
#    return

def test_action():
    action_name = 'sample:action_name'
    label = 'this is a label'
    shortcut = 'Ctrl+Alt+Z'
    tip = 'this is a tooltip'
    icon = 38

    match = {'widget_type': [idaapi.BWN_STRUCTS, idaapi.BWN_ENUMS, idaapi.BWN_LOCTYPS, idaapi.BWN_PSEUDOCODE, idaapi.BWN_TILIST, idaapi.BWN_DISASM]}
    #action = ui.hook.action.new(action_name, 'application', match, shortcut=shortcut, icon=icon, label=label, icon=icon, tooltip=tip)
    action = ui.hook.action.new(action_name, match, shortcut=shortcut, icon=icon, label=label, tooltip=tip)

    callback = lambda ctx: print('activate', [ctx.widget_type, ctx.widget_title])
    callback2 = lambda ctx: print("{:#x}".format(ctx.cur_ea))
    print(hook.action.add(action, callback), hook.action.add(action, callback2))

    # idaapi.SETMENU_INS - insert
    # idaapi.SETMENU_APP - append
    # idaapi.SETMENU_FIRST - beginning
    # idaapi.SETMENU_ENSURE_SEP - (flag) separator
    if not idaapi.attach_action_to_menu('Windows/Sample', action_name, idaapi.SETMENU_APP):
        print('failed attaching menu')
    if not idaapi.attach_action_to_toolbar('AnalysisToolbar', action_name):
        print('failed attaching toolbar')

    widget = ui.widget.form(ui.widget.by('IDA View-A'))
    popup_handle = popup_path = None
    setmenu_flags = 0
    #if not idaapi.attach_action_to_popup(widget, popup_handle, action_name, popup_path, setmenu_flags):
    #    print('failed attaching to popup')

def tagfilter(iterable):
    def iterator(*dictionary, **matches):
        matches.update(*dictionary) if dictionary else ()
        for ea, res in iterable:
            if all(k in res and res[k] == v for k, v in matches.items()):
                yield ea, res
            continue
        return
    return iterator

def touch(ea, *label, **prefix):
    ea = db.a(ea)
    assert(db.t.data(ea)), 'not data {:#x}'.format(ea)
    assert(not(func.has(ea))), 'not data {:#x}'.format(ea)
    has_type = '__typeinfo__' in db.tag(ea)
    listed = not(func.has(ea))
    if has_type:
        default = 'gp' if db.t(ea).is_ptr() else 'gv'
    else:
        default = 'gp'
    string = prefix.get('prefix', default)
    return db.name(ea, *ichain([string], label, [db.offset(ea)]), listed=listed)

import internal.netnode as netnode
import internal.tagindex as Index
#logging.root._cache[logging.DEBUG]=True

import hexrays
class struchook(object):
    class idp(object):
        @staticmethod
        def ev_setup_til(*args):
            print('GOT A TYPE LIBRARY SETUP COMON BITCH.', args)
            return

    class hexrays(object):
        @classmethod
        def _emit_vdui(cls, event, vdui):
            cfunc, mba, lasterror = vdui.cfunc, vdui.mba, vdui.last_code
            print("[{:s}] vdui: {:#x} {:#x}".format(event, cfunc.entry_ea, mba.entry_ea))
            print("[{:s}] vdui.last_code: {:#x}".format(event, vdui.last_code & idaapi.BADADDR))
            print("[{:s}] item: {:s}".format(event, hexrays.repr(cfunc, vdui.item)))

        @classmethod
        def lvar_name_changed(cls, vdui, lvar, name, is_user_name):
            event = 'lvar_name_changed'
            cls._emit_vdui(event, vdui)
            cfunc = vdui.cfunc
            print("[{:s}] rename to {!r} ({!s})".format(event, name, is_user_name))
            print("[{:s}] {!s}".format(event, hexrays.repr(cfunc, lvar)))

        @classmethod
        def lvar_type_changed(cls, vdui, lvar, tinfo):
            event = 'lvar_type_changed'
            cls._emit_vdui(event, vdui)
            cfunc = vdui.cfunc
            print("[{:s}] type to {!s}".format(event, interface.tinfo.quoted(tinfo)))
            print("[{:s}] {!s}".format(event, hexrays.repr(cfunc, lvar)))

        @classmethod
        def lvar_cmt_changed(cls, vdui, lvar, cmt):
            event = 'lvar_cmt_changed'
            cls._emit_vdui(event, vdui)
            cfunc = vdui.cfunc
            print("[{:s}] comment to {!r}".format(event, cmt))
            print("[{:s}] {!s}".format(event, hexrays.repr(cfunc, lvar)))

        @classmethod
        def cmt_changed(cls, cfunc, treeloc, cmt):
            event = 'cmt_changed'
            print("[{:s}] function: {:#x}".format(event, cfunc.entry_ea))
            print("[{:s}] location: {!s}".format(event, hexrays.repr(treeloc)))
            print("[{:s}] comment set {!r}".format(event, cmt))

    #class hx(object):
    #    @classmethod
    #    def lxe_lvar_name_changed(cls, vdui, lvar, name, is_user_name):
    #        event = 'lxe_lvar_name_changed'
    #        cls._emit_vdui(event, vdui)
    #        cfunc = vdui.cfunc
    #        print("[{:s}] rename to {!r} ({!s})".format(event, name, is_user_name))
    #        print("[{:s}] {!s}".format(event, hexrays.repr(cfunc, lvar)))

    #    @classmethod
    #    def lxe_lvar_type_changed(cls, vdui, lvar, tinfo):
    #        event = 'lxe_lvar_type_changed'
    #        cls._emit_vdui(event, vdui)
    #        print("[{:s}] type to {!s}".format(event, interface.tinfo.quoted(tinfo)))
    #        print("[{:s}] {!s}".format(event, hexrays.repr(cfunc, lvar)))

    #    @classmethod
    #    def lxe_lvar_cmt_changed(cls, vdui, lvar, cmt):
    #        event = 'lxe_lvar_cmt_changed'
    #        cls._emit_vdui(event, vdui)
    #        print("[{:s}] comment to {!r}".format(event, cmt))
    #        print("[{:s}] {!s}".format(event, hexrays.repr(cfunc, lvar)))

    #    @classmethod
    #    def hxe_cmt_changed(cls, cfunc, treeloc, cmt):
    #        event = 'hxe_cmt_changed'
    #        print("[{:s}] function: {:#x}".format(event, cfunc.entry_ea))
    #        print("[{:s}] location: {!s}".format(event, hexrays.repr(treeloc)))
    #        print("[{:s}] comment set {!r}".format(event, cmt))

#import hook
#for n in dir(struchook):
#    if n.startswith('_'): continue
#    ns = getattr(struchook, n)
#    H = getattr(hook, n)
#    for hn in dir(ns):
#        if hn.startswith('_'): continue
#        f = getattr(ns, hn)
#        t = (f.__doc__ or '').split('(', 1)[0]
#        print('add', hn, H.add(hn, f))
#    continue

#del(f, n, t)
#ui.hook.idp.add('ev_setup_til', lambda *a: print('SETUP_TIL', a, 'SETUP_TIL'*20))
#ui.hook.idp.add('ev_set_idp_options', lambda *a: print('IDP_OPTIONS', a, 'IDP_OPTIONS'*20))
#ui.hook.idp.add('ev_set_proc_options', lambda *a: print('PROC_OPTIONS', a, 'PROC_OPTIONS'*20))
#ui.hook.idb.add('loader_finished', lambda *a: print('LOADER_FINISHED', a, 'LOADER_FINISHED'*20))
#ui.hook.idb.add('compiler_changed', lambda *a: print('COMPILER', a, 'COMPILER'*20))

# FIXME: make this an action to attach to a menu
#def sizeUpATypeFromExpression(cexpr):
def size_em_up(cexpr):
    '''use an expression to find the size of a structure, and create it...word-sized.'''

# FIXME: figure out this batman reference
#def slice_and_dicee(structure, cexpr):
def slice_and_dice_them(structure, cexpr):
    '''use an expression to find fields for a structure, and divvy-up its members into its individual bytes/words/etc.'''

#internal.hooks.logging.setLevel(logging.DEBUG)
#import internal.structure
#importlib.reload(internal.structure)
