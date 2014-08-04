#define n
#    ni
#    h
#end
#
#define s
#    si
#    h
#end

define show_regs
    printf "\n-=[registers]=-\n"
    printf "[eax: 0x%08x] [ebx: 0x%08x] [ecx: 0x%08x] [edx: 0x%08x]\n", $eax, $ebx, $ecx, $edx
    printf "[esi: 0x%08x] [edi: 0x%08x] [esp: 0x%08x] [ebp: 0x%08x]\n", $esi, $edi, $esp, $ebp
end

define show_stack
    printf "\n-=[stack]=-\n"
    x/8wx $esp
end

define show_code
    printf "\n-=[disassembly]=-\n"
    x/10i $pc
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

define h
    show_regs
    show_flags
    show_stack
    show_code
end

catch exec
set stop-on-solib-events 1
