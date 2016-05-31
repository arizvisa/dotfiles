if __name__ == '__main__':
    raise RuntimeError("Not intended to be run as a stand-alone application")

import sys,os,platform,logging
import types,itertools,operator,functools
import platform,fnmatch
import commands,argparse,shlex
import lldb

### lldb utilities
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
        klass_sync = itertools.starmap('command script add -c {:s}.{:s} -s {:s} {:s}'.format, ((klass.__module__,klass.__name__,cls.synchronicity[command],command) for command,klass in cls.cls_cache if command not in cls.synchronicity))
        handleCommand = cls.stupid(interpreter.HandleCommand, lldb.SBCommandReturnObject)
        return map(handleCommand, itertools.chain(func, klass,klass_sync))

def __lldb_init_module(debugger, globals):
    interp = debugger.GetCommandInterpreter()
    if any(not n.Succeeded() for n in lldb_command.load(interp)):
        logging.warn('Error trying to define python commands')
    return

#@lldb_command('example')
#def example(debugger, command, result, globals):
#    print(command)
#    print(result)

#@lldb_command('example')
#class example(object):
#    def __init__(debugger, globals):
#        pass
#    def get_flags(self):
#        lldb.eCommandProcessMustBeLaunched
#        lldb.eCommandProcessMustBePaused
#        lldb.eCommandRequiresFrame
#        lldb.eCommandRequiresProcess
#        lldb.eCommandRequiresRegContext
#        lldb.eCommandRequiresTarget
#        lldb.eCommandRequiresThread
#        lldb.eCommandTryTargetAPILok
#        pass
#    def get_long_help(self):
#    def get_short_help(self):
#    def __call__(self, debugger, command, result, globals):
#        pass

### general utilities
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

### function definitions
@lldb_command('lm')
def list_modules(debugger, command, result, globals):
    argh = argparse.ArgumentParser(prog='list-modules', description='list all modules that match the specified glob')
    argh.add_argument('-I', action='store_false', dest='ignorecase', default=True, help='case-sensitive matching')
    argh.add_argument('-a', action='store_true', dest='all', default=False, help='list all modules, included ones that are not loaded yet.')
    argh.add_argument('glob', action='store', default='*', help='glob to match module names with')
    args = argh.parse_args(shlex.split(command or '*'))

    result.Clear()
    for res in module.list(debugger.GetSelectedTarget(), args.glob, all=args.all, ignorecase=args.ignorecase):
        result.AppendMessage(res)
    result.SetStatus(lldb.eReturnStatusSuccessFinishResult)

@lldb_command('ls')
def list_symbols(debugger, command, result, globals):
    argh = argparse.ArgumentParser(prog='list-symbols', description='list all symbols that match the specified glob against a module with it\'s symbols')
    argh.add_argument('-I', action='store_false', dest='ignorecase', default=True, help='case-sensitive matching')
    argh.add_argument('-a', action='store_true', dest='all', default=False, help='list all symbols, including ones that are from unloaded modules.')
    argh.add_argument('glob', action='store', default='*', help='glob to match symbol names with')
    args = argh.parse_args(shlex.split(command))

    result.Clear()
    if not command:
        argh.print_usage()
        return

    for res in symbol.list(debugger.GetSelectedTarget(), args.glob, all=args.all, ignorecase=args.ignorecase):
        result.AppendMessage(res)
    result.SetStatus(lldb.eReturnStatusSuccessFinishResult)

@lldb_command('gvars')
def list_globals(debugger, command, result, globals):
    result.Clear()
    raise NotImplementedError

@lldb_command('lvars')
def list_locals(debugger, command, result, globals):
    result.Clear()
    raise NotImplementedError

@lldb_command('avars')
def list_arguments(debugger, command, result, globals):
    result.Clear()
    raise NotImplementedError

@lldb_command('ln')
def list_near(debugger, command, result, globals):
    result.Clear()
    opt = lldb.SBExpressionOptions()
    opt.SetTryAllThreads()
    res = debugger.GetSelectedTarget().EvaluateExpression(command, opt)
    raise NotImplementedError

def show_flags(frame):
    raise NotImplementedError

def show_regs(result):
    frame = lldb.SBFrame
    result.Clear()
    map(result.AppendMessage, '-=[registers]=-'.split('\n'))
    map(result.AppendMessage, frame.registers(frame).split('\n'))
    raise NotImplementedError

def show_stack(result):
    result.Clear()
    map(result.AppendMessage, '\n-=[stack]=-\n'.split('\n'))
    raise NotImplementedError

def show_code(result):
    result.Clear()
    map(result.AppendMessage, '\n-=[disassembly]=-\n'.split('\n'))
    raise NotImplementedError
