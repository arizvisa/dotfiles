python import operator,itertools,functools,subprocess

### python helpers
python
import re,string
class function(gdb.Function):
    def __init__(self):
        return super(function, self).__init__(self.__class__.__name__)
class command(gdb.Command):
    def __init__(self):
        return super(command, self).__init__(self.__class__.__name__, getattr(self,'COMMAND',0))
class execute(command):
    def invoke(self, string, from_tty):
        gdb.execute(gdb.parse_and_eval(string).string())
class emit(command):
    COMMAND = gdb.COMMAND_DATA
    def invoke(self, string, from_tty):
        gdb.write(gdb.parse_and_eval(string).string())
        gdb.flush()
class clip(command):
    COMMAND = gdb.COMMAND_DATA
    def invoke(self, string, from_tty):
        res = gdb.parse_and_eval(string)
        try:
            out = "{!s}".format(res.string())
        except gdb.error as E:
            if res.address is not None:
                out = "{:#x}".format(int(res.address))
            elif res.type.code in {gdb.TYPE_CODE_FLT}:
                out = "{!s}".format(float(res))
            elif res.type.is_scalar:
                out = "{:#x}".format(int(res))
            else:
                raise E
        self.xclip(out)

    XA_CLIPBOARD = 'clipboard'
    XA_PRIMARY = 'primary'
    XA_SECONDARY = 'secondary'
    def xclip(self, string):
        clipboards = [self.XA_CLIPBOARD, self.XA_PRIMARY, self.XA_SECONDARY]
        for selection in clipboards:
            gdb.write("sending result to {:s}: {!r}\n".format(selection, string))
            with subprocess.Popen(['xclip', '-selection', selection], close_fds=True, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT) as P:
                stdout, stderr = P.communicate(string.encode('utf-8'))
            continue
        gdb.flush()

    def xsel(self, string):
        clipboards = [self.XA_CLIPBOARD, self.XA_PRIMARY, self.XA_SECONDARY]
        with subprocess.Popen(['xsel', '-i'] + ["--{:s}".format(selection) for selection in clipboards], close_fds=True, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT) as P:
            gdb.write("sending result to {:s}: {!r}\n".format(', '.join(clipboards if len(clipboards) == 1 else clipboards[:-1] + ["and {:s}".format(clipboards[-1])]), string))
            stdout, stderr = P.communicate(string.encode('utf-8'))
        gdb.flush()

    def gtkclip(self, string):
        raise NotImplementedError
    def qtclip(self, string):
        raise NotImplementedError
    def winclip(self, string):
        raise NotImplementedError

class typeof(function):
    def invoke(self, symbol):
        return str(symbol.type).replace(' ','')
class sprintf(function):
    def invoke(self, *args):
        res,formatter,args = '',string.Formatter(),iter(args)
        fmt = re.sub('%(\d+\.?\d+f|0?\d*[\w^\d]|\d*[\w^\d]|-0?\d*[\w^\d]|-\d*[\w^\d])', lambda m:'{:'+m.groups(1)[0]+'}', next(args).string())
        for text,_,typestr,_ in formatter.parse(fmt):
            res += text
            if typestr is None: continue
            realtype,value = typestr[-1],next(args)
            size = value.type.sizeof
            if realtype in 's':
                res += '{:{typestr:s}}'.format(value.string(), typestr=typestr)
            elif realtype in 'dx':
                val = int(value.cast(gdb.lookup_type(intcast(value))))
                absint = (2**(8*size)+val) if val < 0 else val
                if typestr.startswith('-'):
                    res += '{:{typestr:s}}'.format(val, typestr=typestr)
                else:
                    res += '{:{typestr:s}}'.format(absint, typestr=typestr)
            elif realtype == 'p':
                val = int(value.cast(gdb.lookup_type(intcast(value))))
                absint = (2**(8*size)+val) if val < 0 else val
                if typestr.startswith('-'):
                    res += ('-' if val < 0 else '') + '{:#0{size:d}x}'.format(abs(val), size=2+size*2)
                else:
                    res += '{:#0{size:d}x}'.format(absint, size=2+size*2)
            elif realtype == 'f':
                res += '{:{typestr:s}}'.format(float(val), typestr=typestr)
            else:
                raise gdb.error("Unknown format specifier: {:s}".format(typestr))
            continue
        return res
execute(),emit(),typeof(),clip(),sprintf()

def intcast(val):
    if val.type.sizeof == 8:
        return "unsigned long long"
    elif val.type.sizeof == 4:
        return "unsigned int"
    elif val.type.sizeof == 2:
        return "unsigned short"
    elif val.type.sizeof == 1:
        return "unsigned char"
    raise NotImplementedError(val.type)

def parsenum(string):
    if string.startswith('0x'):
        return int(string[2:], 16)
    elif string.startswith('0y'):
        return int(string[2:], 2)
    elif string.startswith('0o'):
        return int(string[2:], 8)
    return int(string, 10)

def evaluate_address(string):
    res = gdb.parse_and_eval(string)
    type = gdb.lookup_type(intcast(res))
    return res.cast(type)
end

## hexdump helpers
python
import sys,math,array,struct,string

class Memory(object):
    printable = set().union(string.printable).difference(string.whitespace).union(' ')

    @classmethod
    def read(cls, inferior, address, count):
        res = inferior.read_memory(address, count=1)
        return res.tobytes() if isinstance(res, memoryview) else res[:]
    @classmethod
    def write(cls, inferior, address, buffer):
        return inferior.write_memory(address, buffer)
    @classmethod
    def readable(cls, inferior, address, count=1):
        try: inferior.read_memory(address, count)
        except gdb.MemoryError: ok = False
        else: ok = True
        return ok
    @classmethod
    def writable(cls, inferior, address, count=1):
        raise NotImplementedError("unable to determine whether {:#x}{:+#x} is writable".format(address, count))
        try: inferior.read_memory(address, count)
        except gdb.MemoryError: ok = False
        else: ok = True
        return ok
    @classmethod
    def executable(cls, inferior, address, count=1):
        raise NotImplementedError("unable to determine whether {:#x}{:+#x} is executable".format(address, count))
        try: inferior.read_memory(address, count)
        except gdb.MemoryError: ok = False
        else: ok = True
        return ok

    ## dumping
    @classmethod
    def _gfilter(cls, iterable, itemsize):
        if itemsize < 8:
            for item in iterable:
                yield item
            return
        try:
            while True:
                iteml, itemh = next(iterable), next(iterable)
                yield (itemh << (8 * itemsize / 2)) | iteml
        except StopIteration:
            pass
        return

    @classmethod
    def _hex_generator(cls, iterable, itemsize):
        maxlength = math.ceil(math.log(2 ** (8 * itemsize)) / math.log(0x10))
        for item in iterable:
            yield '{:0{:d}x}'.format(item, math.trunc(maxlength))
        return

    @classmethod
    def _bin_generator(cls, iterable, itemsize):
        for item in iterable:
            yield '{:0{:d}b}'.format(item, itemsize)
        return

    @classmethod
    def _int_generator(cls, iterable, itemsize):
        maxlength = math.ceil(math.log(2 ** (8 * itemsize)) / math.log(10))
        for item in iterable:
            yield '{:{:d}d}'.format(item, math.trunc(maxlength))
        return

    @classmethod
    def _float_generator(cls, iterable, itemsize):
        maxlength = 32
        for item in iterable:
            yield '{:{:d}.5f}'.format(item, math.trunc(maxlength))
        return

    @classmethod
    def _dump(cls, data, kind=1):
        lookup = {1:'B', 2:'H', 4:'I', 8:'Q' if sys.version_info.major == 3 else 'L'}
        itemtype = lookup.get(kind, kind)
        return array.array(itemtype, data)

    ## specific dumping formats
    @classmethod
    def _hexdump(cls, data, kind):
        res = array.array(kind, data)
        if res.typecode == 'L' and res.itemsize == 4:
            res,sz = cls._gfilter(iter(res),8),8
        else:
            res,sz = res,res.itemsize
        return sz, cls._hex_generator(iter(res), sz)
    @classmethod
    def _itemdump(cls, data, kind):
        res = array.array(kind, data)
        if res.typecode == 'L' and res.itemsize == 4:
            res,sz = cls._gfilter(iter(res),8),8
        else:
            res,sz = res,res.itemsize
        if res.typecode in ('f','d'):
            return res.itemsize, cls._float_generator(iter(res), sz)
        return sz, cls._int_generator(iter(res), sz)
    @classmethod
    def _bindump(cls, data, kind):
        res = array.array(kind, data)
        if res.typecode == 'L' and res.itemsize == 4:
            res,sz = cls._gfilter(iter(res),8),8
        else:
            res,sz = res,res.itemsize
        return sz, cls._bin_generator(iter(res), sz*8)
    @classmethod
    def _chardump(cls, data, width):
        printable = set(sorted(cls.printable))
        printable = ''.join((ch if ch in printable else '.') for ch in map(chr,range(0,256)))
        res = array.array('b', data.translate(printable.encode('ascii')))
        imap, izip = (map,itertools.zip_longest) if sys.version_info.major == 3 else (itertools.imap,itertools.izip_longest)
        return width, imap(''.join, izip(*(imap(chr,res),)*width, fillvalue=''))

    @classmethod
    def _row(cls, width, columns):
        result = []
        for itemsize,column in columns:
            data = (c for i,c in zip(range(0, width, itemsize),column))
            result.append(' '.join(data))
        return result

    @classmethod
    def _dump(cls, target, address, count, width, kind, content):
        data = cls.read(target, address, struct.calcsize(kind) * count)
        countup = struct.calcsize(kind) * count
        offset = ('{:0{:d}x}'.format(a, math.trunc(math.floor(math.log(address + count) / math.log(0x10) + 1))) for a in range(address, address + math.trunc(countup), width))
        cols = ((width, offset), content(data, kind), cls._chardump(data, width))
        maxcols = (0,) * len(cols)
        while True:
            row = cls._row(width, cols)
            if len(row[0].strip()) == 0: break
            maxcols = tuple(max(item, len(r)) for item, r in zip(maxcols, row))
            yield tuple('{:{:d}s}'.format(col, colsize) for col, colsize in zip(row, maxcols))
        return

    @classmethod
    def hexdump(cls, target, address, count, kind, width=16):
        return '\n'.join(map(' | '.join, cls._dump(target, address, count, width, kind, cls._hexdump)))

    @classmethod
    def itemdump(cls, target, address, count, kind, width=16):
        return '\n'.join(map(' | '.join, cls._dump(target, address, count, width, kind, cls._itemdump)))

    @classmethod
    def binarydump(cls, target, address, count, kind, width=8):
        return '\n'.join(map(' | '.join, cls._dump(target, address, count, width, kind, cls._bindump)))

## commands
class __dump__(command):
    COMMAND = gdb.COMMAND_DATA
    method = kind = None
    def invoke(self, string, from_tty, count=None):
        args = gdb.string_to_argv(string)
        if any(n.startswith('L') for n in args):
            res = (i for i,n in enumerate(args) if n.startswith('L'))
            idx = next(res, None)
            expr,count_s = ' '.join(args[:idx]),'L{:d}'.format(count) if idx is None else args.pop(idx)
            if len(args[idx:]) > 0:
                raise gdb.error("SyntaxError : Unexpected arguments after row count : {!r}".format(' '.join(args[idx:])))
            count = parsenum(count_s[1:])
        else:
            itemsize = struct.calcsize(self.kind)
            expr, count = string, 6 * (16 / itemsize)

        inf, val = gdb.selected_inferior(), gdb.parse_and_eval(expr).cast( gdb.lookup_type("long") )
        res = self.method(inf, int(val.cast(gdb.lookup_type(intcast(val)))), count, self.kind)
        gdb.write(res + '\n')
        gdb.flush()

class __dumpitem__(__dump__): method = Memory.itemdump
class __dumphex__(__dump__): method = Memory.hexdump
class __dumpbinary__(__dump__): method = Memory.binarydump

# hexadecimal
class db(__dumphex__): kind = 'B'
class dw(__dumphex__): kind = 'H'
class dd(__dumphex__): kind = 'I'
class dq(__dumphex__): kind = 'Q' if sys.version_info.major == 3 else 'L'
db(),dw(),dd(),dq()

# integrals
class dnb(__dumpitem__): kind = 'B'
class dnw(__dumpitem__): kind = 'H'
class dnd(__dumpitem__): kind = 'I'
class dnq(__dumpitem__): kind = 'Q' if sys.version_info.major == 3 else 'L'
dnb(),dnw(),dnd(),dnq()

# floating-point
class df(__dumpitem__): kind = 'f'
class dD(__dumpitem__): kind = 'd'
df(),dD()

# binary
class dyb(__dumpbinary__): kind = 'B'
class dyw(__dumpbinary__): kind = 'H'
class dyd(__dumpbinary__): kind = 'I'
class dyq(__dumpbinary__): kind = 'Q' if sys.version_info.major == 3 else 'L'
dyb(),dyw(),dyd(),dyq()

## functions
class hexdump(function):
    def invoke(self, address, count, kind):
        inf, val = gdb.selected_inferior(), address
        return Memory.hexdump(inf, int(val.cast(gdb.lookup_type(intcast(val)))), int(count), chr(kind)) + '\n'
class itemdump(function):
    def invoke(self, address, count, kind):
        inf, val = gdb.selected_inferior(), address
        return Memory.itemdump(inf, int(val.cast(gdb.lookup_type(intcast(val)))), int(count), chr(kind)) + '\n'
class bindump(function):
    def invoke(self, address, count, kind):
        inf, val = gdb.selected_inferior(), address
        return Memory.bindump(inf, int(val.cast(gdb.lookup_type(intcast(val)))), int(count), chr(kind)) + '\n'
class access(function):
    _rwx_ = {4: Memory.readable, 2: Memory.writable, 1: Memory.executable}
    def invoke(self, address, count=1, permissions=4):
        inf, ea, length = gdb.selected_inferior(), int(address.cast(gdb.lookup_type(intcast(address)))), int(count)
        items = [callable for flag, callable in self._rwx_.items() if permissions & flag]
        return all(callable(inf, ea, length) for callable in items)
hexdump(),itemdump(),bindump(),access()

end

### 32-bit / 64-bit functions
define show_regs32
    emit "\n-=[registers]=-\n"
    emit $sprintf("[eax: 0x%08x] [ebx: 0x%08x] [ecx: 0x%08x] [edx: 0x%08x]\n", $eax, $ebx, $ecx, $edx)
    emit $sprintf("[esi: 0x%08x] [edi: 0x%08x] [esp: 0x%08x] [ebp: 0x%08x]\n", $esi, $edi, (unsigned int)$esp, (unsigned int)$ebp)
    show_flags
end

define show_regs64
    emit "\n-=[registers]=-\n"
    emit $sprintf("[rax: 0x%016x] [rbx: 0x%016x] [rcx: 0x%016x]\n", $rax, $rbx, $rcx)
    emit $sprintf("[rdx: 0x%016x] [rsi: 0x%016x] [rdi: 0x%016x]\n", $rdx, $rsi, $rdi)
    emit $sprintf("[rsp: 0x%016x] [rbp: 0x%016x] [ pc: 0x%016x]\n", (unsigned long long)$rsp, (unsigned long long)$rbp, (unsigned long long)$pc)
    emit $sprintf("[ r8: 0x%016x] [ r9: 0x%016x] [r10: 0x%016x]\n", $r8, $r9, $r10)
    emit $sprintf("[r11: 0x%016x] [r12: 0x%016x] [r13: 0x%016x]\n", $r11, $r12, $r13)
    emit $sprintf("[r14: 0x%016x] [r15: 0x%016x] [efl: 0x%08x]\n", $r14, $r15, (unsigned int)$ps)
    show_flags
end

define show_stack32
    emit "\n-=[stack]=-\n"
    if $access($esp, sizeof(long))
        emit $hexdump($esp, 4 * sizeof(long), 'I')
        #x/6wx $esp
    else
        emit $sprintf("... address %p not available ...\n", $esp)
    end
end

define show_stack64
    emit "\n-=[stack]=-\n"
    if $access($esp, sizeof(long))
        emit $hexdump($rsp, 1 * sizeof(long), 'L')
        #x/6gx $rsp
    else
        emit $sprintf("... address %p not available ...\n", $rsp)
    end
end

define show_data32
    set variable $_data_rows = 8

    if $access($arg0, sizeof(int))
        if $argc > 1
            emit $hexdump($arg0, $arg1 * 0x10 / sizeof(int), 'I')
        else
            emit $hexdump($arg0, $_data_rows * 0x10 / sizeof(int), 'I')
        end
    else
        emit $sprintf("... address %p not available ...\n", $arg0)
    end
end

define show_data64
    set variable $_data_rows = 8

    if $access($arg0, sizeof(int))
        if $argc > 1
            emit $hexdump($arg0, $arg1 * 0x10 / sizeof(long), 'L')
        else
            emit $hexdump($arg0, $_data_rows * 0x10 / sizeof(long), 'L')
        end
    else
        emit $sprintf("... address %p not available ...\n", $arg0)
    end
end

define show_code32
    set variable $_max_instruction = 0x10 - 1
    # FIXME: better way to figure this out per-architecture?

    emit "\n-=[disassembly]=-\n"
    if $access($pc, 1)
        if $access($pc + -3 * $_max_instruction, 1)
            x/-3i $pc
        else
            emit $sprintf("...")
        end

        if $access($pc + +4 * $_max_instruction, 1)
            x/4i $pc
        else
            x/i $pc
        end
    else
        emit $sprintf("... address %p not available ...\n", $pc)
    end
end

define show_code64
    set variable $_max_instruction = 0x10 - 1
    # FIXME: better way to figure this out per-architecture?

    emit "\n-=[disassembly]=-\n"
    if $access($pc, 1)
        if $access($pc + -3 * $_max_instruction, 1)
            x/-3i $pc
        else
            emit $sprintf("...")
        end
        if $access($pc + +4 * $_max_instruction, 1)
            x/4i $pc
        else
            x/i $pc
        end
    else
        emit $sprintf("... address %p not available ...\n", $pc)
    end
end

#      |11|10|F|E|D|C|B|A|9|8|7|6|5|4|3|2|1|0|
#        |  | | | | | | | | | | | | | | | | +---  CF Carry Flag
#        |  | | | | | | | | | | | | | | | +---  1
#        |  | | | | | | | | | | | | | | +---  PF Parity Flag
#        |  | | | | | | | | | | | | | +---  0
#        |  | | | | | | | | | | | | +---  AF Auxiliary Flag
#        |  | | | | | | | | | | | +---  0
#        |  | | | | | | | | | | +---  ZF Zero Flag
#        |  | | | | | | | | | +---  SF Sign Flag
#        |  | | | | | | | | +---  TF Trap Flag  (Single Step)
#        |  | | | | | | | +---  IF Interrupt Flag
#        |  | | | | | | +---  DF Direction Flag
#        |  | | | | | +---  OF Overflow flag
#        |  | | | +-+---  IOPL I/O Privilege Level  (286+ only)
#        |  | | +-----  NT Nested Task Flag  (286+ only)
#        |  | +-----  0
#        |  +-----  RF Resume Flag (386+ only)
#        +------  VM  Virtual Mode Flag (386+ only)

define show_flags
    set variable $_cf   = ($ps& 0x000001)?  "+CF" : "-CF"
    set variable $_r1   = ($ps& 0x000002)?  " R1" : ""
    set variable $_pf   = ($ps& 0x000004)?  "+PF" : "-PF"
    set variable $_r2   = ($ps& 0x000008)?  " R2" : ""
    set variable $_af   = ($ps& 0x000010)?  "+AF" : "-AF"
    set variable $_r3   = ($ps& 0x000020)?  " R3" : ""
    set variable $_zf   = ($ps& 0x000040)?  "+ZF" : "-ZF"
    set variable $_sf   = ($ps& 0x000080)?  "+SF" : "-SF"
    set variable $_tf   = ($ps& 0x000100)?  " TF" : ""
    set variable $_if   = ($ps& 0x000200)?  "+IF" : "-IF"
    set variable $_df   = ($ps& 0x000400)?  "+DF" : "-DF"
    set variable $_of   = ($ps& 0x000800)?  "+OF" : "-OF"
    set variable $_iopl = ($ps& 0x003000)? $sprintf(" IOPL%d",($ps&0x3000)>>0x1000) : ""
    set variable $_nt   = ($ps& 0x004000)?  " NT" : ""
    set variable $_r4   = ($ps& 0x008000)?  " R4" : ""

    ## eflags
    set variable $_rf   = ($ps& 0x010000)?  " RF" : ""
    set variable $_vm   = ($ps& 0x020000)?  " VM" : ""
    set variable $_ac   = ($ps& 0x040000)?  " AC" : ""
    set variable $_vif  = ($ps& 0x080000)?  " VIF": ""
    set variable $_vip  = ($ps& 0x100000)?  " VIP": ""
    set variable $_id   = ($ps& 0x200000)?  " ID" : ""
    set variable $_ereserved = (($ps >> 16+6) & 0x3ff)? $sprintf(" R<eflags>=0x%03x", ($ps >> 16+6) & 0x3ff) : ""

    ## rflags
    set variable $_rreserved = (($ps >> 32) & 0xffffffff)? $sprintf(" R<rflags>=0x%08x", ($ps >> 32) & 0xffffffff) : ""
    emit $sprintf("[flags: %s %s %s %s %s %s %s %s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s]\n", $_zf, $_sf, $_of, $_cf, $_df, $_pf, $_af, $_if, $_tf, $_nt, $_rf, $_vm, $_ac, $_vif, $_vip, $_id, $_iopl, $_r1, $_r2, $_r3, $_r4, $_ereserved, $_rreserved)
end

define here32
    show_regs32
    show_stack32
    show_code32
end

define here64
    show_regs64
    show_stack64
    show_code64
end

### stepping
define n
    nexti
    here
end

define s
    stepi
    here
end

### conditional definitions based on the arch
define show_regs
    if sizeof(void*) == 4
        show_regs32
    end
    if sizeof(void*) == 8
        show_regs64
    end
end

define show_stack
    if sizeof(void*) == 4
        show_stack32
    end
    if sizeof(void*) == 8
        show_stack64
    end
end

define show_code
    if sizeof(void*) == 4
        show_code32
    end
    if sizeof(void*) == 8
        show_code64
    end
end

define here
    if sizeof(void*) == 4
        here32
    end
    if sizeof(void*) == 8
        here64
    end
end

# needs to be defined in order to replace the help command
define h
    here
end

### shortcuts
define maps
    info proc mappings
end

define cwd
    info proc cwd
end

define segments
    info files
end

define tasks
    #maintenance info program-spaces
    if $argc > 0
        info inferiors $arg0
    else
        info inferiors
    end
end

define threads
    if $argc > 0
        info threads $arg0
    else
        info threads
    end
end

define symbols
    info variables $arg0
end

define lvars
    info locals
end

define args
    info args
end

define vars
    show convenience
end

define la
    info address $arg0
end

define ll
    info line $arg0
end

define ln
    info symbol $arg0
end

define lm
    info proc mappings
end

define bl
    info breakpoints
end

# unassemble
define u
    if $argc > 1
        set variable $_unassemble_rows = $arg1
    else
        set variable $_unassemble_rows = 0d25
    end
    if $argc > 0
        set variable $_unassemble_position = $arg0
    else
        set variable $_unassemble_position = $pc
    end

    # use x/ to disassemble the parameters
    eval "x/%di %s\n",$_unassemble_rows,"$_unassemble_position"
end

# disassemble
define dis
    if $argc > 0
        disassemble $arg0
    else
        disassemble
    end
end

define dc
    if $argc > 1
        if sizeof(void*) == 4
            show_data32 $arg0 $arg1
        end
        if sizeof(void*) == 8
            show_data64 $arg0 $arg1
        end
    else
        if sizeof(void*) == 4
            show_data32 $arg0
        end
        if sizeof(void*) == 8
            show_data64 $arg0
        end
    end
end

### breakpoints with wildcards
python
class bc(command):
    def invoke(self, s, from_tty):
        if s == '*':
            gdb.execute("delete breakpoints")
            return
        gdb.execute("delete breakpoints " + s)
class bd(command):
    def invoke(self, s, from_tty):
        if s == '*':
            gdb.execute("disable breakpoints")
            return
        gdb.execute("disable breakpoints " + s)
class be(command):
    def invoke(self, s, from_tty):
        if s == '*':
            gdb.execute("enable breakpoints")
            return
        gdb.execute("enable breakpoints " + s)
class ba(command):
    def invoke(self, s, from_tty):
        args = gdb.string_to_argv(s)
        addr = args.pop(0)
        if not addr.startswith('*'):
            addr = "*({})".format(addr)
        if len(args) > 0 and args[0].startswith('~'):
            t=args.pop(0)[1:]
            thread = '' if t == '*' else (' thread %s'% t)
        else:
            th = gdb.selected_thread()
            thread = '' if th is None else ' thread %d'% th.num
        rest = (' if '+' '.join(args)) if len(args) > 0 else ''
        gdb.execute("hbreak " + addr + thread + rest)
class bp(command):
    def invoke(self, s, from_tty):
        args = gdb.string_to_argv(s)
        addr = args.pop(0)
        if not addr.startswith('*'):
            addr = "*({})".format(addr)
        if len(args) > 0 and args[0].startswith('~'):
            t=args.pop(0)[1:]
            thread = '' if t == '*' else (' thread %s'% t)
        else:
            th = gdb.selected_thread()
            thread = '' if th is None else ' thread %d'% th.num
        rest = (' if '+' '.join(args)) if len(args) > 0 else ''
        gdb.execute("break " + addr + thread + rest)
class go(command):
    def invoke(self, s, from_tty):
        args = gdb.string_to_argv(s)
        addr = args.pop(0)
        if not addr.startswith('*'):
            addr = "*({})".format(addr)
        if len(args) > 0 and args[0].startswith('~'):
            t=args.pop(0)[1:]
            thread = '' if t == '*' else (' thread %s'% t)
        else:
            th = gdb.selected_thread()
            thread = '' if th is None else ' thread %d'% th.num
        rest = (' if '+' '.join(args)) if len(args) > 0 else ''
        gdb.execute("tbreak " + addr + thread + rest)
        gdb.execute("run" if gdb.selected_thread() is None else "continue")
        gdb.execute("here")

bc(),bd(),be(),ba(),bp(),go()
end

### defaults

## aliases
alias -- g = go
alias -- h32 = here32
alias -- h64 = here64

## catchpoints
catch exec
catch fork
disable breakpoint $bpnum
catch vfork
disable breakpoint $bpnum
tbreak main

## options
set stop-on-solib-events 0
set follow-fork-mode child
set detach-on-fork off
set input-radix 0x10
set output-radix 0x10
#set width unlimited
#set height unlimited
set max-value-size unlimited

## registers ($ps)
set variable $cf = 1 << 0
#set variable $r1 = 1 << 1
set variable $pf = 1 << 2
#set variable $r2 = 1 << 3
set variable $af = 1 << 4
#set variable $r3 = 1 << 5
set variable $zf = 1 << 6
set variable $sf = 1 << 7
set variable $tf = 1 << 8
set variable $if = 1 << 9
set variable $df = 1 << 10
set variable $of = 1 << 11
#set variable $iopl = 3 << 12
#set variable $nt = 1 << 14
#set variable $r4 = 1 << 15
#set variable $rf = 1 << 16
#set variable $vm = 1 << 17

#source /usr/local/lib/python2.7/dist-packages/exploitable-1.32-py2.7.egg/exploitable/exploitable.py
