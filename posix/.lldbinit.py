'''
@lldb_command('example')
def example(debugger, command, result, globals):
    print(command)
    print(result)

@lldb_command('example')
class example(object):
    def __init__(self, debugger, globals):
        pass
    def get_flags(self):
        lldb.eCommandProcessMustBeLaunched
        lldb.eCommandProcessMustBePaused
        lldb.eCommandRequiresFrame
        lldb.eCommandRequiresProcess
        lldb.eCommandRequiresRegContext
        lldb.eCommandRequiresTarget
        lldb.eCommandRequiresThread
        lldb.eCommandTryTargetAPILock
        pass
    def get_long_help(self):
    def get_short_help(self):
    def __call__(self, debugger, command, executioncontext, result):
        pass
'''
if __name__ == '__main__':
    raise RuntimeError("Not intended to be run as a stand-alone application")

import sys,os,platform,traceback,logging
import types,itertools,operator,functools
import fnmatch,six,array,math,string
import commands,argparse,shlex
import lldb

### default options
class options(object):
    # which disassembly-flavor to use
    syntax = 'att'

    # whether to display with a color-scheme
    color = False

    # which characters are printable within the hextdump
    printable = set().union(string.printable).difference(string.whitespace).union(' ')

### lldb command utilities
class lldb_command(object):
    cls_cache = []
    func_cache = []
    synchronicity = {}

    def __new__(cls, name, sync=None):
        lookup = [(types.TypeType, cls.cls_cache.append), ((types.FunctionType,types.MethodType), cls.func_cache.append)]
        def add_to_cache(definition):
            for t,cache in lookup:
                if isinstance(definition,t): cache((name, definition))
            return definition
        if sync: cls.synchronicity[name] = sync
        return add_to_cache

    @classmethod
    def stupid(cls, func, restype):
        def wrapper(*args, **kwds):
            res = restype()
            args += (res,)
            _ = func(*args, **kwds)
            return res
        return functools.update_wrapper(wrapper, func)

    @classmethod
    def load(cls, interpreter):
        func = itertools.starmap('command script add -f {:s}.{:s} {:s}'.format, ((func.__module__,func.__name__,command) for command,func in cls.func_cache))
        klass = itertools.starmap('command script add -c {:s}.{:s} {:s}'.format, ((klass.__module__,klass.__name__,command) for command,klass in cls.cls_cache if command not in cls.synchronicity))
        klass_sync = itertools.starmap('command script add -c {:s}.{:s} -s {:s} {:s}'.format, ((klass.__module__,klass.__name__,cls.synchronicity[command],command) for command,klass in cls.cls_cache if command in cls.synchronicity))
        handleCommand = cls.stupid(interpreter.HandleCommand, lldb.SBCommandReturnObject)
        return map(handleCommand, itertools.chain(func, klass,klass_sync))

def __lldb_init_module(debugger, globals):
    interp = debugger.GetCommandInterpreter()
    if any(not n.Succeeded() for n in lldb_command.load(interp)):
        logging.warn('Error trying to define python commands')
    return

# lldb-stupidity helpers
class CaptureOutput(object):
    def __init__(self, result):
        self.result = result
        self.state = []
        self.error = []

    @classmethod
    def splitoutput(cls, append):
        leftover = ''
        while True:
            try:
                output = leftover + (yield)
            except GeneratorExit:
                append(leftover)
                break

            split = output.split('\n')
            res = iter(split)
            if len(split) > 1: map(append,itertools.islice(res, len(split)-1))
            leftover = next(res)
        return

    @classmethod
    def fileobj(cls, append):
        splitter = cls.splitoutput(append)
        splitter.next()
        fileobj = type(cls.__name__, (object,), {'write':splitter.send})
        return fileobj()

    def __enter__(self):
        self.state.append(sys.stdout), self.error.append(sys.stderr)
        sys.stdout = out = self.fileobj(self.result.AppendMessage)
        sys.stderr = err = self.fileobj(self.result.AppendWarning)
        return out,err

    def __exit__(self, exc_type, exc_val, exc_tb):
        sys.stdout = self.state.pop(-1)
        sys.stderr = self.error.pop(-1)

class CommandWrapper(object):
    CONTINUE = {False : lldb.eReturnStatusSuccessContinuingNoResult, True : lldb.eReturnStatusSuccessContinuingResult}
    FINISH   = {False : lldb.eReturnStatusSuccessFinishNoResult,     True : lldb.eReturnStatusSuccessFinishResult}

    def __init__(self, fn, continuing=False, result=False):
        state = self.CONTINUE if continuing else self.FINISH
        self.callable, self.success = fn, state[result]

    def __call__(self, context, command, result):
        result.Clear()
        try:
            with CaptureOutput(result) as (f,e):
                failed = self.callable(context, command)
        except:
            exc = traceback.format_exception(*sys.exc_info())
            map(result.AppendWarning, exc)
            failed = True
        result.SetStatus(lldb.eReturnStatusFailed if failed else self.success)

Flags = type('Flags', (object,), { n[len('eCommand'):] : getattr(lldb, n) for n in dir(lldb) if n.startswith('eCommand') })

class Command(object):
    # what context to pass to the command
    context = lldb.SBDebugger

    # whether the command continues or finishes
    continuing = False

    # whether the command has a result or not
    hasresult = False

    # the argument parser object
    help = None

    # default arguments to pass if none is specified
    default = None

    # lldb.eCommand* flags that describe requirements of the command
    flags = 0

    @classmethod
    def convert(cls, ctx, (debugger, context)):
        # for some reason if these aren't touched, they don't work.
        lldb.target,lldb.debugger,lldb.process,lldb.thread,lldb.frame

        # return the correct object given the requested context
        if ctx == None:
            return context.GetTarget()
        elif ctx == lldb.SBExecutionContext:
            return context
        elif ctx == lldb.SBDebugger:
            return debugger
        elif ctx == lldb.SBTarget:
            return context.GetTarget()
        elif ctx == lldb.SBCommandInterpreter:
            return debugger.GetCommandInterpreter()
        elif ctx == lldb.SBProcess:
            return context.GetProcess()
        elif ctx == lldb.SBThread:
            return context.GetThread()
        elif ctx == lldb.SBFrame:
            return context.GetFrame()
        elif ctx == lldb.SBBlock:
            frame = context.GetFrame()
            #return frame.GetFrameBlock()
            return frame.GetBlock()
        elif ctx == lldb.SBValueList:
            frame = context.GetFrame()
            return frame.GetRegisters()
        elif ctx == lldb.SBFunction:
            frame = context.GetFrame()
            return frame.GetFunction()
        elif ctx == lldb.SBModule:
            frame = context.GetFrame()
            return frame.GetModule()
        elif ctx == lldb.SBFileSpec:
            frame = context.GetFrame()
            module = frame.GetModule()
            return frame.GetFileSpec()
        raise NotImplementedError("{:s}.{:s}.convert : unable to convert requested context to it's instance : {!r}".format(__name__, cls.__name__, ctx))

    @classmethod
    def verify(cls):
        if not isinstance(cls.continuing, bool):
            raise AssertionError("{:s}.{:s}.continuing is not of type bool : {!r}".format(__name__, cls.__name__, cls.continuing.__class__))
        if not isinstance(cls.hasresult, bool):
            raise AssertionError("{:s}.{:s}.hasresult is not of type bool : {!r}".format(__name__, cls.__name__, cls.hasresult.__class__))
        if cls.help and not isinstance(cls.help, argparse.ArgumentParser):
            raise AssertionError("{:s}.{:s}.help is not of type {:s} : {!r}".format(__name__, cls.__name__, argparse.ArgumentParser.__name__, cls.help.__class__))
        if not isinstance(cls.flags, six.integer_types):
            raise AssertionError("{:s}.{:s}.flags is not an integral : {!r}".format(__name__, cls.__name__, cls.flags))
        if cls.command is Command.command:
            raise AssertionError("{:s}.{:s}.command has not been overloaded : {!r}".format(__name__, cls.__name__, cls.command))
        if isinstance(cls.command, types.MethodType):
            raise AssertionError("{:s}.{:s}.command is not a staticmethod : {!r}".format(__name__, cls.__name__, cls.command.__class__))
        return

    def __init__(self, debugger, namespace):
        # not sure what the point of these are..
        self.debugger, self.namespace = debugger, namespace

        # verify the class is defined properly, and create our wrapper
        self.verify()

        # decorate our method
        self.callable = CommandWrapper(self.command, self.continuing, self.hasresult)

    def get_flags(self):
        FLAG = {
            lldb.SBTarget    : Flags.RequiresTarget,
            lldb.SBProcess   : Flags.RequiresProcess,
            lldb.SBThread    : Flags.RequiresThread,
            lldb.SBValueList : Flags.RequiresRegContext | Flags.RequiresFrame,
            lldb.SBFrame     : Flags.RequiresFrame,
            lldb.SBBlock     : Flags.RequiresFrame,
            lldb.SBFunction  : Flags.RequiresFrame,
            lldb.SBModule    : Flags.RequiresFrame,
            lldb.SBFileSpec  : Flags.RequiresFrame,
        }
        return self.flags | FLAG[self.context]
    def get_long_help(self):
        return self.help.format_help() if self.help else 'No help is available.'
    def get_short_help(self):
        return self.help.format_usage() if self.help else 'No usage information is available.'
    def __call__(self, debugger, command, context, result):
        argv = shlex.split(command) if command else self.default

        if self.help:
            if argv is None:
                result.Clear()
                map(result.AppendMessage, self.help.format_usage().split('\n'))
                return
            try: res = self.help.parse_args(argv)
            except SystemExit: return
        else:
            res = argv

        ctx = self.convert(self.context, (debugger,context))
        return self.callable(ctx, res, result)

    @staticmethod
    def command(context, arguments):
        raise NotImplementedError

### generalized lldb object tools
class module(object):
    separator = '`' if platform.system() == 'Darwin' else '!'
    @classmethod
    def list(cls, target, string, all=True, ignorecase=True):
        results = ((i,m) for i,m in enumerate(target.modules) if fnmatch.fnmatch(m.file.basename.lower() if ignorecase else m.file.basename, string.lower() if ignorecase else string))
        for i,m in results:
            if not all and not cls.mappedQ(m):
                continue
            yield '[{:d}] {:s}'.format(i, cls.repr(m))
        return

    @classmethod
    def byaddress(cls, target, address):
        res = (m for m in target.modules if cls.address(m) <= address < cls.address(m)+cls.loadsize(m))
        return next(res)

    @classmethod
    def mappedQ(cls, m):
        res = cls.address(m)
        return res not in (0,lldb.LLDB_INVALID_ADDRESS)

    @classmethod
    def address(cls, m):
        res = m.GetObjectFileHeaderAddress()
        return res.file_addr if res.load_addr == lldb.LLDB_INVALID_ADDRESS else res.load_addr

    @classmethod
    def filesize(cls, m):
        return sum(s.file_size for s in m.sections if s.name != '__PAGEZERO')

    @classmethod
    def loadsize(cls, m):
        return sum(s.size for s in m.sections if s.name != '__PAGEZERO')

    @classmethod
    def repr(cls, m):
        addr,size = cls.address(m),cls.loadsize(m)
        start = '0x{:x}'.format(addr) if cls.mappedQ(m) else '{unmapped}'
        return '{name:s} {triple:s} {fullname:s} {address:s}:+0x{size:x} num_sections={sections:d} num_symbols={symbols:d}'.format(address=start, size=size, name=m.file.basename, triple=m.triple, fullname=m.file.fullpath, symbols=len(m.symbols), sections=len(m.sections))

class section(object):
    SUMMARY_SIZE = 0x10

    @classmethod
    def repr(cls, s):
        e = lldb.SBError()
        try:
            section_data = s.GetSectionData()
            data = repr(section_data.ReadRawData(e, 0, cls.SUMMARY_SIZE))
            if e.Fail(): raise Exception
        except:
            data = '???'
        return '[0x{address:x}] {name:!r} 0x{offset:x}:+0x{size:x}{:s}'.format(name=s.name, offset=s.file_offset, size=s.size, address=s.file_addr, data=(' '+data if data else ''))

class symbol(object):
    @classmethod
    def list(cls, target, string, all=False, ignorecase=True):
        fullmatch,modulematch,symmatch = None,None,None
        if module.separator in string:
            modulematch,symmatch = string.split(module.separator, 1)
        else:
            fullmatch,symmatch = string,string

        total = 0
        for m in target.modules:
            if not all and not module.mappedQ(m): continue
            if modulematch and not fnmatch.fnmatch(m.file.basename.lower() if ignorecase else m.file.basename, modulematch.lower() if ignorecase else modulematch):
                continue

            prefix = m.file.basename + module.separator

            # check matches
            res = set()
            if fullmatch:
                res.update(s for s in m.symbols if fnmatch.fnmatch((prefix+s.name).lower() if ignorecase else (prefix+s.name), fullmatch.lower() if ignorecase else fullmatch))
            if symmatch:
                res.update(s for s in m.symbols if fnmatch.fnmatch(s.name.lower() if ignorecase else s.name, symmatch.lower() if ignorecase else symmatch))
            if not res: continue

            # start yielding our results
            for i,s in enumerate(res):
                yield '[{:d}] {:s}'.format(total+i, prefix+cls.repr(s))
            total += i + 1
        return

    @classmethod
    def address(cls, s):
        return s.addr.file_addr if s.addr.load_addr == lldb.LLDB_INVALID_ADDRESS else s.addr.load_addr

    @classmethod
    def size(cls, s):
        addr = cls.address(s)
        end = s.end_addr.file_addr if s.end_addr.load_addr == lldb.LLDB_INVALID_ADDRESS else s.end_addr.load_addr
        return end-addr

    @classmethod
    def repr(cls, s):
        TYPE_PREFIX = 'eTypeClass'
        start = cls.address(s)
        end = start + cls.size(s)

        types = {getattr(lldb,n) : n[len(TYPE_PREFIX):] for n in dir(lldb) if n.startswith(TYPE_PREFIX)}
        attributes = (n for n in ('external','synthetic') if getattr(s,n))
        if s.type in (lldb.eTypeClassFunction,):
            attributes = itertools.chain(attributes, ('instructions={:d}'.format(len(s.instructions))))
        attributes=filter(None,attributes)
        return '{name:s}{opt_mangled:s} type={type:s} 0x{addr:x}{opt_size:s}'.format(name=s.name, type=types.get(s.type,str(s.type)), opt_mangled=(' ('+s.mangled+')') if s.mangled else '', addr=start, opt_size=':+0x{:x}'.format(end-start) if end > start else '') + ((' ' + ' '.join(attributes)) if attributes else '')

class frame(object):
    @classmethod
    def registers(cls, frame):
        pc,fp,sp = frame.pc,frame.GetFP(),frame.sp
        regs = frame.registers
        raise NotImplementedError
    @classmethod
    def flags(cls, frame):
        regs = frame.registers
        raise NotImplementedError
    @classmethod
    def args(cls, frame):
        #lldb.LLDB_REGNUM_GENERIC_ARG1
        #lldb.LLDB_REGNUM_GENERIC_ARG2
        avars = frame.args
        raise NotImplementedError
    @classmethod
    def vars(cls, frame):
        lvars,svars = frame.locals,frame.statics
        raise NotImplementedError

class target(object):
    @classmethod
    def disassemble(cls, target, address, count, flavor=None):
        flavor = options.syntax if flavor is None else flavor
        addr = lldb.SBAddress(address, target)
        return target.ReadInstructions(addr, count, flavor)
    @classmethod
    def read(cls, target, address, count):
        process = target.GetProcess()

        err = lldb.SBError()
        err.Clear()
        data = process.ReadMemory(address, count, err)
        if err.Fail() or len(data) != count:
            raise ValueError("{:s}.{:s}.read : Unable to read 0x{:x} bytes from 0x{:x}".format(__name__, cls.__name__, count, address))
        return data

    ## dumping
    @classmethod
    def _gfilter(cls, iterable, itemsize):
        if itemsize < 8:
            for n in iterable: yield n
            return
        while True:
            nl,nh = next(iterable),next(iterable)
            yield (nh << (8*itemsize/2)) | nl
        return

    @classmethod
    def _hex_generator(cls, iterable, itemsize):
        maxlength = math.ceil(math.log(2**(itemsize*8)) / math.log(0x10))
        while True:
            n = next(iterable)
            yield '{:0{:d}x}'.format(n, int(maxlength))
        return

    @classmethod
    def _int_generator(cls, iterable, itemsize):
        maxlength = math.ceil(math.log(2**(itemsize*8)) / math.log(10))
        while True:
            n = next(iterable)
            yield '{:{:d}d}'.format(n, int(maxlength))
        return

    @classmethod
    def _float_generator(cls, iterable, itemsize):
        maxlength = 16
        while True:
            n = next(iterable)
            yield '{:{:d}f}'.format(n, int(maxlength))
        return

    @classmethod
    def _dump(cls, data, kind=1):
        lookup = {1:'B', 2:'H', 4:'I', 8:'L'}
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
    def _chardump(cls, data, width):
        printable = set(sorted(options.printable))
        printable = ''.join((ch if ch in printable else '.') for ch in map(chr,xrange(0,256)))
        res = array.array('c', data.translate(printable))
        return width, itertools.imap(''.join, itertools.izip_longest(*(iter(res),)*width, fillvalue=''))

    @classmethod
    def _row(cls, width, columns):
        result = []
        for itemsize,column in columns:
            data = (c for i,c in zip(xrange(0, width, itemsize),column))
            result.append(' '.join(data))
        return result

    @classmethod
    def _dump(cls, target, address, count, width, kind, content):
        data = cls.read(target, address, count)
        countup = int((count // width) * width)
        offset = ('{:0{:d}x}'.format(a, int(math.ceil(math.log(address+count)/math.log(0x10)))) for a in xrange(address, address+countup, width))
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
        return '\n'.join(map(' | '.join, cls._dump(target, address, count, width, kind, cls._hexdump)))

    @classmethod
    def itemdump(cls, target, address, count, kind, width=16):
        return '\n'.join(map(' | '.join, cls._dump(target, address, count, width, kind, cls._itemdump)))

### command definitions
@lldb_command('lm')
class list_modules(Command):
    context = lldb.SBTarget

    help = argparse.ArgumentParser(prog='lm', description='list all modules that match the specified glob')
    help.add_argument('-I', action='store_false', dest='ignorecase', default=True, help='case-sensitive matching')
    help.add_argument('-a', action='store_true', dest='all', default=False, help='list all modules, included ones that are not loaded yet.')
    help.add_argument('glob', action='store', default='*', help='glob to match module names with')

    @staticmethod
    def command(target, args):
        for res in module.list(target, args.glob, all=args.all, ignorecase=args.ignorecase):
            print res
        return

@lldb_command('ls')
class list_symbols(Command):
    context = lldb.SBTarget

    help = argparse.ArgumentParser(prog='ls', description='list all symbols that match the specified glob against a module with it\'s symbols')
    help.add_argument('-I', action='store_false', dest='ignorecase', default=True, help='case-sensitive matching')
    help.add_argument('-a', action='store_true', dest='all', default=False, help='list all symbols, including ones that are from unloaded modules.')
    help.add_argument('glob', action='store', default='*', help='glob to match symbol names with')

    @staticmethod
    def command(target, args):
        for res in symbol.list(target, args.glob, all=args.all, ignorecase=args.ignorecase):
            print res
        return

@lldb_command('gvars')
class list_globals(Command):
    context = lldb.SBProcess
    @staticmethod
    def command(target, args):
        raise NotImplementedError   # FIXME

@lldb_command('lvars')
class list_locals(Command):
    context = lldb.SBFrame
    @staticmethod
    def command(target, args):
        frame.vars
        raise NotImplementedError   # FIXME

@lldb_command('avars')
class list_arguments(Command):
    context = lldb.SBFrame
    @staticmethod
    def command(target, args):
        frame.args
        raise NotImplementedError   # FIXME

@lldb_command('ln')
class list_near(Command):
    context = lldb.SBTarget
    @staticmethod
    def command(target, args):
        # FIXME: search through all symbols for the specified address
        raise NotImplementedError

@lldb_command('show_regs')
class show_regs(Command):
    context = lldb.SBFrame

    flagbits = [
        (1, ["CF", "NC"]),
        (2, ["PF", "NP"]),
        (4, ["AF", "NA"]),
        (8, ["ZF", "NZ"]),
        (16, ["SF", "NS"]),
        (32, ["TF", "NT"]),
        (64, ["IF", "NI"]),
        (128, ["DF", "ND"]),
        (256, ["OF", "NO"]),
        (512, ["IOPL", ""]),
        (1024, ["NT", ""]),
        (2048, ["", ""]),
        (4096, ["RF", ""]),
        (8192, ["VM", ""]),
    ]

    @staticmethod
    def regs32(regs):
        res = []
        res.append("[eax: 0x%08x] [ebx: 0x%08x] [ecx: 0x%08x] [edx: 0x%08x]"% (regs['eax'], regs['ebx'], regs['ecx'], regs['edx']))
        res.append("[esi: 0x%08x] [edi: 0x%08x] [esp: 0x%08x] [ebp: 0x%08x]"% (regs['esi'], regs['edi'], regs['esp'], regs['ebp']))
        return '\n'.join(res)

    @staticmethod
    def eflags(regs):
        fl, names = regs['eflags'], (3, 4, 8, 0, 7, 6)
        res = (v[1][0 if fl & v[0] else 1] for v in map(show_regs.flagbits.__getitem__, names))
        return '[eflags: %s]'% ' '.join(res)

    @staticmethod
    def regs64(regs):
        res = []
        res.append("[rax: 0x%016lx] [rbx: 0x%016lx] [rcx: 0x%016lx]"% (regs['rax'], regs['rbx'], regs['rcx']))
        res.append("[rdx: 0x%016lx] [rsi: 0x%016lx] [rdi: 0x%016lx]"% (regs['rdx'], regs['rsi'], regs['rdi']))
        res.append("[rsp: 0x%016lx] [rbp: 0x%016lx] [ pc: 0x%016lx]"% (regs['rsp'], regs['rbp'], regs['rip']))
        res.append("[ r8: 0x%016lx] [ r9: 0x%016lx] [r10: 0x%016lx]"% (regs['r8'],  regs['r9'],  regs['r10']))
        res.append("[r11: 0x%016lx] [r12: 0x%016lx] [r13: 0x%016lx]"% (regs['r11'], regs['r12'], regs['r13']))
        res.append("[r14: 0x%016lx] [r15: 0x%016lx] [efl: 0x%016lx]"  % (regs['r14'], regs['r15'], regs['rflags']))
        return '\n'.join(res)

    @staticmethod
    def rflags(regs):
        fl, names = regs['rflags'], (3, 4, 8, 0, 7, 6)
        res = (v[1][0 if fl & v[0] else 1] for v in map(show_regs.flagbits.__getitem__, names))
        return '[rflags: %08x %s]'% (((fl & 0xffffffff00000000) >> 32), ' '.join(res))

    @staticmethod
    def get(frame, name):
        res, = (value for value in frame.GetRegisters() if name.lower() in value.GetName().lower())
        return {n.GetName() : float(n.GetValue()) if '.' in n.GetValue() else int(n.GetValue(),16)  for n in res}

    @staticmethod
    def command(frame, args):
        target = frame.GetThread().GetProcess().GetTarget()
        bits = target.GetAddressByteSize() * 8
        res = show_regs.get(frame, 'general purpose')

        print('-=[registers]=-')
        if bits == 32:
            print(show_regs.regs32(res))
            print(show_regs.eflags(res))
        elif bits == 64:
            print(show_regs.regs64(res))
            print(show_regs.rflags(res))
        else: raise NotImplementedError(bits)

@lldb_command('show_stack')
class show_stack(Command):
    context = lldb.SBFrame
    @staticmethod
    def command(frame, args):
        t = frame.GetThread().GetProcess().GetTarget()
        bits = t.GetAddressByteSize() * 8
        res = show_regs.get(frame, 'general purpose')
        print('-=[stack]=-')
        if bits == 32:
            print(target.hexdump(t, res['esp'], 0x40, 'I'))
        elif bits == 64:
            print(target.hexdump(t, res['rsp'], 0x40, 'L'))
        else: raise NotImplementedError(bits)

@lldb_command('show_code')
class show_code(Command):
    context = lldb.SBFrame
    @staticmethod
    def command(frame, args):
        t = frame.GetThread().GetProcess().GetTarget()
        bits = t.GetAddressByteSize() * 8

        # FIXME: move this back a few instructions so we can see what was just executed
        pc = frame.GetPC()

        print('-=[disassembly]=-')
        if bits == 32:
            print('\n'.join(map(str,target.disassemble(t, pc, 10))))
        elif bits == 64:
            print('\n'.join(map(str,target.disassemble(t, pc, 6))))
        else: raise NotImplementedError(bits)

@lldb_command('h')
class show(Command):
    context = lldb.SBFrame
    @staticmethod
    def command(frame, args):
        show_regs.command(frame, args)
        print('')
        show_stack.command(frame, args)
        print('')
        show_code.command(frame, args)

@lldb_command('maps')
class show_maps(Command):
    context = lldb.SBProcess
    @staticmethod
    def command(process, args):
        raise NotImplementedError

@lldb_command('cwd')
class getcwd(Command):
    context = lldb.SBTarget
    @staticmethod
    def command(target, args):
        li = target.GetLaunchInfo()
        print(li.GetWorkingDirectory())
