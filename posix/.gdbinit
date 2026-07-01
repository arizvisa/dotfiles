python import operator,itertools,functools,subprocess
python from pprint import pprint as pp
python from pprint import pformat as pf
python from __future__ import print_function
python p, pp, pf = print, pp, pf

### python helpers
python
class function(gdb.Function):
    def __init__(self, *group):
        cls = self.__class__
        if group:
            [space] = group
            if not issubclass(space, workspace):
                raise AssertionError("Received an unsupported workspace type (`{:s}`) during construction of `{:s}`.".format('.'.join(filter(None, [space.__module__, space.__name__])), '.'.join(filter(None, [cls.__module__, cls.__name__]))))
            self.__space__ = space
        keyword = getattr(self, 'KEYWORD', cls.__name__)
        return super(function, self).__init__(keyword)
    @property
    def workspace(self):
        if hasattr(self, '__space__'):
            return self.__space__
        raise AttributeError("{!r} object has no attribute {!r}.".format(self.__class__.__name__, 'workspace'))
    def invoke(self, *args):
        raise NotImplementedError("Unable to invoke unimplemented function \"{:s}\" with arguments: {!s}".format('.'.join(getattr(cls, attribute) for attribute in ['__module__', '__name__'] if hasattr(cls, attribute)), args))

class command(gdb.Command):
    def __init__(self, *group):
        cls = self.__class__
        if group:
            [space] = group
            if not issubclass(space, workspace):
                raise AssertionError("Received an unsupported workspace type (`{:s}`) during construction of `{:s}`.".format('.'.join(filter(None, [space.__module__, space.__name__])), '.'.join(filter(None, [cls.__module__, cls.__name__]))))
            self.__space__ = space
        keyword = getattr(self, 'KEYWORD', cls.__name__)
        return super(command, self).__init__(keyword, getattr(self,'COMMAND',0))
    def invoke(self, argument, from_tty):
        description = "from tty ({!s})".format(from_tty) if from_tty else ''
        raise NotImplementedError("Unable to invoke unimplemented command \"{:s}\"{:s} with argument: {:s}".format('.'.join(getattr(cls, attribute) for attribute in ['__module__', '__name__'] if hasattr(cls, attribute)), " {:s}".format(description) if description else '', argument))
    def complete(self, text, word):
        return getattr(self,'COMPLETE',gdb.COMPLETE_NONE)
    @property
    def workspace(self):
        if hasattr(self, '__space__'):
            return self.__space__
        raise AttributeError("{!r} object has no attribute {!r}.".format(self.__class__.__name__, 'workspace'))

class workspace(object):
    __slots__, system = ['EXPORTS'], __import__('sys')
    @classmethod
    def register(cls):
        exports = getattr(cls, 'EXPORTS', ())
        available = {} if isinstance(exports, type('', (object,), {'__slots__': ['descriptor']}).descriptor.__class__) else {klass for klass in exports}
        invalid = {klass for klass in available if not issubclass(klass, (gdb.Command, gdb.Function))}

        if available:
            [ klass(cls) for klass in available - invalid ]
        else:
            gdb.write("Skipping registration of workspace `{:s}` due to no exports being defined.".format('.'.join(filter(None, [cls.__module__, cls.__name__]))))

        for klass in invalid:
            gdb.write("Refusing to register class `{:s}` from workspace `{:s}` due to inheriting of an unsupported type.\n".format('.'.join(filter(None, [klass.__module__, klass.__name__])), '.'.join(filter(None, [cls.__module__, cls.__name__]))))

        # update the namespace of the caller to remove all references to
        # the workspace that we registered. this is dirty, but whatever...
        #snapshot = cls.depth(2)
        #[current, parent] = (frame for frame in snapshot)
        #names = {name for name, value in parent.f_locals.items() if id(value) == id(cls)}
        #[ parent.f_locals.pop(name) for name in names ]
        #names = {name for name, value in parent.f_globals.items() if id(value) == id(cls)}
        #[ parent.f_globals.pop(name) for name in names ]
        return
    @classmethod
    def depth(cls, count=-1):
        current = cls.system._getframe()
        results, frame = [], current.f_back
        while frame and (count < 0 or count > 0):
            results.append(frame)
            frame = frame.f_back
            count -= 1
        return (frame for frame in results)
    def __init__(self):
        cls = self.__class__
        raise SystemError("Unable to instantiate an object of type `{:s}`.".format('.'.join(filter(None, [cls.__module__, cls.__name__]))))

import re,string
class execute(command):
    '''Evaluate the parameter and execute it as a command.'''
    def invoke(self, string, from_tty):
        gdb.execute(gdb.parse_and_eval(string).string())
class emit(command):
    '''Evaluate the parameter and write it to the terminal.'''
    COMMAND = gdb.COMMAND_DATA
    def invoke(self, string, from_tty):
        gdb.write(gdb.parse_and_eval(string).string())
        gdb.flush()
class clear(command):
    '''Clear the current terminal screen.'''
    def invoke(self, string, from_tty):
        gdb.execute('shell clear')
class clip(command):
    '''Evaluate the parameter and copy it to the clipboard.'''
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
    '''Return the type of the specified parameter as a string.'''
    def invoke(self, symbol):
        return str(symbol.type).replace(' ','')
class sizeof(function):
    '''Return the size of the specified parameter.'''
    def invoke(self, value):
        try:
            type = gdb.lookup_type(value.string())
        except gdb.error:
            type = value.type
        return type.sizeof

class sprintf(function):
    '''Return each of the given parameters as a string formatted according to the first parameter.'''
    def invoke(self, *args):
        res,formatter,args = '',string.Formatter(),iter(args)
        fmt = re.sub(r'%(\d+\.?\d+f|0?\d*[\w^\d]|\d*[\w^\d]|-0?\d*[\w^\d]|-\d*[\w^\d])', lambda m:'{:'+m.groups(1)[0]+'}', next(args).string())
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
execute(),emit(),clear(),typeof(),sizeof(),clip(),sprintf()

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

# FIXME: this should be a workspace
class Memory(object):
    printable = set().union(string.printable).difference(string.whitespace).union(' ')

    @classmethod
    def read(cls, inferior, address, count):
        res = inferior.read_memory(address, count)
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
        offset = ('{:#0{:d}x}'.format(a, math.trunc(math.floor(math.log(address + count) / math.log(0x10) + 1))) for a in range(address, address + math.trunc(countup), width))
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
    COMMAND, COMPLETE = gdb.COMMAND_DATA, gdb.COMPLETE_EXPRESSION
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
class db(__dumphex__):
    '''Dump the specified address in 8-bit hexadecimal (base16).'''
    kind = 'B'
class dw(__dumphex__):
    '''Dump the specified address in 16-bit hexadecimal (base16).'''
    kind = 'H'
class dd(__dumphex__):
    '''Dump the specified address in 32-bit hexadecimal (base16).'''
    kind = 'I'
class dq(__dumphex__):
    '''Dump the specified address in 64-bit hexadecimal (base16).'''
    kind = 'Q' if sys.version_info.major == 3 else 'L'
db(),dw(),dd(),dq()

# integrals
class dnb(__dumpitem__):
    '''Dump the specified address in 8-bit decimal (base10).'''
    kind = 'B'
class dnw(__dumpitem__):
    '''Dump the specified address in 16-bit decimal (base10).'''
    kind = 'H'
class dnd(__dumpitem__):
    '''Dump the specified address in 32-bit decimal (base10).'''
    kind = 'I'
class dnq(__dumpitem__):
    '''Dump the specified address in 64-bit decimal (base10).'''
    kind = 'Q' if sys.version_info.major == 3 else 'L'
dnb(),dnw(),dnd(),dnq()

# floating-point
class df(__dumpitem__):
    '''Dump the specified address in 32-bit floats (single).'''
    kind = 'f'
class dD(__dumpitem__):
    '''Dump the specified address in 64-bit floats (double).'''
    kind = 'd'
df(),dD()

# binary
class dyb(__dumpbinary__):
    '''Dump the specified address in 8-bit binary (base2).'''
    kind = 'B'
class dyw(__dumpbinary__):
    '''Dump the specified address in 16-bit binary (base2).'''
    kind = 'H'
class dyd(__dumpbinary__):
    '''Dump the specified address in 32-bit binary (base2).'''
    kind = 'I'
class dyq(__dumpbinary__):
    '''Dump the specified address in 64-bit binary (base2).'''
    kind = 'Q' if sys.version_info.major == 3 else 'L'
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

class wat(command):
    '''Display information about the specified symbol.'''
    COMMAND, COMPLETE = gdb.COMMAND_USER, gdb.COMPLETE_SYMBOL
    DOMAINS = {value : key for key, value in gdb.__dict__.items() if all([key.startswith('SYMBOL_'), key.endswith('_DOMAIN')])}
    CLASS = {value : key for key, value in gdb.__dict__.items() if key.startswith('SYMBOL_LOC_')}
    TYPE = {operator.attrgetter(attribute) : attribute for attribute in ['needs_frame', 'is_argument', 'is_constant', 'is_function', 'is_variable', 'is_valid']}

    def blocks(self, block):
        left, right = block.end, block.start
        while block is not None:
            if (left, right) != (block.start, block.end):
                yield block.start, block.end
            left, right, block = block.start, block.end, block.superblock
        return

    def invoke(self, string, from_tty, count=None):
        args = gdb.string_to_argv(string)
        if len(args) not in {1,2}:
            raise gdb.GdbError("usage: wat symbol [$pc]")
        symbol, pc = args if len(args) == 2 else args + [None]
        block = gdb.selected_frame().block() if pc is None else gdb.block_for_pc(gdb.parse_and_eval(pc).__int__() if isinstance(pc, str) else pc)
        if block is None:
            raise gdb.error("Unable to find basic block for {:s}.".format("program counter ({:#x})".format(gdb.parse_and_eval(pc).__int__() if isinstance(pc, str) else pc) if pc else 'current program counter'))

        result = {domain : gdb.lookup_symbol(symbol, block, domain) for domain in self.DOMAINS}
        locations = {domain : variable for domain, (variable, _) in result.items() if variable is not None}
        if not locations:
            raise gdb.error("Unable to locate symbol {:s}.".format(symbol))

        types = {description for F, description in self.TYPE.items() if any(map(F, locations.values()))}
        domains = {self.DOMAINS[domain] for domain in locations}
        classes = {self.CLASS[variable.addr_class] for _, variable in locations.items()}

        gdb.write("Symbol: {:s}\n".format(symbol))
        gdb.write("Type{:s}: {:s}\n".format('' if len(types) == 1 else 's', ', '.join(types)))
        gdb.write("Block: {:s}\n".format(' -> '.join("{:#x}..{:#x}".format(left, right) for left, right in self.blocks(block))))
        gdb.write("Domain{:s}: {:s}\n".format('' if len(domains) == 1 else 's', ', '.join(domains)))
        gdb.write("Class{:s}: {:s}\n".format('' if len(classes) == 1 else 's', ', '.join(classes)))
        gdb.flush()
wat()

class process_mappings(workspace):
    commands = functions = set()

    @classmethod
    def filter_by_glob(cls, glob, fnmatch=__import__('fnmatch')):
        def filter(iterable):
            return fnmatch.filter(iterable, glob)
        return filter

    @classmethod
    def filter_by_name(cls, glob, fnmatch=__import__('fnmatch')):
        def filter(iterable):
            transformed = ((path, cls.os.path.basename(path)) for path in iterable)
            filtered = (path for path, name in transformed if fnmatch.fnmatch(name, glob))
            # FIXME: should really be using fnmatch.translate and then compiling
            #        to a regex to avoid fnmatch doing it for every iteration.
            return filtered
        return filter

    expected_field_names = ['Start Addr', 'End Addr', 'Size', 'Offset', 'Perms', 'File']
    reduced_field_names = ['Start Addr', 'End Addr', 'Size', 'Offset', 'File']
    @classmethod
    def mappings(cls):
        mappings = gdb.execute('info proc mappings', False, True)
        rows = mappings.strip().split('\n')
        iterable = (index for index, row in enumerate(rows) if row.lstrip().startswith('0x'))
        index = next(iterable, 0)
        headerline = rows[:index][-1]

        # Hack to figure if the "Perms" column is missing from the mappings.
        is_reduced = 'Perms' not in headerline
        headers = headerline.rsplit(None, 3 if is_reduced else 4)
        iterable = itertools.chain(filter(None, headers[:1][0].rsplit('  ')), headers[1:])
        split = [header for header in iterable]

        # Hack to find columns that are the same size as the "Start Addr" field.
        field_names = cls.reduced_field_names if is_reduced else cls.expected_field_names
        if len(split) != len(field_names):
            expected = len("{:#0{:d}x}".format(0, 2 + 32 // 4))
            target = split[0]
            split = itertools.chain([target[:expected], target[expected:]], split[1:])

        fields = [header.strip() for header in split]
        if any(name not in fields for name in field_names):
            gdb.write("The expected field names ({!s}) were changed by gdb to {!s}".format(field_names, fields))
        return [{field : value for field, value in zip(fields, row.strip().split())} for row in rows[index:]]

    @classmethod
    def columns(cls, results):
        fields = {}
        for row in results:
            iterable = ((field, column) for field, column in row.items())
            columns = {field : len(column) for field, column in iterable if len(column) > fields.get(field, -1)}
            fields.update(columns)
        return fields

    @classmethod
    def format(cls, fields, columns):
        range = ("{:{:s}{:d}s}".format(fields[address], justification, columns[address]) for address, justification in zip(['Start Addr', 'End Addr'], '><'))
        #relative = ''.join([fields['Offset'], '+', fields['Size']])
        relative = '+'.join("{:#0{:d}x}".format(int(fields[field], 16), columns[field]) for field in ['Offset', 'Size'])
        location = "{:s} {:<{:d}s}".format('..'.join(range), "({:s})".format(relative), 2 + 1 + sum(columns[field] for field in ['Offset', 'Size']))
        permissions = "<{:{:d}s}>".format(fields['Perms'], 2 + columns['Perms']) if 'Perms' in fields else '<?Perms>'
        filename = "{:{:d}s}".format(fields.get(cls.expected_field_names[-1], ''), columns.get(cls.expected_field_names[-1], 0))
        #return "{:s} {:>{:d}s} {:{:d}s}".format(location, fields['Perms'], columns['Perms'], fields.get('objfile', ''), columns['objfile'])
        return ' '.join([location, permissions, filename])

    @commands.add
    class select(command):
        '''List the segment mappings for the current process (inferior).'''
        KEYWORD = 'select_process_mappings'
        COMMAND, COMPLETE = gdb.COMMAND_STATUS, gdb.COMPLETE_FILENAME

        def complete(self, arguments_string, last):
            # FIXME: we should probably enumerate the mappings so we can
            #        complete things. we should also complete the known
            #        parameters since they're available for this command.
            return self.COMPLETE

        def invoke(self, string, from_tty, count=None):
            args = gdb.string_to_argv(string)
            if not(args):
                return self.invoke_raw(from_tty, count=count)

            elif not(len(args) in {2} and args[0] in 'amM'):
                raise gdb.GdbError("usage: select_process_mappings [a|m|M] [address|glob]")

            subcommand, remaining = args
            if subcommand in 'a':
                parsed = gdb.parse_and_eval(remaining)
                address = int(parsed)
                return self.invoke_address(address, from_tty, count=count)

            elif subcommand in 'm':
                return self.invoke_path(self.workspace.filter_by_name(remaining), from_tty, count=count)

            elif subcommand in 'M':
                return self.invoke_path(self.workspace.filter_by_glob(remaining), from_tty, count=count)
            raise NotImplementedError(subcommand, remaining)

        def invoke_address(self, integer, from_tty, count=None):
            res, ordered, field = {}, self.workspace.mappings(), self.workspace.expected_field_names[-1]
            [res.setdefault(item.get(field, ''), []).append(index) for index, item in enumerate(ordered)]
            iterable = ((item.get(field, ''), parsenum(item['Start Addr']), parsenum(item['End Addr'])) for item in ordered)
            selected = {objfile for objfile, start, end in iterable if start <= integer < end}
            #indices = itertools.chain(*(res[objfile] for objfile in filteritems(res)))
            indices = sorted(itertools.chain(*map(functools.partial(operator.getitem, res), selected)))
            results = [ordered[index] for index in indices]
            columns = self.workspace.columns(results)
            [ gdb.write("{:s}\n".format(self.workspace.format(item, columns))) for item in results ]
            if not results:
                size = int(gdb.parse_and_eval("sizeof({:s})".format('void*')))
                gdb.write("No mappings were found at the specified address {:#0{:d}x}.\n".format(integer, 2 + 2 * size))
            return

        def invoke_path(self, filteritems, from_tty, count=None):
            res, ordered, field = {}, self.workspace.mappings(), self.workspace.expected_field_names[-1]
            [res.setdefault(item[field], []).append(index) for index, item in enumerate(ordered) if field in item]
            #filtered = {objfile for objfile in filteritems(res)}
            #indices = itertools.chain(*(res[objfile] for objfile in filteritems(res)))
            indices = sorted(itertools.chain(*map(functools.partial(operator.getitem, res), filteritems(res))))
            results = [ordered[index] for index in indices]
            columns = self.workspace.columns(results)
            [ gdb.write("{:s}\n".format(self.workspace.format(item, columns))) for item in results ]
            if not(results):
                gdb.write('No mappings were matched for the specified glob.\n')
            return

        def invoke_raw(self, from_tty, count=None):
            res, ordered, field = {}, self.workspace.mappings(), self.workspace.expected_field_names[-1]
            [res.setdefault(item[field], []).append(index) for index, item in enumerate(ordered) if field in item]
            results = [ordered[index] for index in range(len(ordered))]
            columns = self.workspace.columns(results)
            [ gdb.write("{:s}\n".format(self.workspace.format(item, columns))) for item in results ]
            if not(results):
                gdb.write('No available mappings were found in the process.\n')
            return

    import os.path

    class baseaddress(function):
        '''Return the base address of the specified segment by filename, module, or partial path.'''
        def by_path(self, path):
            field = self.workspace.expected_field_names[-1]
            objfiles, mappings, fp = {}, self.workspace.mappings(), self.workspace.os.path.normpath(path[1:] if path.startswith(2 * self.workspace.os.path.sep) else path)
            [objfiles.setdefault(item.get(field, ''), []).append(int(item['Start Addr'], 16)) for index, item in enumerate(mappings) if int(item['Offset'], 16) == 0]
            candidates = {ea for ea in objfiles[fp]}
            if len(candidates) > 1:
                gdb.write("WARNING: More than one base address was found for path: {:s}\n".format(fp))
                [gdb.write("WARNING: Path at {:s} is mapped at {:#x}\n.".format(fp, ea)) for ea in sorted(candidates)]
                return next(iter(candidates))
            return next(iter(candidates)) if candidates else -1

        def by_module(self, module):
            field = self.workspace.expected_field_names[-1]
            objfiles, mappings, path = {}, self.workspace.mappings(), self.workspace.os.path
            [objfiles.setdefault(item.get(field, ''), []).append(item) for index, item in enumerate(mappings) if int(item['Offset'], 16) == 0]
            iterable = (name for name in objfiles if path.split(name)[-1] == module)
            candidates = {(item.get(field, ''), int(item['Start Addr'], 16)) for item in itertools.chain(*(objfiles[name] for name in iterable))}
            if not candidates:
                # FIXME: need to return a failure or emptiness of some sort
                return gdb.Value(-1)
            if len(candidates) > 1:
                gdb.write("WARNING: More than one base address was found for module: {:s}\n".format(module))
                [gdb.write("WARNING: Path at {:s} is mapped at {:#x}.\n".format(fp, ea)) for fp, ea in sorted(candidates)]
                candidates = [next(iter(candidates))]
            [(_, ea)] = candidates
            return ea

        def by_subpath(self, subpath):
            field = self.workspace.expected_field_names[-1]
            mappings, path = self.workspace.mappings(), self.workspace.os.path
            objfiles, components = {}, path.normpath(subpath).split(path.sep)
            for index, item in enumerate(mappings):
                if int(item['Offset'], 16) != 0:
                    continue
                split = item.get(field, '').split(path.sep)
                sliced = split[-len(components):] if components else split
                objfiles.setdefault(path.join(*sliced), []).append(item)
            iterable = (name for name in objfiles if name == subpath)
            candidates = {(item.get(field, ''), int(item['Start Addr'], 16)) for item in itertools.chain(*(objfiles[name] for name in iterable))}
            if not candidates:
                # FIXME: need to return a failure or emptiness of some sort
                return gdb.Value(-1)
            if len(candidates) > 1:
                gdb.write("WARNING: More than one base address was found for sub-path: {:s}\n".format(module))
                [gdb.write("WARNING: Path at {:s} is mapped at {:#x}.\n".format(fp, ea)) for fp, ea in sorted(candidates)]
                candidates = [next(iter(candidates))]
            [(_, ea)] = candidates
            return ea

        def by_string(self, string):
            path = self.workspace.os.path
            if path.sep not in string:
                return self.by_module(string)
            elif path.isabs(string):
                return self.by_path(string)
            return self.by_subpath(string)

        def by_reference(self, ref):
            address = parameter.address
            return self.by_address(int(address))

        def by_address(self, ea):
            mappings, path, field = self.workspace.mappings(), self.workspace.os.path, self.workspace.expected_field_names[-1]

            # FIXME: this is pretty inefficient, but we can't improve it unless we actively
            #        track when addresses are mapped/unmapped inside the address space.
            results, objfiles = {}, {}
            for index, item in enumerate(mappings):
                left, right = (int(item[field], 16) for field in ['Start Addr', 'End Addr'])
                name = item.get(field, '')
                if left <= ea < right:
                    results.setdefault(name, set()).add((left, right))
                if int(item['Offset'], 16) != 0:
                    continue
                objfiles.setdefault(name, []).append(item)

            iterable = itertools.chain(*(objfiles[name] for name in results))
            candidates = {(item.get(field, ''), int(item['Start Addr'], 16)) for item in iterable}
            if not candidates:
                # FIXME: need to return a failure or emptiness of some sort
                return gdb.Value(-1)
            if len(candidates) > 1:
                gdb.write("WARNING: More than one base address was found for address: {:#x}\n".format(ea))
                [gdb.write("WARNING: Path at {:s} is mapped at {:#x}.\n".format(fp, ea)) for fp, ea in sorted(candidates)]
                candidates = [next(iter(candidates))]
            [(_, ea)] = candidates
            return ea

        def invoke(self, *parameters):
            integerish = {gdb.TYPE_CODE_PTR, gdb.TYPE_CODE_INT}
            if not(parameters):
                pc = gdb.parse_and_eval('$pc')
                return self.by_address(int(pc))

            elif len(parameters) != 1:
                raise gdb.GdbError('Expected 0 or 1 parameter for $baseaddress')

            else:
                [parameter] = parameters

            if parameter.type.is_string_like:
                return self.by_string(parameter.string())
            elif parameter.type.is_scalar and parameter.type.code in integerish:
                return self.by_address(int(parameter))
            return self.by_reference(parameter)

    @functions.add
    class baseoffset(baseaddress):
        '''Return an offset from the base address of the segment for the provided address.'''
        def invoke(self, *parameters):
            integerish = {gdb.TYPE_CODE_PTR, gdb.TYPE_CODE_INT}
            pc = gdb.parse_and_eval('$pc')
            [parameter] = parameters if parameters else [pc]
            if parameter.type.is_string_like:
                pc, ea = pc, self.by_string(parameter.string())
            elif parameter.type.is_scalar and parameter.type.code in integerish:
                pc, ea = int(parameter), self.by_address(int(parameter))
            else:
                pc, ea = int(parameter), self.by_reference(parameter)
            return gdb.parse_and_eval("{:#x} - {:#x}".format(pc, ea))

    # XXX: now we can get rid of the baseaddress function
    baseaddress = functions.add(baseaddress)

    EXPORTS = {item for item in itertools.chain(commands, functions)}

process_mappings.register()
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

document show_regs32
Output the register state for the 32-bit Intel architecture.
end

document show_regs64
Output the register state for the 64-bit Intel architecture.
end

define show_stack32
    set variable $_data_rows = 8

    emit "\n-=[stack]=-\n"
    if $access($sp, sizeof(long))
        if $argc > 0
            emit $hexdump($sp, $arg0 * 0x10 / sizeof(int), 'I')
        else
            emit $hexdump($sp, $_data_rows * 0x10 / sizeof(int), 'I')
            #x/6wx $sp
        end
    else
        emit $sprintf("... address %p not available ...\n", $esp)
    end
end

define show_stack64
    set variable $_data_rows = 8

    emit "\n-=[stack]=-\n"
    if $access($sp, sizeof(long))
        if $argc > 0
            emit $hexdump($sp, $arg0 * 0x10 / sizeof(long), 'L')
        else
            emit $hexdump($sp, $_data_rows * 0x10 / sizeof(long), 'L')
            #x/6gx $sp
        end
    else
        emit $sprintf("... address %p not available ...\n", $rsp)
    end
end

document show_stack32
Dump the memory at the address specified by the $sp register containing the 32-bit stack.
end

document show_stack64
Dump the memory at the address specified by the $sp register containing the 64-bit stack.
end

define show_data32
    set variable $_data_rows = 8

    if $access($arg0, sizeof(long))
        if $argc > 1
            emit $hexdump($arg0, $arg1 * 0x10 / sizeof(long), 'I')
        else
            emit $hexdump($arg0, $_data_rows * 0x10 / sizeof(long), 'I')
        end
    else
        emit $sprintf("... address %p not available ...\n", $arg0)
    end
end

define show_data64
    set variable $_data_rows = 8

    if $access($arg0, sizeof(long))
        if $argc > 1
            emit $hexdump($arg0, $arg1 * 0x10 / sizeof(long), 'L')
        else
            emit $hexdump($arg0, $_data_rows * 0x10 / sizeof(long), 'L')
        end
    else
        emit $sprintf("... address %p not available ...\n", $arg0)
    end
end

document show_data32
Dump the memory at the specified address as 32-bit data.
end

document show_data64
Dump the memory at the specified address as 64-bit data.
end

define show_code32
    set variable $_max_instruction = 0x10 - 1
    # FIXME: better way to figure this out per-architecture?

    if $argc > 0
        set variable $pre = $arg0 / 2
        set variable $post = $arg0 / 2 + $arg0 % 2
    else
        set variable $pre = 3
        set variable $post = 4
    end

    emit "\n-=[disassembly]=-\n"
    if $access($pc, 1)
        if $access($pc + -$pre * $_max_instruction, 1)
            eval "x/%di $pc", -$pre
        else
            emit $sprintf("...")
        end

        if $access($pc + +$post * $_max_instruction, 1)
            eval "x/%di $pc", +$post
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

    if $argc > 0
        set variable $pre = $arg0 / 2
        set variable $post = $arg0 / 2 + $arg0 % 2
    else
        set variable $pre = 3
        set variable $post = 4
    end

    emit "\n-=[disassembly]=-\n"
    if $access($pc, 1)
        if $access($pc + -$pre * $_max_instruction, 1)
            eval "x/%di $pc", -$pre
        else
            emit $sprintf("...")
        end
        if $access($pc + +$post * $_max_instruction, 1)
            eval "x/%di $pc", +$post
        else
            x/i $pc
        end
    else
        emit $sprintf("... address %p not available ...\n", $pc)
    end
end

document show_code32
Disassemble the memory at the address specified by the $pc register as 32-bit code.
end

document show_code64
Disassemble the memory at the address specified by the $pc register as 64-bit code.
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
    set variable $_ps   = (long long)((sizeof($ps) > 4)? $ps & 0xffffffffffffffff : $ps & 0xffffffff)
    set variable $_cf   = ($_ps & 0x000001)?  "+CF" : "-CF"
    set variable $_r1   = ($_ps & 0x000002)?  " R1" : ""
    set variable $_pf   = ($_ps & 0x000004)?  "+PF" : "-PF"
    set variable $_r2   = ($_ps & 0x000008)?  " R2" : ""
    set variable $_af   = ($_ps & 0x000010)?  "+AF" : "-AF"
    set variable $_r3   = ($_ps & 0x000020)?  " R3" : ""
    set variable $_zf   = ($_ps & 0x000040)?  "+ZF" : "-ZF"
    set variable $_sf   = ($_ps & 0x000080)?  "+SF" : "-SF"
    set variable $_tf   = ($_ps & 0x000100)?  " TF" : ""
    set variable $_if   = ($_ps & 0x000200)?  "+IF" : "-IF"
    set variable $_df   = ($_ps & 0x000400)?  "+DF" : "-DF"
    set variable $_of   = ($_ps & 0x000800)?  "+OF" : "-OF"
    set variable $_iopl = ($_ps & 0x003000)? $sprintf(" IOPL%d",($_ps&0x3000)>>0x1000) : ""
    set variable $_nt   = ($_ps & 0x004000)?  " NT" : ""
    set variable $_r4   = ($_ps & 0x008000)?  " R4" : ""

    ## eflags
    set variable $_rf   = ($_ps & 0x010000)?  " RF" : ""
    set variable $_vm   = ($_ps & 0x020000)?  " VM" : ""
    set variable $_ac   = ($_ps & 0x040000)?  " AC" : ""
    set variable $_vif  = ($_ps & 0x080000)?  " VIF": ""
    set variable $_vip  = ($_ps & 0x100000)?  " VIP": ""
    set variable $_id   = ($_ps & 0x200000)?  " ID" : ""
    set variable $_ereserved = (($_ps >> 16+6) & 0x3ff)? $sprintf(" R<eflags>=0x%03x", ($_ps >> 16+6) & 0x3ff) : ""

    ## rflags (upper 64-bits are not supported by gdb)
    set variable $_rreserved = (($_ps >> 32) & 0xffffffff)? $sprintf(" R<rflags>=0x%08x", ($_ps >> 32) & 0xffffffff) : ""
    emit $sprintf("[flags: %s %s %s %s %s %s %s %s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s]\n", $_zf, $_sf, $_of, $_cf, $_df, $_pf, $_af, $_if, $_tf, $_nt, $_rf, $_vm, $_ac, $_vif, $_vip, $_id, $_iopl, $_r1, $_r2, $_r3, $_r4, $_ereserved, $_rreserved)
end

document show_flags
Display the contents of the $ps register for the Intel architecture.
end

define here32
    show_regs32
    show_stack32
    if $argc > 0
        show_code32 $arg0
    else
        show_code32
    end
end

define here64
    show_regs64
    show_stack64
    if $argc > 0
        show_code64 $arg0
    else
        show_code64
    end
end

document here32
Show information about the current processor state for the 32-bit Intel architecture.
end

document here64
Show information about the current processor state for the 64-bit Intel architecture.
end

### stepping
define n
    nexti
    if $argc > 0
        here $arg0
    else
        here
    end
end

define s
    stepi
    if $argc > 0
        here $arg0
    else
        here
    end
end

document n
Step over the next instruction and display the current processor state.
end

document s
Step into the next instruction and display the current processor state.
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

document show_regs
Show the register file from the current processor state for the Intel architecture.
end

document show_stack
Dump the memory at the address specified by the $sp register as a stack.
end

document show_code
Show the instructions around the memory address specified by the $pc register.
end

define here
    if $argc > 0
        if sizeof(void*) == 4
            here32 $arg0
        end
        if sizeof(void*) == 8
            here64 $arg0
        end
    else
        if sizeof(void*) == 4
            here32
        end
        if sizeof(void*) == 8
            here64
        end
    end
end

document here
Show information about the current processor state for the Intel architecture.
end

# needs to be defined in order to replace the help command
define h
    if $argc > 0
        here $arg0
    else
        here
    end
end

define hsrc
    # start by displaying some number of frames from the backtrace.
    if $argc > 1
        eval "backtrace %d", ($arg1 < 1)? 1 : $arg1
    else
        backtrace 6
    end

    # if we were given a parameter, then we will use it as the number of lines
    # of code to display from the current address.
    if $argc > 0

        # start by grabbing the current list size to preserve it so that we can
        # temporarily assign a new one and restore it right afterwards.
        python gdb.execute("set ${:s} = {:#x}".format('_gdb_listsize', gdb.parameter('listsize')))

        # now we can temporarily assign a new one, list the specified number of
        # lines from the code, and then restore the original list size.
        eval "set listsize %d", ($arg0 < 1)? 1 : $arg0
        list *$pc
        eval "set listsize %d", $_gdb_listsize

        # last thing to do is to unset the temporary variable that we used.
        set $_gdb_listsize = (void)-1
    else
        list *$pc
    end

    info line
end

document h
Show information about the current processor state for the Intel architecture.

This is an alias for the `here` command.
end

document hsrc
Show information about the source code currently being executed.
end

### shortcuts
define maps
    info proc mappings
end

document maps
Display the segment mappings of the process (inferior) currently running.
end

define cwd
    info proc cwd
end

document cwd
Display the current working directory of the process (inferior) currently running.
end

define segments
    info files
end

document segments
Display the sections and their backing files from the process (inferior) currently running.
end

define tasks
    #maintenance info program-spaces
    if $argc > 0
        info inferiors $arg0
    else
        info inferiors
    end
end

document tasks
Display each of the currently debugged processes (inferior).
end

define threads
    if $argc > 0
        info threads $arg0
    else
        info threads
    end
end

document threads
Display each of the threads from the currently currently debugged process.
end

define symbols
    info variables $arg0
end

document symbols
Display the address and name of each of the symbols matching the specified regular expression.
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

document lvars
Display the local variables in scope of the function currently being executed.
end

document args
Display the arguments used to call the function currently being executed.
end

document vars
Display all of the available variables provided by the debugger.
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

document la
Display the address information for the specified symbol.
end

document ll
Display the line number information for the specified location.
end

document ln
Display information about the specified global or static symbol.
end

define lm
    # gdb's expression evaluation appears pretty limited as i couldn't for the
    # life of me paste string args together with an `eval` loop as described in
    # the documentation. there's also no elseif. so, we use the following nested
    # conditionals so that the wrong number of parameters can be passed to the
    # `select_process_mappings` implementation which will display its help.
    if $argc == 0
        select_process_mappings
    else
        if $argc == 1
            select_process_mappings $arg0
        else
            if $argc == 2
                select_process_mappings $arg0 $arg1
            else
                if $argc == 3
                    select_process_mappings $arg0 $arg1 $arg2
                end
            end
        end
    end
    #progspace = gdb.current_progspace()
    #objfiles = progspace.objfiles()
    #progspace.objfile_for_address($pc)
end

document lm
List the segment mappings for the address space of the currently running process (inferior).
end

define bl
    info breakpoints
end

document bl
List all of the breakpoints that have been defined in the current debugging session.
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

document u
Disassemble forward from the specified address or the address specified by $pc if an address is not provided.
end

# disassemble
define dis
    if $argc > 0
        disassemble $arg0
    else
        disassemble
    end
end

document dis
Disassemble forward from the specified address or the current location if an address is not provided.
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

document dc
Dump the specified address as words defined by the processor architecture.
end

### breakpoints with wildcards
python
class uses_an_address(workspace):
    @staticmethod
    def escape_address(string):
        addr = string
        if addr.startswith('0x'):
            escaped_addr = "*({})".format(addr)

        # not sure if this is the right way to escape a symbol in gdb-speak
        else:
            escaped = addr.replace('\\', '\\\\').replace("\"", "{:s}\"".format('\\'))
            quoted_addr = "\"{:s}\"".format(escaped)
            escaped_addr = "'{:s}'".format(quoted_addr)
        return escaped_addr

class breakpoints(uses_an_address):
    commands = set()

    @commands.add
    class bc(command):
        '''Delete the specified breakpoint.'''
        COMMAND = gdb.COMMAND_BREAKPOINTS
        def invoke(self, s, from_tty):
            if s == '*':
                gdb.execute("delete breakpoints")
                return
            gdb.execute("delete breakpoints " + s)

    @commands.add
    class bd(command):
        '''Disable the specified breakpoint.'''
        COMMAND = gdb.COMMAND_BREAKPOINTS
        def invoke(self, s, from_tty):
            if s == '*':
                gdb.execute("disable breakpoints")
                return
            gdb.execute("disable breakpoints " + s)

    @commands.add
    class be(command):
        '''Enable the specified breakpoint.'''
        COMMAND = gdb.COMMAND_BREAKPOINTS
        def invoke(self, s, from_tty):
            if s == '*':
                gdb.execute("enable breakpoints")
                return
            gdb.execute("enable breakpoints " + s)

    @commands.add
    class ba(command):
        '''Break on access to the specified memory address.'''
        COMMAND, COMPLETE = gdb.COMMAND_BREAKPOINTS, gdb.COMPLETE_EXPRESSION
        def invoke(self, s, from_tty):
            args = gdb.string_to_argv(s)
            addr = args.pop(0)
            escaped_addr = self.workspace.escape_address(addr)
            if len(args) > 0 and args[0].startswith('~'):
                t=args.pop(0)[1:]
                thread = '' if t == '*' else (' thread %s'% t)
            else:
                th = gdb.selected_thread()
                thread = '' if th is None else ' thread %d'% th.num
            rest = (' if '+' '.join(args)) if len(args) > 0 else ''
            gdb.execute("hbreak {:s}".format(escaped_addr) + thread + rest)

    @commands.add
    class bp(command):
        '''Break at the execution of the specified memory address.'''
        COMMAND, COMPLETE = gdb.COMMAND_BREAKPOINTS, gdb.COMPLETE_LOCATION
        def invoke(self, s, from_tty):
            args = gdb.string_to_argv(s)    # FIXME: this stupid function removes quotes from all the arguments
            addr = args.pop(0)
            escaped_addr = self.workspace.escape_address(addr)
            if len(args) > 0 and args[0].startswith('~'):
                t=args.pop(0)[1:]
                thread = '' if t == '*' else (' thread %s'% t)
            else:
                th = gdb.selected_thread()
                thread = '' if th is None else ' thread %d'% th.num
            rest = (' if '+' '.join(args)) if len(args) > 0 else ''
            gdb.execute("break {:s}".format(escaped_addr) + thread + rest)
    EXPORTS = commands

class running(uses_an_address):
    class go(command):
        '''Run or continue execution until encountering the specified address.'''
        COMMAND, COMPLETE = gdb.COMMAND_RUNNING, gdb.COMPLETE_LOCATION
        def invoke(self, s, from_tty):
            args = gdb.string_to_argv(s)
            if not args:
                return gdb.execute("run" if gdb.selected_thread() is None else "continue")
            addr = args.pop(0)
            if addr.startswith('0x'):
                escaped_addr = "*({})".format(addr)
            else:   # not sure if this is the right way to escape a symbol in gdb-speak
                escaped = addr.replace('\\', '\\\\').replace("\"", "{:s}\"".format('\\'))
                quoted_addr = "\"{:s}\"".format(escaped)
                escaped_addr = "'{:s}'".format(quoted_addr)
            if len(args) > 0 and args[0].startswith('~'):
                t=args.pop(0)[1:]
                thread = '' if t == '*' else (' thread %s'% t)
            else:
                th = gdb.selected_thread()
                thread = '' if th is None else ' thread %d'% th.num
            rest = (' if '+' '.join(args)) if len(args) > 0 else ''
            gdb.execute("tbreak {:s}".format(escaped_addr) + thread + rest)
            gdb.execute("run" if gdb.selected_thread() is None else "continue")
            gdb.execute("here")
    EXPORTS = {go}

breakpoints.register(), running.register()
end

# thanks, claude.
python
class StepUntil(workspace):
    commands = functions = set()

    # Mnemonics that indicate a call. Architecture-spanning set; extend as needed.
    CALL_MNEMONICS = (
        # x86 / x86-64
        "call", "callq", "lcall",
        # ARM / AArch64
        "bl", "blx", "blr",
        # MIPS
        "jal", "jalr", "bal",
        # PowerPC
        "bctrl", "blrl",
        # RISC-V (jal/jalr with link register; pseudo "call" also emitted by some disassemblers)
    )

    # Branch/jump mnemonics. We treat anything that can redirect control flow
    # (conditional or unconditional) as a branch. Calls are a subset of branches,
    # but stepbranch stops on plain branches too.
    BRANCH_PREFIXES = (
        # x86 / x86-64: jmp, je, jne, jg, jl, jbe, jae, loop, etc.
        "jmp", "j",          # 'j' prefix covers jcc family; filtered below
        "loop",
        # ARM / AArch64
        "b", "bl", "blx", "br", "blr", "cbz", "cbnz", "tbz", "tbnz",
        # MIPS / PPC / RISC-V
        "beq", "bne", "bgt", "blt", "bge", "ble", "bal",
        "bctr", "bctrl", "bx",
    )

    # Return / function-exit mnemonics.
    RETURN_MNEMONICS = (
        # x86 / x86-64
        "ret", "retq", "retf", "lret", "iret", "iretq", "iretd", "sysret", "sysexit",
        # ARM (AArch32 uses 'bx lr' or pop pc; AArch64 has a dedicated 'ret')
        "ret", "eret",
        # MIPS — return is 'jr $ra'; we special-case below since 'jr' alone isn't
        #        always a return. Listed for completeness via the predicate.
        # PowerPC
        "blr", "rfi",
        # RISC-V — return is 'ret' (pseudo for 'jalr x0, x1, 0')
        # SPARC
        "retl", "return",
    )

    @classmethod
    def current_mnemonic(cls):
        """Return the lowercased mnemonic of the instruction at $pc, or None."""
        frame = gdb.selected_frame()
        pc = frame.pc()
        arch = frame.architecture()
        insn = arch.disassemble(pc)[0]
        text = insn["asm"].strip()
        if not text:
            return None
        # The mnemonic is the first whitespace-delimited token.
        return text.split()[0].lower()

    @classmethod
    def current_insn_text(cls):
        """Return the full disassembled text of the instruction at $pc, or ''."""
        frame = gdb.selected_frame()
        pc = frame.pc()
        insn = frame.architecture().disassemble(pc)[0]
        return insn["asm"].strip()


    @classmethod
    def is_call(cls, mnemonic):
        if mnemonic is None:
            return False
        return mnemonic in cls.CALL_MNEMONICS


    @classmethod
    def is_branch(cls, mnemonic):
        """True for any control-flow redirect (branches, jumps, and calls)."""
        if mnemonic is None:
            return False
        if cls.is_call(mnemonic):
            return True
        # Direct membership check first.
        if mnemonic in cls.BRANCH_PREFIXES:
            return True
        # x86 conditional jumps: je, jne, jg, jle, jae, jnz, ... all start with 'j'
        # but exclude 'jmp' (already covered) — every 'j*' on x86 is a branch.
        if mnemonic.startswith("j"):
            return True
        # ARM conditional branches like b.eq, b.ne, b.gt ...
        if mnemonic.startswith("b.") or mnemonic == "b":
            return True
        return False


    @classmethod
    def is_return(cls, mnemonic):
        """True for instructions that return from the current function.

        Note: 'ret' on most ISAs is unambiguous. MIPS/AArch32 returns are
        register-indirect jumps ('jr $ra', 'bx lr', 'mov pc, lr', 'pop {..,pc}'),
        which we detect from the full instruction text rather than the mnemonic
        alone — see the text-based fallback below.
        """
        if mnemonic is None:
            return False
        return mnemonic in cls.RETURN_MNEMONICS


    @classmethod
    def is_return_insn(cls, mnemonic, full_text):
        """Combine mnemonic check with text heuristics for register-indirect
        returns that share a mnemonic with ordinary jumps."""
        if cls.is_return(mnemonic):
            return True
        t = full_text.lower()
        # MIPS: jr $ra
        if mnemonic == "jr" and ("$ra" in t or "ra" == t.split()[-1].lstrip("$")):
            return True
        # AArch32: bx lr / mov pc, lr
        if mnemonic == "bx" and "lr" in t:
            return True
        if mnemonic in ("mov", "movs") and t.replace(" ", "").endswith("pc,lr"):
            return True
        # ARM/Thumb: pop {..., pc}  (popping into PC is a return)
        if mnemonic in ("pop", "ldm", "ldmia", "ldmfd") and "pc" in t:
            return True
        return False

    class StepUntil(command):
        """Base: single-step instructions until a predicate is true.

        Stops *on* the matching instruction (i.e. $pc points at the
        call/branch/ret, which has not yet executed), so you can inspect
        operands, return values, and the stack before stepping into it.
        """
        command = gdb.COMMAND_RUNNING

        def _matches(self):
            mnem = StepUntil.current_mnemonic()
            text = StepUntil.current_insn_text()
            return self._predicate(mnem, text)

        def invoke(self, arg, from_tty):
            # Optional safety cap so a runaway loop doesn't hang the session.
            # Pass an integer argument to override (e.g. `stepcall 1000000`).
            max_steps = 1024
            if arg.strip():
                try:
                    max_steps = int(arg.strip(), 0)
                except ValueError:
                    raise gdb.GdbError("argument must be an integer step cap")

            # If we're already sitting on a matching instruction, step off it first
            # so the command makes forward progress on repeated invocations.
            if self._matches():
                gdb.execute("stepi", to_string=True)

            steps = 0
            while steps < max_steps:
                if self._matches():
                    frame = gdb.selected_frame()
                    pc = frame.pc()
                    insn = StepUntil.current_insn_text()
                    gdb.write(f"Stopped at {self._label}: 0x{pc:x}\t{insn}\n")
                    gdb.execute("x/i $pc")
                    return
                gdb.execute("stepi", to_string=True)
                steps += 1

            raise gdb.GdbError(
                f"step cap ({max_steps}) reached without finding a {self._label}"
            )

    class tillcall(StepUntil):
        '''Continue execution until a call instruction is encountered.'''
        _predicate = staticmethod(lambda m, t: StepUntil.is_call(m))
        _label = 'call'

    class tillbranch(StepUntil):
        '''Continue execution until a branch instruction is encountered.'''
        _predicate = staticmethod(lambda m, t: StepUntil.is_branch(m))
        _label = 'branch'

    class tillreturn(StepUntil):
        '''Continue execution until a return instruction is encountered.'''
        _predicate = staticmethod(lambda m, t: StepUntil.is_return_insn(m, t))
        _label = 'return'

    @commands.add
    class pc(tillcall): pass
    @commands.add
    class ph(tillbranch): pass
    @commands.add
    class pt(tillreturn): pass

    @commands.add
    class tillcall(tillcall): pass
    @commands.add
    class tillbranch(tillbranch): pass
    @commands.add
    class tillreturn(tillreturn): pass

    EXPORTS = {item for item in itertools.chain(commands, functions)}

StepUntil.register()

import operator, itertools, functools, math
class IntelDisassembler(workspace):
    """
    Backward disassembler for GDB (32-bit and 64-bit Intel).

    Usage:
        lengths = IntelDisassembler.backwardlength(address, count=5)
        chains = IntelDisassembler.candidates(address, depth=3)

        for score, chain in IntelDisassembler.candidates(address, depth=3):
            ...
        IntelDisassembler.mode = 32
    """

    # Set to 32 or 64 to override auto-detection
    mode = None

    # Maximum instruction size
    maximum = 15

    # --- One-byte opcode map: (has_modrm, imm_kind) ----------------------

    ONEBYTE = {}

    # ALU families: ADD, OR, ADC, SBB, AND, SUB, XOR, CMP
    for _base in (0x00, 0x08, 0x10, 0x18, 0x20, 0x28, 0x30, 0x38):
        for _i, _kind in ((0, 'none'), (1, 'none'), (2, 'none'), (3, 'none'),
                          (4, 'ib'), (5, 'iz')):
            ONEBYTE[_base + _i] = (_i < 4, _kind)
    del _base, _i, _kind

    # INC/DEC r (32-bit), PUSH/POP r, PUSHA, POPA
    for _op in range(0x40, 0x62):
        ONEBYTE[_op] = (False, 'none')

    ONEBYTE[0x68] = (False, 'iz')
    ONEBYTE[0x69] = (True, 'iz')
    ONEBYTE[0x6A] = (False, 'ib')
    ONEBYTE[0x6B] = (True, 'ib')

    # Jcc rel8
    for _op in range(0x70, 0x80):
        ONEBYTE[_op] = (False, 'ib')

    ONEBYTE[0x80] = (True, 'ib')
    ONEBYTE[0x81] = (True, 'iz')
    ONEBYTE[0x83] = (True, 'ib')

    # TEST, XCHG, MOV variants, MOV sreg, LEA, POP r/m
    for _op in range(0x84, 0x90):
        ONEBYTE[_op] = (True, 'none')

    # NOP, XCHG eAX/r
    for _op in range(0x90, 0x98):
        ONEBYTE[_op] = (False, 'none')

    # CWDE, CDQ, PUSHF, POPF, SAHF, LAHF
    for _op in [0x98, 0x99, 0x9C, 0x9D, 0x9E, 0x9F]:
        ONEBYTE[_op] = (False, 'none')

    # MOV AL/eAX moffs variants
    for _op in [0xA0, 0xA2]:
        ONEBYTE[_op] = (False, 'ib')
    for _op in [0xA1, 0xA3]:
        ONEBYTE[_op] = (False, 'iz')

    ONEBYTE[0xA8] = (False, 'ib')
    ONEBYTE[0xA9] = (False, 'iz')

    # MOV r8, imm8
    for _op in range(0xB0, 0xB8):
        ONEBYTE[_op] = (False, 'ib')

    # MOV r, imm
    for _op in range(0xB8, 0xC0):
        ONEBYTE[_op] = (False, 'iq')

    # Shift r/m, imm8
    for _op in [0xC0, 0xC1]:
        ONEBYTE[_op] = (True, 'ib')

    ONEBYTE[0xC2] = (False, 'iw')
    ONEBYTE[0xC6] = (True, 'ib')
    ONEBYTE[0xC7] = (True, 'iz')
    ONEBYTE[0xCD] = (False, 'ib')

    # RET, ENTER, LEAVE, INT3, IRET
    for _op in [0xC3, 0xC8, 0xC9, 0xCC, 0xCF]:
        ONEBYTE[_op] = (False, 'none')

    # Shift/rotate r/m by 1 or CL
    for _op in range(0xD0, 0xD4):
        ONEBYTE[_op] = (True, 'none')

    # LOOPNE, LOOPE, LOOP, JECXZ, IN imm8, OUT imm8
    for _op in range(0xE0, 0xE8):
        ONEBYTE[_op] = (False, 'ib')

    # CALL rel32, JMP rel32
    for _op in [0xE8, 0xE9]:
        ONEBYTE[_op] = (False, 'iz')

    ONEBYTE[0xEB] = (False, 'ib')

    # IN/OUT via DX
    for _op in range(0xEC, 0xF0):
        ONEBYTE[_op] = (False, 'none')

    # Group 3 — imm depends on ModR/M reg field
    ONEBYTE[0xF6] = ('grp3_8', None)
    ONEBYTE[0xF7] = ('grp3_v', None)

    # ICEBP, HLT, CMC, CLC, STC, CLI, STI, CLD, STD
    for _op in [0xF1, 0xF4, 0xF5, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD]:
        ONEBYTE[_op] = (False, 'none')

    # INC/DEC r/m, indirect CALL/JMP/PUSH
    for _op in [0xFE, 0xFF]:
        ONEBYTE[_op] = (True, 'none')

    del _op

    # --- Two-byte opcode map (0F xx) --------------------------------------

    TWOBYTE = {}

    # Jcc rel32
    for _op in range(0x80, 0x90):
        TWOBYTE[_op] = (False, 'iz')

    # SETcc r/m8
    for _op in range(0x90, 0xA0):
        TWOBYTE[_op] = (True, 'none')

    # PUSH/POP FS/GS, CPUID
    for _op in [0xA0, 0xA1, 0xA2, 0xA8, 0xA9]:
        TWOBYTE[_op] = (False, 'none')

    # BT, BTS, BTR, BTC, CMPXCHG, MOVZX, MOVSX, BSF, BSR, XADD, IMUL
    for _op in [0xA3, 0xAB, 0xAF, 0xB0, 0xB1, 0xB3,
                0xB6, 0xB7, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF,
                0xC0, 0xC1]:
        TWOBYTE[_op] = (True, 'none')

    # BT/BTS/BTR/BTC r/m, imm8
    TWOBYTE[0xBA] = (True, 'ib')

    # BSWAP r
    for _op in range(0xC8, 0xD0):
        TWOBYTE[_op] = (False, 'none')

    del _op

    # --- Other constants --------------------------------------------------

    LEGACY = frozenset([0xF0, 0xF2, 0xF3, 0x2E, 0x36, 0x3E, 0x26, 0x64, 0x65])

    BRANCH_REL32 = frozenset([0xE8, 0xE9])
    BRANCH_REL8  = frozenset([0xEB] + list(range(0x70, 0x80)))

    # --- Integer decoding -------------------------------------------------

    @classmethod
    def decode_unsigned(cls, data, offset, size):
        """Decode a little-endian unsigned integer from bytearray."""
        bytes = bytearray(data[offset : offset + size])
        Faggregate = lambda carry, octet: carry * 0x100 + octet
        return functools.reduce(Faggregate, bytes[::-1], 0)

    @classmethod
    def decode_signed(cls, data, offset, size):
        """Decode a little-endian signed integer from bytearray."""
        unsigned = cls.decode_unsigned(data, offset, size)
        sign_bit = pow(2, 8 * size - 1)
        if unsigned & sign_bit:
            return unsigned - 2 * sign_bit
        return unsigned

    @classmethod
    def _read_signed(cls, data, offset, size):
        return None if offset is None or size == 0 else cls.decode_signed(data, offset, size)

    # --- Mode detection ---------------------------------------------------

    @classmethod
    def get_mode(cls):
        try:
            res = getattr(cls, 'mode', None)
            if res is None:
                raise AttributeError
            return res

        except AttributeError:
            pass

        # ask gdb for the architecture word size
        try:
            architecture = gdb.selected_frame().architecture()
            name = architecture.name().lower()
            if '64' in name or 'amd64' in name:
                return 64
            return 32

        except (gdb.error, RuntimeError):
            pass

        # ask python for the architecture word size
        return 64 if math.log2(2 * sys.maxsize) > 32 else 32

    # --- Operand extraction -----------------------------------------------

    @classmethod
    def immediate(cls, kind, opsize16, rex_w):
        if kind == 'none': return 0
        if kind == 'ib':   return 1
        if kind == 'iw':   return 2
        if kind == 'iz':   return 2 if opsize16 else 4
        if kind == 'iv':   return 2 if opsize16 else (8 if rex_w else 4)
        if kind == 'iq':   return 8 if rex_w else (2 if opsize16 else 4)
        return 0

    @classmethod
    def operands(cls, data, start, length, mode=None):
        if mode is None:
            mode = cls.get_mode()

        p = start
        end = start + length
        opsize16 = False
        rex_w = False

        while p < end:
            b = data[p]
            if b in cls.LEGACY:
                p += 1
            elif b == 0x66:
                opsize16 = True; p += 1
            elif b == 0x67:
                p += 1
            elif mode == 64 and 0x40 <= b <= 0x4F:
                rex_w = bool(b & 8); p += 1
            else:
                break

        if p >= end:
            return None

        opcode = data[p]; p += 1
        opcode_map = 1

        if opcode == 0x0F:
            if p >= end:
                return None
            opcode = data[p]; p += 1
            opcode_map = 2
            if opcode in (0x38, 0x3A):
                return None
            info = cls.TWOBYTE.get(opcode)
        else:
            info = cls.ONEBYTE.get(opcode)

        if info is None:
            return None

        has_modrm, imm_kind = info

        if has_modrm in ('grp3_8', 'grp3_v'):
            if p >= end:
                return None
            reg = (data[p] >> 3) & 7
            if reg in (0, 1):
                imm_kind = 'ib' if has_modrm == 'grp3_8' else 'iz'
            else:
                imm_kind = 'none'
            has_modrm = True

        disp_off = None
        disp_size = 0
        rip_relative = False

        if has_modrm:
            if p >= end:
                return None
            modrm = data[p]; p += 1
            mod = (modrm >> 6) & 3
            rm = modrm & 7
            if mod != 3:
                if rm == 4:
                    if p >= end:
                        return None
                    sib = data[p]; p += 1
                    if mod == 0 and (sib & 7) == 5:
                        disp_size = 4
                if mod == 0 and rm == 5:
                    disp_size = 4
                    if mode == 64:
                        rip_relative = True
                elif mod == 1:
                    disp_size = 1
                elif mod == 2:
                    disp_size = 4
            if disp_size:
                disp_off = p
                p += disp_size

        imm_sz = cls.immediate(imm_kind, opsize16, rex_w)
        imm_off = None
        if imm_sz:
            imm_off = p
            p += imm_sz

        if p != end:
            return None

        return {
            'opcode': opcode,
            'opcode_map': opcode_map,
            'rex_w': rex_w,
            'opsize16': opsize16,
            'disp_off': disp_off,
            'disp_size': disp_size,
            'imm_off': imm_off,
            'imm_size': imm_sz,
            'rip_relative': rip_relative,
        }

    # --- Scoring ----------------------------------------------------------

    @classmethod
    def score(cls, ops, data, address, length):
        s = 0.0
        end = address + length

        def peek(address, inferior=gdb.selected_inferior()):
            try: return bytearray(Memory.read(inferior, address, 1))
            except gdb.MemoryError: return None

        if ops['rip_relative']:
            disp = cls._read_signed(data, ops['disp_off'], ops['disp_size'])
            if disp is not None:
                target = end + disp
                if peek(target) is not None:
                    s += 1.0
                else:
                    s -= 2.0

        if not ops['rip_relative'] and ops['disp_size'] == 4:
            disp = cls._read_signed(data, ops['disp_off'], ops['disp_size'])
            if disp is not None:
                target = disp & 0xFFFFFFFF
                if peek(target) is not None:
                    s += 0.5
                else:
                    s -= 0.5

        imm = cls._read_signed(data, ops['imm_off'], ops['imm_size'])

        if ops['opcode_map'] == 1 and ops['opcode'] in cls.BRANCH_REL32 and imm is not None:
            target = end + imm
            if peek(target) is not None:
                s += 2.0
            else:
                s -= 3.0
        elif ops['opcode_map'] == 2 and 0x80 <= ops['opcode'] < 0x90 and imm is not None:
            target = end + imm
            if peek(target) is not None:
                s += 1.0
            else:
                s -= 3.0
        elif ops['opcode_map'] == 1 and ops['opcode'] in cls.BRANCH_REL8 and imm is not None:
            target = end + imm
            if peek(target) is None:
                s -= 1.0

        return s

    # --- Single-step backward candidates ----------------------------------

    @classmethod
    def length(cls, address):
        '''Return the length of the instruction at the specified `address`.'''
        try:
            architecture = gdb.selected_frame().architecture()
            [instruction] = architecture.disassemble(address, count=1)
            res = instruction['length']
        except (gdb.error, gdb.MemoryError, RuntimeError, ValueError):
            res = None
        return res

    @classmethod
    def candidate(cls, address):
        '''Yield (score, ea, length) for each valid candidate ending at `address`.'''
        inferior, mode = gdb.selected_inferior(), cls.get_mode()
        for k in range(1, cls.maximum + 1):
            ea = address - k
            L = cls.length(ea)
            if L != k:
                continue

            bytes = Memory.read(inferior, ea, k)
            if bytes is None:
                continue

            data = bytearray(bytes)
            ops = cls.operands(data, 0, k, mode)

            if ops is None:
                yield (0.0, ea, k)

            else:
                yield (cls.score(ops, data, ea, k), ea, k)
            continue
        return

    # --- Block-level candidate chains (generator) -------------------------

    @classmethod
    def candidates(cls, address, depth=1):
        """Generator yielding (score, chain) tuples incrementally.

        Each chain is [(ea, length), ...] in forward order.
        """
        if depth < 1:
            return

        if depth == 1:
            for score, ea, length in cls.candidate(address):
                yield (score, [(ea, length)])
            return

        for tail_score, ea, length in cls.candidate(address):
            predecessor = False
            for prefix_score, prefix_chain in cls.candidates(ea, depth - 1):
                predecessor = True
                yield (prefix_score + tail_score, prefix_chain + [(ea, length)])
            if not predecessor:
                yield (tail_score, [(ea, length)])
            continue
        return

    # --- Sorted wrapper ---------------------------------------------------

    @classmethod
    def results(cls, address, depth=1):
        """Collect all candidate chains and return them sorted best-first.

        Returns list of (score, [(address, length), ...]).
        """
        iterable = cls.candidates(address, depth)
        Fkey = lambda pair: (lambda score, item: -1. * score)(*pair)
        return sorted(iterable, key=Fkey)

    # --- Convenience: backward length -------------------------------------

    @classmethod
    def get_forward_length(cls, address, count=1):
        """Return instruction lengths for `count` instructions ending at `address`.

        Returns a list of lengths in forward order.
        """
        ea, chain = int(address), []
        while count > 0:
            length = cls.length(ea)
            chain.append((ea, length))
            ea, count = ea + length, count - 1
        return [length for _, length in chain]

    @classmethod
    def get_backward_length(cls, address, count=1):
        """Return instruction lengths for `count` instructions ending at `address`, using the best-scoring chain.

        Returns a list of lengths in forward order.
        """
        ea = int(address)
        chains = cls.results(ea, depth=count)
        if not chains:
            return []
        # grab the one with the most instructions
        iterable = itertools.groupby(chains, key=operator.itemgetter(0))
        score, grouped = next(iterable, (0.0, []))
        candidates = [chain for score, chain in grouped]
        chain = max(candidates, key=len)
        return [length for _, length in chain]

    @classmethod
    def disassemble_forward(cls, address, count=10, mark={}, hexdump=False):
        iterable = mark if isinstance(mark, (list, set, tuple, dict)) else {mark}
        signs = {ea : sign for ea, sign in iterable} if isinstance(iterable, dict) else {ea : '=>' for ea in iterable}
        signwidth = max(len("{:s} ".format(sign)) for _, sign in signs.items()) if signs else 0

        frame, inferior = gdb.selected_frame(), gdb.selected_inferior()
        architecture = frame.architecture()

        instructions = architecture.disassemble(address, count=count)
        maximum = max(instruction['addr'] for instruction in instructions) if instructions else 0
        width = len("{:#x}".format(maximum))

        chain = [(instruction['addr'], instruction['length']) for instruction in instructions]
        for ea, length in chain:
            try: [info] = architecture.disassemble(ea, count=1)
            except (gdb.error, gdb.MemoryError, RuntimeError, ValueError): info = None
            asm_column = '???' if info is None else info['asm']

            marker_column = "{:<{:d}s}".format(signs.get(ea, ''), signwidth)
            address_column = "{:<#{:d}x}".format(ea, width)

            if hexdump:
                try:
                    raw = Memory.read(inferior, ea, length)
                    hexrow = ' '.join(map("{:02x}".format, bytearray(raw)))
                except gdb.MemoryError:
                    hexrow = '??'
                hex_column = "{:<{:d}s}".format(hexrow, 45)
                gdb.write("{:s}{:s} {:s} {:s}\n".format(marker_column, address_column, hex_column, asm_column))
            else:
                gdb.write("{:s}{:s}    {:s}\n".format(marker_column, address_column, asm_column))
            continue
        return

    @classmethod
    def disassemble_backward(cls, address, count=10, mark={}, hexdump=False):
        """Disassemble backwards and print results."""
        iterable = mark if isinstance(mark, (list, set, tuple, dict)) else {mark}
        signs = {ea : sign for ea, sign in iterable} if isinstance(iterable, dict) else {ea : '=>' for ea in iterable}
        signwidth = max(len("{:s} ".format(sign)) for _, sign in signs.items()) if signs else 0

        frame, inferior = gdb.selected_frame(), gdb.selected_inferior()
        architecture = frame.architecture()

        chains = cls.results(address, depth=count)
        if not chains:
            return gdb.write('(no results)\n')

        _, chain = chains[0]
        maximum = max(int(ea) for ea, _ in chain) if chain else 0
        width = len("{:#x}".format(int(maximum)))

        for ea, length in chain:
            try: [info] = architecture.disassemble(ea, count=1)
            except (gdb.error, gdb.MemoryError, RuntimeError, ValueError): info = None
            asm_column = '???' if info is None else info['asm']

            marker_column = "{:<{:d}s}".format(signs.get(ea, ''), signwidth)
            address_column = "{:<#{:d}x}".format(ea, width)

            if hexdump:
                try:
                    raw = Memory.read(inferior, ea, length)
                    hexrow = ' '.join(map("{:02x}".format, bytearray(raw)))
                except gdb.MemoryError:
                    hexrow = '??'
                hex_column = "{:<{:d}s}".format(hexrow, 45)
                gdb.write("{:s}{:s} {:s} {:s}\n".format(marker_column, address_column, hex_column, asm_column))
            else:
                gdb.write("{:s}{:s}    {:s}\n".format(marker_column, address_column, asm_column))
            continue
        return

    commands = functions = set()

    @commands.add
    class forwarddisplay(command):
        '''Disassemble instructions from the specified address and display them.'''
        KEYWORD = 'disassemble_forwards'
        COMMAND, COMPLETE = gdb.COMMAND_USER, gdb.COMPLETE_LOCATION

        def invoke(self, string, from_tty, count=10):
            ea = int(evaluate_address(string))
            IntelDisassembler.disassemble_forward(ea, count=count, mark=ea, hexdump=True)
            gdb.flush()

    @commands.add
    class backwarddisplay(command):
        '''Disassemble instructions backwards from the specified address and display them.'''
        KEYWORD = 'disassemble_backwards'
        COMMAND, COMPLETE = gdb.COMMAND_USER, gdb.COMPLETE_LOCATION

        def invoke(self, string, from_tty, count=10):
            ea = int(evaluate_address(string))
            IntelDisassembler.disassemble_backward(ea, count=count, mark=ea, hexdump=True)
            gdb.flush()

    @functions.add
    class forwardlength(function):
        '''Return the total length of the specified number of instructions from the specified address.'''
        def invoke(self, *args):
            [address, count] = args if len(args) == 2 else itertools.chain(args, [1]) if len(args) == 1 else [gdb.parse_and_eval('$pc'), 1] if not args else args
            candidates = IntelDisassembler.get_forward_length(int(address), count)
            return sum(candidates)

    @functions.add
    class backwardlength(function):
        '''Return the total length of the specified number of instructions backwards from the specified address.'''
        def invoke(self, *args):
            [address, count] = args if len(args) == 2 else itertools.chain(args, [1]) if len(args) == 1 else [gdb.parse_and_eval('$pc'), 1] if not args else args
            candidates = IntelDisassembler.get_backward_length(int(address), count)
            return sum(candidates)

    EXPORTS = {item for item in itertools.chain(commands, functions)}

IntelDisassembler.register()
end

### defaults
set debuginfod enabled off

## aliases
alias -- g = go
alias -- h32 = here32
alias -- h64 = here64
alias -- ps = info inferiors

# clause stuff
alias -- tcall = tillcall
alias -- tbranch = tillbranch
alias -- treturn = tillreturn

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

## catchpoints
catch exec
disable breakpoint $bpnum
catch fork
disable breakpoint $bpnum
catch vfork
disable breakpoint $bpnum
tbreak main

## options
set stop-on-solib-events 0
set follow-fork-mode parent
set detach-on-fork on
set input-radix 0x10
set output-radix 0x10
#set width unlimited
#set height unlimited
set max-value-size unlimited
set debuginfod enabled off
#set disassemble-next-line on
set pagination off

set dump-excluded-mappings on
set multiple-symbols all
set debug threads off
set debug entry-values 0
set debug skip on

set ada print-signatures on
set guile print-stack full
set python dont-write-bytecode on
set python print-stack full

set history save on
set history size 131072
set history expansion on
set history filename ~/.gdb_history

set print array-indexes on
set print asm-demangle on
set print demangle on
set print finish on
set print object on
set print type hex on
set print vtbl on
set print inferior-events on
set print thread-events on
set print address on
set print symbol on
set print symbol-filename on
set print array on
set print frame-info location-and-address
set print repeats 16
set print max-depth 16
set print memory-tag-violations on
set print pretty on

set max-completions 32

## script-related
add-auto-load-safe-path .

## tui
set tui border-kind ascii
set tui border-mode half
set tui active-border-mode normal
set tui mouse-events off

tui new-layout default {-horizontal src 1 asm 1} 2 status 0 cmd 1
tui layout default
tui window height src 16
tui focus cmd
tui disable

### utility scripts
#guile ((lambda (script) (if (file-exists? script) (execute (format #f "source ~s" script) #t #t))) "/usr/local/lib/python2.7/dist-packages/exploitable-1.32-py2.7.egg/exploitable/exploitable.py")
#guile ((lambda (script) (if (file-exists? script) (execute (format #f "source ~s" script) #t #t))) "/usr/share/doc/python2.7/gdbinit")
#guile ((lambda (script) (if (file-exists? script) (execute (format #f "source ~s" script) #t #t))) "/usr/share/doc/python3-devel/gdbinit")

## python stuff
#python (lambda os, filename: os.path.exists(filename) and gdb.execute("source {:s}".format(filename)))(__import__('os.path'), "/usr/share/doc/python2.7/gdbinit")
#python (lambda os, filename: os.path.exists(filename) and gdb.execute("source {:s}".format(filename)))(__import__('os.path'), "/usr/local/lib/python2.7/dist-packages/exploitable-1.32-py2.7.egg/exploitable/exploitable.py")
python (lambda os, filename: os.path.exists(filename) and gdb.execute("source {:s}".format(filename)))(__import__('os.path'), "/usr/share/doc/python3-devel/gdbinit")

## in case "add-auto-load-safe-path" doesn't execute ".gdbinit".
#python (lambda os, filename: os.path.dirname(os.path.abspath(filename)) != os.path.abspath(os.path.expanduser("~")) and os.path.exists(filename) and gdb.execute("source {:s}".format(filename)))(__import__('os.path'), "./.gdbinit")
python (lambda os, filename: os.path.exists(filename) and gdb.execute("source {:s}".format(filename)))(__import__('os.path'), __import__('os.path').path.expanduser("~/.gdbinit.local"))
