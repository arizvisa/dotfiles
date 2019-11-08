python import operator,itertools,functools

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
                    res += ('-' if val < 0 else '') + '0x{:0{size:d}x}'.format(abs(val), size=size*2)
                else:
                    res += '0x{:0{size:d}x}'.format(absint, size=size*2)
            elif realtype == 'f':
                res += '{:{typestr:s}}'.format(float(val), typestr=typestr)
            else:
                raise gdb.error("Unknown format specifier: {:s}".format(typestr))
            continue
        return res
execute(),emit(),typeof(),sprintf()

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
end

## hexdump helpers
python
import sys,math,array,string

class Memory(object):
    printable = set().union(string.printable).difference(string.whitespace).union(' ')

    @classmethod
    def read(cls, inferior, address, count):
        res = inferior.read_memory(address, count)
        return res.tobytes() if isinstance(res, memoryview) else res[:]
    @classmethod
    def write(cls, inferior, address, buffer):
        return inferior.write_memory(address, count)

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
        maxlength = math.ceil(math.log(2**(itemsize*8)) / math.log(0x10))
        for item in iterable:
            yield '{:0{:d}x}'.format(item, int(maxlength))
        return

    @classmethod
    def _bin_generator(cls, iterable, itemsize):
        for item in iterable:
            yield '{:0{:d}b}'.format(item, itemsize)
        return

    @classmethod
    def _int_generator(cls, iterable, itemsize):
        maxlength = math.ceil(math.log(2**(itemsize*8)) / math.log(10))
        for item in iterable:
            yield '{:{:d}d}'.format(item, int(maxlength))
        return

    @classmethod
    def _float_generator(cls, iterable, itemsize):
        maxlength = 32
        for item in iterable:
            yield '{:{:d}.5f}'.format(item, int(maxlength))
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
        data = cls.read(target, address, count)
        countup = int((count // width) * width)
        offset = ('{:0{:d}x}'.format(a, int(math.floor(math.log(address+count)/math.log(0x10) + 1))) for a in range(address, address+countup, width))
        cols = ((width, offset), content(data, kind), cls._chardump(data, width))
        maxcols = (0,) * len(cols)
        while True:
            row = cls._row(width, cols)
            if len(row[0].strip()) == 0: break
            maxcols = tuple(max((n,len(r))) for n,r in zip(maxcols,row))
            yield tuple('{:{:d}s}'.format(col, colsize) for col,colsize in zip(row,maxcols))
        return

    @classmethod
    def hexdump(cls, target, address, count, kind, width=16):
        return '\n'.join(map(' | '.join, cls._dump(target, address, count*width, width, kind, cls._hexdump)))

    @classmethod
    def itemdump(cls, target, address, count, kind, width=16):
        return '\n'.join(map(' | '.join, cls._dump(target, address, count*width, width, kind, cls._itemdump)))

    @classmethod
    def binarydump(cls, target, address, count, kind, width=16):
        return '\n'.join(map(' | '.join, cls._dump(target, address, count*width, width, kind, cls._bindump)))

## commands
class __dump__(command):
    COMMAND = gdb.COMMAND_DATA
    method = kind = None
    def invoke(self, string, from_tty, count=6):
        args = gdb.string_to_argv(string)
        if any(n.startswith('L') for n in args):
            res = (i for i,n in enumerate(args) if n.startswith('L'))
            idx = next(res, None)
            expr,count_s = ' '.join(args[:idx]),'L{:d}'.format(count) if idx is None else args.pop(idx)
            if len(args[idx:]) > 0:
                raise gdb.error("SyntaxError : Unexpected arguments after row count : {!r}".format(' '.join(args[idx:])))
            count = parsenum(count_s[1:])
        else:
            expr = string

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
hexdump(),itemdump(),bindump()

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
    emit $sprintf("[r14: 0x%016x] [r15: 0x%016x] [efl: 0x%08x]\n", $r14, $r15, (unsigned int)$eflags)
    show_flags
end

define show_stack32
    emit "\n-=[stack]=-\n"
    emit $hexdump($esp, 4, 'I')
    #x/6wx $esp
end

define show_stack64
    emit "\n-=[stack]=-\n"
    #x/6gx $rsp
    emit $hexdump($rsp, 4, 'L')
end

define show_code32
    emit "\n-=[disassembly]=-\n"
    x/6i $pc
end

define show_code64
    emit "\n-=[disassembly]=-\n"
    x/6i $pc
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
    set variable $_cf = ($eflags&  1)? "CF" : "NC"
    set variable $_pf = ($eflags&  2)? "PF" : "NP"
    set variable $_af = ($eflags&  4)? "AF" : "NA"
    set variable $_zf = ($eflags&  8)? "ZF" : "NZ"
    set variable $_sf = ($eflags& 16)? "SF" : "NS"
#    set variable $_tf = ($eflags& 32)? "TF" : "NT"
    set variable $_if = ($eflags& 64)? "IF" : "NI"
    set variable $_df = ($eflags&128)? "DF" : "ND"
    set variable $_of = ($eflags&256)? "OF" : "NO"
#    set variable $_iopl = ($eflags&512)? "IOPL"
#    set variable $_nt = ($eflags&1024)? "NT"
#    set variable $_nothing = ($eflags&2048)
#    set variable $_rf = ($eflags&4096)? "RF"
#    set variable $_vm = ($eflags&8192)? "VM"
    emit $sprintf("[eflags: %s %s %s %s %s %s]\n", $_zf, $_sf, $_of, $_cf, $_df, $_if)
end

define h32
    show_regs32
    show_stack32
    show_code32
end

define h64
    show_regs64
    show_stack64
    show_code64
end

### stepping
define n
    ni
    h
end

define s
    si
    h
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

define h
    if sizeof(void*) == 4
        h32
    end
    if sizeof(void*) == 8
        h64
    end
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
    info sharedlibrary
end

define bl
    info breakpoints
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
        if any(map(addr.startswith, string.digits)):
            addr = '*'+addr
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
        if any(map(addr.startswith, string.digits)):
            addr = '*'+addr
        if len(args) > 0 and args[0].startswith('~'):
            t=args.pop(0)[1:]
            thread = '' if t == '*' else (' thread %s'% t)
        else:
            th = gdb.selected_thread()
            thread = '' if th is None else ' thread %d'% th.num
        rest = (' if '+' '.join(args)) if len(args) > 0 else ''
        gdb.execute("break " + addr + thread + rest)
bc(),bd(),be(),ba(),bp()
end

### defaults

## catchpoints
catch exec
catch fork
catch vfork
tbreak main

## options
set stop-on-solib-events 0
set follow-fork-mode child
set input-radix 0x10
set output-radix 0x10
#set width unlimited
#set height unlimited

## registers ($ps)
set variable $cf = 1 << 0
set variable $pf = 1 << 1
set variable $af = 1 << 2
set variable $zf = 1 << 3
set variable $sf = 1 << 4
#set variable $tf = 1 << 5
set variable $if = 1 << 6
set variable $df = 1 << 7
set variable $of = 1 << 8
#set variable $iopl = 1 << 9
#set variable $nt = 1 << 10
#set variable $nothing = 1 << 11
#set variable $rf = 1 << 12
#set variable $vm = 1 << 13

#source /usr/local/lib/python2.7/dist-packages/exploitable-1.32-py2.7.egg/exploitable/exploitable.py
