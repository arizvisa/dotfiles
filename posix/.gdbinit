python import operator,itertools,functools,subprocess

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
        snapshot = cls.depth(2)
        [current, parent] = (frame for frame in snapshot)
        names = {name for name, value in parent.f_locals.items() if id(value) == id(cls)}
        [ parent.f_locals.pop(name) for name in names ]
        names = {name for name, value in parent.f_globals.items() if id(value) == id(cls)}
        [ parent.f_globals.pop(name) for name in names ]
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
class sizeof(function):
    def invoke(self, value):
        try:
            type = gdb.lookup_type(value.string())
        except gdb.error:
            type = value.type
        return type.sizeof

class sprintf(function):
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
execute(),emit(),typeof(),sizeof(),clip(),sprintf()

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

class wat(command):
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
    @classmethod
    def mappings(cls):
        mappings = gdb.execute('info proc mappings', False, True)
        rows = mappings.strip().split('\n')
        iterable = (index for index, row in enumerate(rows) if row.lstrip().startswith('0x'))
        index = next(iterable, 0)
        headers = rows[:index][-1].rsplit(None, 4)
        iterable = itertools.chain(filter(None, headers[:1][0].rsplit('  ')), headers[1:])
        fields = [header.strip() for header in iterable]
        if any(name not in fields for name in cls.expected_field_names):
            gdb.write("The expected field names ({!s}) were changed by gdb to {!s}".format(cls.expected_field_names, fields))
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
        permissions = "{:{:d}s}".format(fields['Perms'], columns['Perms'])
        filename = "{:{:d}s}".format(fields.get(cls.expected_field_names[-1], ''), columns.get(cls.expected_field_names[-1], 0))
        #return "{:s} {:>{:d}s} {:{:d}s}".format(location, fields['Perms'], columns['Perms'], fields.get('objfile', ''), columns['objfile'])
        return ' '.join([location, "<{:s}>".format(permissions), filename])

    @commands.add
    class select(command):
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

    @functions.add
    class baseaddress(function):
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

        def invoke(self, parameter):
            integerish = {gdb.TYPE_CODE_PTR, gdb.TYPE_CODE_INT}
            if parameter.type.is_string_like:
                return self.by_string(parameter.string())
            elif parameter.type.is_scalar and parameter.type.code in integerish:
                return self.by_address(int(parameter))
            return self.by_reference(parameter)

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

define show_code32
    set variable $_max_instruction = 0x10 - 1
    # FIXME: better way to figure this out per-architecture?

    if $arg0 > 0
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

# needs to be defined in order to replace the help command
define h
    if $argc > 0
        here $arg0
    else
        here
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
        COMMAND = gdb.COMMAND_BREAKPOINTS
        def invoke(self, s, from_tty):
            if s == '*':
                gdb.execute("delete breakpoints")
                return
            gdb.execute("delete breakpoints " + s)

    @commands.add
    class bd(command):
        COMMAND = gdb.COMMAND_BREAKPOINTS
        def invoke(self, s, from_tty):
            if s == '*':
                gdb.execute("disable breakpoints")
                return
            gdb.execute("disable breakpoints " + s)

    @commands.add
    class be(command):
        COMMAND = gdb.COMMAND_BREAKPOINTS
        def invoke(self, s, from_tty):
            if s == '*':
                gdb.execute("enable breakpoints")
                return
            gdb.execute("enable breakpoints " + s)

    @commands.add
    class ba(command):
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
        COMMAND, COMPLETE = gdb.COMMAND_BREAKPOINTS, gdb.COMPLETE_LOCATION
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
            gdb.execute("break {:s}".format(escaped_addr) + thread + rest)
    EXPORTS = commands

class running(uses_an_address):
    class go(command):
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

### defaults

## aliases
alias -- g = go
alias -- h32 = here32
alias -- h64 = here64
alias -- ps = info inferiors

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

set max-completions 32

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

## utility scripts
#guile ((lambda (script) (if (file-exists? script) (execute (format #f "source ~s" script) #t #t))) "/usr/local/lib/python2.7/dist-packages/exploitable-1.32-py2.7.egg/exploitable/exploitable.py")
#guile ((lambda (script) (if (file-exists? script) (execute (format #f "source ~s" script) #t #t))) "/usr/share/doc/python3-devel/gdbinit")
python (lambda filename: __import__('os.path').path.exists(filename) and gdb.execute("source {:s}".format(filename)))("/usr/local/lib/python2.7/dist-packages/exploitable-1.32-py2.7.egg/exploitable/exploitable.py")
python (lambda filename: __import__('os.path').path.exists(filename) and gdb.execute("source {:s}".format(filename)))("/usr/share/doc/python3-devel/gdbinit")
