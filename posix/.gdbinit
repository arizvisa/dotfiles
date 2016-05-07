## python helpers
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
        formatter,args = string.Formatter(),iter(args)
        fmt = re.sub('%(\d+\.?\d+f|0?\d*[\w^\d]|\d*[\w^\d]|-0?\d*[\w^\d]|-\d*[\w^\d])', lambda m:'{:'+m.groups(1)[0]+'}', next(args).string())
        res = ''
        for text,_,typestr,_ in formatter.parse(fmt):
            res += text
            if typestr is None: continue
            realtype,value = typestr[-1],next(args)
            size = value.type.sizeof
            if realtype in 's':
                res += '{:{typestr:s}}'.format(value.string(), typestr=typestr)
            elif realtype in 'dx':
                absint = (2**(8*size)+int(value)) if int(value) < 0 else int(value)
                if typestr.startswith('-'):
                    res += '{:{typestr:s}}'.format(int(value), typestr=typestr)
                else:
                    res += '{:{typestr:s}}'.format(absint, typestr=typestr)
            elif realtype == 'p':
                absint = (2**(8*size)+int(value)) if int(value) < 0 else int(value)
                if typestr.startswith('-'):
                    res += ('-' if int(value) < 0 else '') + '0x{:0{size:d}x}'.format(abs(int(value)), size=size*2)
                else:
                    res += '0x{:0{size:d}x}'.format(absint, size=size*2)
            elif realtype == 'f':
                res += '{:{typestr:s}}'.format(float(value), typestr=typestr)
            else:
                raise gdb.error("Unknown format specifier: {:s}".format(typestr))
            continue
        return res
execute(),emit(),typeof(),sprintf()
end

## 32-bit / 64-bit functions
define show_regs32
    emit "\n-=[registers]=-\n"
    emit $sprintf("[eax: 0x%08x] [ebx: 0x%08x] [ecx: 0x%08x] [edx: 0x%08x]\n", $eax, $ebx, $ecx, $edx)
    emit $sprintf("[esi: 0x%08x] [edi: 0x%08x] [esp: 0x%08x] [ebp: 0x%08x]\n", $esi, $edi, $esp, $ebp)
    show_flags
end

define show_regs64
    emit "\n-=[registers]=-\n"
    emit $sprintf("[rax: 0x%016lx] [rbx: 0x%016lx] [rcx: 0x%016lx]\n", $rax, $rbx, $rcx)
    emit $sprintf("[rdx: 0x%016lx] [rsi: 0x%016lx] [rdi: 0x%016lx]\n", $rdx, $rsi, $rdi)
    emit $sprintf("[rsp: 0x%016lx] [rbp: 0x%016lx] [ pc: 0x%016lx]\n", $rsp, $rbp, $pc)
    emit $sprintf("[ r8: 0x%016lx] [ r9: 0x%016lx] [r10: 0x%016lx]\n", $r8, $r9, $r10)
    emit $sprintf("[r11: 0x%016lx] [r12: 0x%016lx] [r13: 0x%016lx]\n", $r11, $r12, $r13)
    emit $sprintf("[r14: 0x%016lx] [r15: 0x%016lx] [efl: 0x%08x]\n", $r14, $r15, $eflags)
    show_flags
end

define show_stack32
    emit "\n-=[stack]=-\n"
    x/8wx $esp
end

define show_stack64
    emit "\n-=[stack]=-\n"
    x/8gx $rsp
end

define show_code32
    emit "\n-=[disassembly]=-\n"
    x/10i $pc
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
#    set variable $_ipol = ($eflags&512)? "IOPL"
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

## stepping
#define n
#    ni
#    h
#end
#
#define s
#    si
#    h
#end

## conditional definitions based on the arch
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

## shortcuts
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

## breakpoints with wildcards
python
class bc(command):
    def invoke(self, string, from_tty):
        if string == '*':
            gdb.execute("delete breakpoints")
            return
        gdb.execute("delete breakpoints " + string)
class bd(command):
    def invoke(self, string, from_tty):
        if string == '*':
            gdb.execute("disable breakpoints")
            return
        gdb.execute("disable breakpoints " + string)
class be(command):
    def invoke(self, string, from_tty):
        if string == '*':
            gdb.execute("enable breakpoints")
            return
        gdb.execute("enable breakpoints " + string)
class ba(command):
    def invoke(self, string, from_tty):
        args = gdb.string_to_argv(string)
        addr = args.pop(0)
        if addr.startswith('0') or addr.isdigit():
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
    def invoke(self, string, from_tty):
        args = gdb.string_to_argv(string)
        addr = args.pop(0)
        if addr.startswith('0') or addr.isdigit():
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

## catchpoints
catch exec
catch fork
catch vfork
catch signal
tbreak main

## options
set stop-on-solib-events 0
set follow-fork-mode child
set input-radix 0x10
set output-radix 0x10
set width unlimited
set height unlimited

#source /usr/local/lib/python2.7/dist-packages/exploitable-1.32-py2.7.egg/exploitable/exploitable.py
