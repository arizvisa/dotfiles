import functools, itertools, types, builtins, operator, six
import sys, logging, importlib
logging.root = logging.RootLogger(logging.WARNING)
#logging.root = logging.RootLogger(logging.DEBUG)

import internal, function as fn
if sys.version_info.major < 3:
    pass
else:
    import importlib as imp

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
    print('{:s}+{:x}'.format(db.module(), db.getoffset(res)))
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
