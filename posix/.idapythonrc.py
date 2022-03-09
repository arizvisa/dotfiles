import functools, itertools, types, builtins, operator, six
import sys, logging, importlib, networkx as nx
#logging.root = logging.RootLogger(logging.WARNING)
#for item in [logging.DEBUG, logging.INFO, logging.WARNING, logging.CRITICAL]:
#    logging.root._cache[item] = True
#logging.root = logging.RootLogger(logging.DEBUG)

import internal, function as fn, ui
if sys.version_info.major < 3:
    pass

else:
    import importlib as imp

ui.hooks.idb.disable('segm_moved')
try:
    import sys, ptypes

    ptypes.setsource(ptypes.prov.Ida)
except ImportError:
    logging.warning('idapythonrc : ignoring external type system due to import error', exc_info=True)

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
    localhost = 'tcp:port=57005,server=127.0.0.1'

    source = None
    def connect(host=localhost):
        global source
        debugger = ptypes.provider.PyDbgEng
        source = pydbgeng.connect(host)
        return ptypes.setsource(source)

    def poi(address):
        return pint.uint32_t(offset=address).l.int()

except ImportError:
    logging.warning('idapythonrc : ignoring external debugger due to import error', exc_info=True)

# shortcuts
def whereami(ea=None):
    res = db.h() if ea is None else ea
    print('{:s}+{:x}'.format(db.module(), db.getoffset(res)))
    return res

def h():
    return whereami(db.h())

def top(ea=None):
    return fn.top(whereami(ea))

hex = '{:x}'.format

def memberFromOp(st, ea, opnum, name=None):
    prefixes = {1: 'b', 2: 'w', 16: 'q'}
    prefixes.update({4: 'd', 8: ''} if db.config.bits() > 32 else {4: '', 8: 'q'})
    offset, size = ins.op(ea, opnum).offset, ins.op_size(ea, opnum)
    prefix = 'v' + prefixes[size]
    packed = (prefix, name, offset) if name else (prefix, offset)
    return st.members.add(packed, (int, size), offset)
mop = memberFromOp

dbname = fcompose(fmap(fpack(fidentity), fcompose(fpack(fidentity), first, fcondition(finstance(int))(db.offset, fdiscard(db.offset)), fpack(fidentity))), funpack(itertools.chain), funpack(db.name))
fnname = fcompose(fmap(fpack(fidentity), fcompose(fpack(fidentity), first, fcondition(finstance(int))(func.offset, fdiscard(func.offset)), fpack(fidentity))), funpack(itertools.chain), funpack(func.name))
selectall = fcompose(db.selectcontents, fpartial(imap, funpack(func.select)), funpack(itertools.chain))

has_immediate_ops = fcompose(fmap(fpartial(fpartial, ins.op_type), ins.opsi_read), funpack(map), set, fmap(fcompose(len,fpartial(operator.eq, 1)), freverse(operator.contains, 'immediate')), all)
has_register_ops = fcompose(fmap(fpartial(fpartial, ins.op_type), ins.opsi_read), funpack(map), set, fmap(fcompose(len,fpartial(operator.eq, 1)), freverse(operator.contains, 'register')), all)
previous_written = fcompose(fmap(fidentity, fcompose(fmap(fpartial(fpartial, ins.op), ins.opsi_read), funpack(map), set)), tuple, fmap(fcompose(first,fpack(fidentity)), fcompose(second,list)), funpack(zip), iget(1), funpack(db.a.prevreg, write=1))

freg_written = lambda reg: lambda ea: any(reg.relatedQ(ins.op(ea, i)) for i in ins.opsi_write(ea) if ins.opt(ea, i) == 'register')
freg = lambda reg: lambda ea: any(reg.relatedQ(ins.op(ea, i)) for i in ins.opsi_read(ea) if isinstance(ins.op(ea, i), symbol_t)) or any(reg.relatedQ(ins.op(ea, i)) for i in ins.opsi_write(ea) if isinstance(ins.op(ea, i), symbol_t) and ins.opt(ea, i) == 'register') or any(any(r.relatedQ(reg) for r in ins.op(ea, i).symbols) for i in range(ins.ops_count(ea)) if ins.opt(ea, i) == 'phrase')

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

### ripped and formatted from some py2 found in an old copy of the custom.ali module.
import itertools,operator,functools

import idaapi
import database as db,function as func,instruction as ins, structure as struc
fn = func

import logging,string,collections
from internal import utils
from string import Template

## types and data structures
from ptypes import *

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

#stores = [(ea,(i,(t1,st))) for ea,(i,[(t1,st),_]) in a.refs() if isinstance(t1,custom.ali.ninsn.op_ref)]
#loads = [(ea,(i,(t2,ld))) for ea,(i,[(t1,st),(t2,ld)]) in a.refs() if isinstance(t2,custom.ali.ninsn.op_ref)]

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
    ea = db.a.walk(ea, db.a.prev, utils.fcompose(fmap(db.t.is_code, utils.fcompose(fn.within, operator.not_)), all))
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

def collect_functions(ea, state=set()):
    children = set(filter(func.within, func.down(ea)))
    for ea in children - state:
        res = collect_functions(ea, state | children)
        state |= res
    return state
