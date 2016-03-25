# .gdbinit options
set variable $_tty_WIDTH = 80
set variable $_tty_HEIGHT = 25-1

## 32-bit / 64-bit functions
define show_regs32
    printf "\n-=[registers]=-\n"
    printf "[eax: 0x%08x] [ebx: 0x%08x] [ecx: 0x%08x] [edx: 0x%08x]\n", $eax, $ebx, $ecx, $edx
    printf "[esi: 0x%08x] [edi: 0x%08x] [esp: 0x%08x] [ebp: 0x%08x]\n", $esi, $edi, $esp, $ebp
    show_flags
end

define show_regs64
    printf "\n-=[registers]=-\n"
    printf "[rax: 0x%016lx] [rbx: 0x%016lx] [rcx: 0x%016lx]\n", $rax, $rbx, $rcx
    printf "[rdx: 0x%016lx] [rsi: 0x%016lx] [rdi: 0x%016lx]\n", $rdx, $rsi, $rdi
    printf "[rsp: 0x%016lx] [rbp: 0x%016lx] [ pc: 0x%016lx]\n", $rsp, $rbp, $pc
    printf "[ r8: 0x%016lx] [ r9: 0x%016lx] [r10: 0x%016lx]\n", $r8, $r9, $r10
    printf "[r11: 0x%016lx] [r12: 0x%016lx] [r13: 0x%016lx]\n", $r11, $r12, $r13
    printf "[r14: 0x%016lx] [r15: 0x%016lx] [efl: 0x%08x]\n", $r14, $r15, $eflags
    show_flags
end

define show_stack32
    printf "\n-=[stack]=-\n"
    x/8wx $esp
end

define show_stack64
    printf "\n-=[stack]=-\n"
    x/8gx $rsp
end

define show_code32
    printf "\n-=[disassembly]=-\n"
    x/10i $pc
end

define show_code64
    printf "\n-=[disassembly]=-\n"
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
    printf "[eflags: %s %s %s %s %s %s]\n", $_zf, $_sf, $_of, $_cf, $_df, $_if
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
define n
    ni
    h
end

define s
    si
    h
end

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
    info inferiors
end

define threads
    info threads $arg0
end

define symbols
    info variables $arg0
end

define la
    info address $arg0
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

define bc
    delete breakpoints $arg0
end

define bd
    disable breakpoints $arg0
end

define be
    enable breakpoints $arg0
end

define ba
    hbreak *($arg0)
end

define bp
    break *($arg0)
end

## catchpoints
catch exec
catch fork
catch vfork
catch signal
tbreak main

## options
set stop-on-solib-events 1
set follow-fork-mode child
set input-radix 0x10
set output-radix 0x10

set width $_tty_WIDTH
set height $_tty_HEIGHT
