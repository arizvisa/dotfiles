" based on an idea that bniemczyk@gmail.com had
" thanks to ccliver@gmail.org for his input
" thanks to Tim Pope <vimNOSPAM@tpope.info> for pointing out preview windows
"
" requires vim to be compiled w/ python support. I noticed that most of my
" python development consisted of copying code into the python interpreter
" and executing it to see how my new code would act. to reduce the effort
" required by copy&paste, I decided to make vim more friendly for that style
" of development. this is the result. I apologize for the hackiness.
"
" when a .py file is opened (determined by filetype), a buffer is created
"
" python-output
" this contains the output of all the code you've executed.
" by default this is shown in a splitscreened window
"
" Usage:
" Move the cursor to a line or hilight some text (visual mode)
" and hit '!' to execute in the python interpreter. it's output will
" be displayed in 'python-output'
"
" ! -- execute current selected row
" Ctrl+@ -- display repr for symbol under character
" Ctrl+_ -- display help for symbol under character
"
" Installation:
" If in posix, copy to ~/.vim/plugin/
" If in windows, copy to $USERPROFILE/vimfiles/plugin/
"
" basic knowledge of window management is required to use effectively. here's
" a quickref:
"
"   <C-w>s -- horizontal split
"   <C-w>v -- vertical split
"   <C-w>o -- hide all other windows
"   <C-w>q -- close current window
"   <C-w>{h,l,j,k} -- move to the window left,right,down,up from current one
"
" Configuration (via globals):
" integer g:PyDisable        -- If true, will disable the plugin (but why?!)
" string g:PyBufferName      -- the name of the output buffer that gets created.
" string g:PyBufferPosition  -- buffer position.  ['above', 'below', 'left', 'right']
" float g:PyBufferRatio      -- window size on creation
" string g:PyBufferProgram   -- name of subprogram

if has("python")
    " options
    let s:options = {}
    let s:options['Disable'] = 1
    let s:options['BufferName'] = '-incpy-output-'
    let s:options['BufferPosition'] = 'below'
    let s:options['BufferRatio'] = 1.0/3
    let s:options['BufferProgram'] = ''

    " FIXME: add 'localecho'

    " set defaults in case they aren't set
    for k in keys(s:options)
        if ! exists('g:Py'. k)
            let g:Py{k} = s:options[k]
        endif
    endfor

    python <<EOF

def __incpy__():
    '''
    this function is really a front to hide the interface for
    incremental python
    '''

    try:
        # i'm a dick
        return __incpy__.cache
    except AttributeError:
        pass

    import vim,exceptions,threading

    ## miscellaneous code for frontend
    class vimerror(exceptions.Exception):
        """because vim is using old-style exceptions"""

    class position(object):
        """helper class for positioning a vim window on the screen"""

        placement = {
            'left': ('vsplit', 'leftabove'),
            'right': ('vsplit', 'rightbelow'),
            'above': ('split', 'leftabove'),
            'below': ('split', 'rightbelow'),
        }

        size = {
            'left': 'width', 'right': 'width',
            'above': 'height', 'below': 'height',
        }

        @classmethod
        def open(cls, where, options, buffername):
            opt = [ '%s=%d'%(k,v) if type(v) in (int,long) else '%s=%s'%(k,v) if type(v) in (str,unicode) else k for k,v in options.iteritems() ]
            a,b = cls.placement[where]
            if opt:
                cmd = 'noautocmd silent %s %s! +setlocal\\ %s %s'%(b,a, r'\ '.join(opt), buffername)
            else:
                cmd = 'noautocmd silent %s %s! %s'%(b,a, buffername)
            return vim.command(cmd)

        @classmethod
        def setsize(cls, where, window, size):
            attr = cls.size[where]
            setattr(window, attr, size)
        @classmethod
        def getsize(cls, where, window):
            attr = cls.size[where]
            return getattr(window,attr)
        @classmethod
        def valid(cls, where):
            return where in ('above','below','left','right')

    class pybuffer(object):
        """vim buffer management"""
        ## instance
        def __init__(self, name):
            self.buffer = self.__create(name)
            self.writing = threading.Lock()
        def __del__(self):
            self.__destroy()
        name = property(fget=lambda s:s.buffer.name)
        number = property(fget=lambda s:s.buffer.number)

        ## scope
        def __create(self, name):
            vim.command(r'badd %s'% (name,))
            return self.search_name(name)
        def __destroy(self):
            # if vim is going down, then it will crash trying to do anything
            # with python...so if it is, don't try to clean up.
            if vim.eval('v:dying'):
                return
            vim.command(r'bdelete %d'% self.buffer.number)

        ## editing buffer
        def write(self, data):
            self.writing.acquire()
            result = iter(data.split('\n'))
            self.buffer[-1] += result.next()
            [self.buffer.append(_) for _ in result]
            self.writing.release()

        def clear(self):
            self.writing.acquire()
            self.buffer[:] = ['']
            self.writing.release()

        ## searching buffers
        @staticmethod
        def search_name(name):
            for b in vim.buffers:
                if b.name is not None and b.name.endswith(name):
                    return b
                continue
            raise vimerror("unable to find buffer '%s'"% name)
        @staticmethod
        def search_number(number):
            for b in vim.buffers:
                if b.number == number:
                    return b
                continue
            raise vimerror("unable to find buffer %d"% number)

    class pywindow(object):
        """keeps track of a window buffer even if it's not showing"""
        ## instance
        window = property(fget=lambda self:self.find(self.buffer))
        def __init__(self, name, placement):
            self.buffer = pybuffer(name)
            self.pos = placement
            self.size = 0
            self.vimlock = threading.Lock()

        def locate(self):
            """select the window containing our buffer. return the previous window."""
            return self.select(self.window)

        ## utils
        @staticmethod
        def find(buffer):
            """return the first window that contains buffer"""
            for w in vim.windows:
                if w.buffer.number == buffer.number:
                    return w
                continue
            raise vimerror("unable to find window %d"% buffer.number)

        @staticmethod
        def select(window):
            """try and navigate to the requested window. return the current window."""
            original = vim.current.window
            if window == original:
                return original
            for _ in xrange(len(vim.windows)):
                vim.command("noautocmd normal ")
                current = vim.current.window
                try:
                    if current == window:
                        return original
                except e:
                    continue
                continue
            if original.buffer.number != vim.current.window.buffer.number:
                raise vimerror("unable to select buffer %d. failed to return to original buffer '%d'"% (window.buffer.number, original.buffer.number))
            raise vimerror("unable to select buffer %d"% window.buffer.number)

        ## interaction
        def write(self, data):
            # XXX: this if test hides an instance of a concurrency bug
            #        to reproduce, try repeatedly executing an empty-line
            if len(data) == 0:
                return

            self.buffer.write(data)
            if vim.current.window.buffer.number == self.buffer.number:
                return

            # FIXME: not sure why this lock doesn't work as i want it to
            self.vimlock.acquire()
            try:
                last = self.locate()
                vim.command('noautocmd normal gg')
                vim.command('noautocmd normal G')
                w = self.select(last)
                # FIXME: after writing, restore the cursor to it's last position
            except vimerror, e:
                # window is not available
                pass
            self.vimlock.release()

        def show(self, **options):
            """shows the current window. returns it."""
            try:
                return self.find(self.buffer)
            except vimerror,e:
                pass

            last = vim.current.window
            position.open(self.pos, options, self.buffer.name)
            self.select(last)

            window = self.window
            position.setsize(self.pos, window, self.size)
            return window

        def hide(self):
            """hides the current window. returns whether it was currently being displayed or not"""
            try:
                last = self.locate()
            except vimerror,e:
                return False

            self.size = position.getsize(self.pos,vim.current.window)
            if last == vim.current.window:
                vim.command('silent close!')
                return True
            vim.command('silent close!')
            self.select(last)
            return True

        ## state
        def setplace(self, placement):
            assert position.valid(placement)
            if self.pos != placement:
                self.size = 0
            self.pos = placement
        def setsize(self, size):
            assert size > 0
            self.size = size

    # XXX: all hacky stuff is after this line
    ## frontend
    class frontend(object):
        display = None
        def __init__(self, name, **options):
            raise NotImplementedError
        def show(self, **options):
            raise NotImplementedError
        def hide(self):
            raise NotImplementedError
        def save(self):
            raise NotImplementedError
        def write(self, data):
            # FIXME: sometimes this causes vim to re-enter itself
            return self.display.write(data)

    class frontend_pywindow(frontend):
        """Default frontend that uses a vim window+buffer"""
        def __init__(self, buffername, placement, ratio, options):
            self.display = pywindow(buffername, placement)
            self.ratio = ratio
            self.options = options
        def show(self, placement=None, ratio=None):
            if placement != None:
                self.display.setplace(placement)
            if ratio is None and self.display.size > 0:
                return self.display.show(**self.options)

            parent = vim.current.window
            if self.display.size == 0:
                ratio = self.ratio if ratio is None else ratio

            parentsize = position.getsize(self.display.pos,parent)
            newsize = int(round(parentsize*ratio))
            self.display.setsize(newsize)
            return self.display.show(**self.options)
        def hide(self):
            if vim.eval('v:dying'):
                # vim is terminating, don't try to make any calls into vim if so
                return
            return self.display.hide()
        def save(self):
            window = self.display.window
            size = position.getsize(self.display.pos, window)
            return self.display.setsize(size)

    ## backends
    class backend(object):
        def install(self, frontend):
            raise NotImplementedError
        def execute(self, command):
            raise NotImplementedError
        def uninstall(self):
            raise NotImplementedError

    class backend_internalpython(backend):
        """Backend that utilizes vim's internal python instance"""
        def install(self, frontend):
            self.state = (sys.stdin,sys.stdout,sys.stderr)
            sys.stdout = frontend
        def execute(self, command):
            print '\n'.join("## %s"%x for x in command.split('\n'))
            exec(command) in globals()
        def uninstall(self):
            stdin,stdout,stderr = self.state
            sys.stdin,sys.stdout,sys.stderr = self.state

    if """Backend that uses an external python instance""":
        import os,signal,threading,Queue,subprocess,time
        class spawn(object):
            """Spawns a program along with a few monitoring threads.

            Provides stdout and stderr in the form of Queue.Queue objects to allow for asynchronous reading.
            """

            program = None              # subprocess.Popen object
            stdout,stderr = None,None   # queues containing stdout and stderr
            id = property(fget=lambda s: s.program.pid)
            running = property(fget=lambda s: s.program.poll() is None)

            def __init__(self, command, **kwds):
                # process
                env = kwds.get('env', os.environ)
                cwd = kwds.get('cwd', os.getcwd())
                joined = kwds.get('joined', True)
                newlines = kwds.get('newlines', True)
                self.program = program = self.__newprocess(command, cwd, env, newlines, joined=joined)

                ## monitor threads (which aren't important if python didn't suck with both threads and gc)
                threads = []
                t,stdout = spawn.monitorPipe('thread-%x-stdout'% program.pid, program.stdout)
                threads.append(t)
                if not joined:
                    t,stderr = spawn.monitorPipe('thread-%x-stderr'% program.pid, program.stderr)
                    threads.append(t)
                else:
                    stderr = None
                self.__threads = threads

                # queues containing stdout and stderr
                self.stdout,self.stderr = stdout,stderr

                # set things off
                for t in threads:
                    t.start()

            def __newprocess(self, program, cwd, environment, newlines, joined):
                stderr = subprocess.STDOUT if joined else subprocess.PIPE
                if os.name == 'nt':
                    si = subprocess.STARTUPINFO()
                    si.dwFlags = subprocess.STARTF_USESHOWWINDOW
                    si.wShowWindow = subprocess.SW_HIDE
                    return subprocess.Popen(program, universal_newlines=newlines, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr, close_fds=False, startupinfo=si, cwd=cwd, env=environment)
                return subprocess.Popen(program, universal_newlines=newlines, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=stderr, close_fds=True, cwd=cwd, env=environment)
            
            @staticmethod
            def monitorPipe(id, pipe, blocksize=1):
                """Create a monitoring thread that stuffs data from a pipe into a queue.

                Returns a (threading.Thread, Queue.Queue)
                (Queues are the only python object that allow you to timeout if data isn't currently available)
                """

                def shuffle(queue, pipe):
                    while not pipe.closed:
                        data = pipe.read(blocksize)
                        queue.put(data)
                    return

                q = Queue.Queue()   # XXX: this should be a multiprocessing.Pipe, but i've had many a problems with that module
                if id is None:
                    monitorThread = threading.Thread(target=shuffle, args=(q,pipe))
                else:
                    monitorThread = threading.Thread(target=shuffle, name=id, args=(q,pipe))
                monitorThread.daemon = True
                return monitorThread,q

            def write(self, data):
                """Write data directly to program's stdin"""
                return self.program.stdin.write(data)

            def signal(self, signal):
                """Send a signal to the program"""
                return self.program.send_signal(signal)

            def wait(self, timeout=0.0):
                """Wait for a process to terminate"""
                program = self.program

                if timeout:
                    t = time.time()
                    while t + timeout > time.time():        # spin until we timeout
                        if program.poll() is not None:
                            return program.returncode
                        continue
                    return None

                return program.wait()

            def stop(self):
                """Sends a SIGKILL signal and then waits for program to complete"""
                p = self.program
                p.kill()
                result = p.wait()
                self.stop_monitoring()
                self.program = None
                return result

            def stop_monitoring(self):
                """Cleanup monitoring threads"""

                # close pipes that have been left open since python fails to do this on program death
                p,stdout,stderr = self.program,self.stdout,self.stderr

                p.stdin.close()
                for q,p in ((stdout,p.stdout), (stderr,p.stderr)):
                    if q is None:
                        continue
                    q.mutex.acquire()
                    while not p.closed:
                        try: p.close()
                        except IOError:
                            continue
                    q.mutex.release()
                [ x.join() for x in self.__threads]

    import threading
    class backend_externalprogram(backend):
        """Backend that utilizes vim's internal python instance"""
        def __init__(self, program):
            self.command = program

        @classmethod
        def update(cls, program, frontend):
            stdout,stderr = program.stdout,program.stderr
            while program.running:
                out = ''
                while not stdout.empty():
                    out += stdout.get()
                if out:
                    frontend.write(out)
            return

        def install(self, frontend):
            self.frontend = frontend
            self.program = spawn(self.command, joined=True)
            self.updater = threading.Thread(target=self.update, name="%x-update"% self.program.id, args=(self.program,frontend))
            self.updater.daemon = True
            frontend.show()
            self.updater.start()   # XXX
        def execute(self, command):
            self.frontend.write(command+"\n")
            self.program.write(command+"\n")
        def uninstall(self):
            self.program.stop()
            del(self.updater)

    ## back to __incpy__()
    # FIXME: figure out a better way to inherit these from vim's global variables
    Defaults = {
        'ratio' : 1.0/3,
        'placement' : 'below',
        'options' : {'buftype':'nowrite', 'noswapfile':True, 'updatecount':0, 'nobuflisted':True, 'filetype':'python'},
        'program' : '',
    }

    import sys
    class result(object):
        frontend = backend = None
        stdin,stdout,stderr = sys.stdin,sys.stdout,sys.stderr

        @staticmethod
        def message(string):
            return result.stdout.write(string)
        @staticmethod
        def error(string):
            return result.stderr.write(string)

        @staticmethod
        def initialize(name, **options):
            if result.backend is not None:
                raise vimerror("incremental python is already initialized")
            Defaults.update(options)

            result.frontend = frontend_pywindow(name, Defaults['placement'],Defaults['ratio'],Defaults['options'])
            result.backend = backend_externalprogram(Defaults['program']) if Defaults['program'] else backend_internalpython()
            result.backend.install(result.frontend)

        @staticmethod
        def execute(data):
            if result.backend:
                return result.backend.execute(data)
        @staticmethod
        def write(data):
            if result.frontend:
                return result.frontend.write(data)
        @staticmethod
        def show(placement=None, ratio=None):
            if result.frontend:
                return result.frontend.show(placement, ratio)
        @staticmethod
        def hide():
            if result.frontend:
                return result.frontend.hide()

        @staticmethod
        def destroy():
            if result.backend:
                result.backend.uninstall()
            if result.frontend:
                result.frontend.hide()
                del(result.frontend)
            result.frontend,result.backend = None,None

        @staticmethod
        def save():
            return result.frontend.save()

    # store it where it will be used
    __incpy__.cache = result
    return __incpy__()  # yea, i'm really a dick
    
EOF
    """ utility functions
    function s:count_indent(string)
        " count the beginning whitespace of a string
        let characters = 0
        for c in split(a:string,'\zs')
            if stridx(" \t",c) == -1
                break
            endif
            let characters += 1
        endfor
        return characters
    endfunction

    function s:find_common_indent(lines)
        " find the smallest indent
        let smallestindent = -1
        for l in a:lines
            " skip empty lines
            if strlen(l) == 0
                continue
            endif

            let spaces = s:count_indent(l)
            if smallestindent < 0 || spaces < smallestindent
                let smallestindent = spaces
            endif
        endfor
        return smallestindent
    endfunction

    function s:strip_indentation(lines)
        let indentsize = s:find_common_indent(a:lines)

        " remove the indent
        let results = []
        let prevlength = 0
        for l in a:lines
            if strlen(l) == 0
                let row = repeat(" ",prevlength)
            else
                let row = strpart(l,indentsize)
                let prevlength = s:count_indent(row)
            endif
            let results += [row]
        endfor

        return results
    endfunction

    function s:selected() range
        " really, vim? really??
        let oldvalue = getreg("")
        normal gvy
        let result = getreg("")
        call setreg("", oldvalue)
        return result
    endfunction

    " show/hide python interface
    function incpy#show()
        execute('python __incpy__().show(placement="'. g:PyBufferPosition .'")')
    endfunction
    function incpy#hide()
        execute('python __incpy__().hide()')
    endfunction

    " evaluate one line of python
    function incpy#execute(line)
        let s = s:strip_indentation([a:line])
        call incpy#show()
        execute('python __incpy__().execute("'. escape(s[0],'"') .'\n")')
    endfunction

    " evaluate multiple lines of python
    function incpy#range(begin, end)
        let lines = s:strip_indentation( getline(a:begin,a:end) )
        let code = map(lines, 'escape(v:val, "\\")')
        let code_s = join(code,'\n')
        call incpy#show()
        execute('python __incpy__().execute("'. escape(code_s,'"') .'")')
    endfunction

    " display help for something in our output buffer
    function incpy#help(arg)
        call incpy#show()
        execute('python __incpy__().execute("help('. a:arg .')")')
    endfunction

    " evaluate a variable and display it
    function incpy#evaluate(variable)
        call incpy#show()
        execute('python __incpy__().execute("_=None;_=eval(\"'. escape(a:variable,'"') .'\");print repr(_)")')
    endfunction

    """ setup some useful commands
    function s:setup_commands()
        command PyLine call incpy#range(line("."),line("."))
        command PyBuffer call incpy#range(0,line('$'))

        command -nargs=1 Py call incpy#execute(<q-args>)
        command -nargs=1 PyEval call incpy#evaluate(<q-args>)
        command -nargs=1 PyHelp call incpy#help(<q-args>)

        command -range PyRange call incpy#range(<line1>,<line2>)
        command -range PyEvalRange <line1>,<line2>call incpy#evaluate(s:selected())
        command -range PyHelpRange <line1>,<line2>call incpy#help(s:selected())
    endfunction

    function s:setup_maps()
        vmap ! :PyRange<C-M>
        vmap <C-@> :PyEvalRange<C-M>
        vmap <C-_> :PyHelpRange<C-M>

        nmap ! :PyLine<C-M>
        nmap <C-@> :call incpy#evaluate(expand("<cword>"))<C-M>
        nmap  :call incpy#help(expand("<cword>"))<C-M>
    endfunction

    function s:setup_autohide()
        " when entering/leaving anything that has a python filetype
        function l:show()
            if &filetype =~ 'python'
                call incpy#show()
            endif
        endfunction
        function l:hide()
            if &filetype =~ 'python' || bufname('%') == '' || bufname('%') == g:PyBufferName
                return
            endif
            call incpy#hide()
        endfunction

        autocmd BufEnter * call l:show()
        autocmd BufLeave * call l:hide()
        autocmd BufLeave g:PyBufferName python __incpy__().save()
    endfunction

    function PyInit()
        execute('python __incpy__().initialize("'. g:PyBufferName .'",placement="'. g:PyBufferPosition .'",ratio='. printf('%f',g:PyBufferRatio) .',program="'. g:PyBufferProgram .'")')
        call s:setup_commands()
        call s:setup_maps()
        call s:setup_autohide()
    endfunction

    function PyUninit()
        execute('python __incpy__().destroy()')
    endfunction

    if g:PyDisable == 0
        autocmd! VimEnter * call PyInit()
        autocmd! VimLeavePre * call PyUninit()
    endif
endif

