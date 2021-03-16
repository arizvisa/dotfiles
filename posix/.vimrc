""" general vim options (-eval)
set nocp
set encoding=utf-8
set fileformat=unix
set fileformats=unix,dos
set formatoptions=

"" specify the default temp directory for swap files (overwritten when +eval)
set directory=$TMP,$TMPDIR

"" enforce 4 space tabbing
set ts=4
set shiftwidth=4
set expandtab
set autowrite
set autoindent

"" no wordwrap
set nowrap
set textwidth=0

set nostartofline
set nofixendofline

set noincsearch
set hlsearch
set visualbell

"" overall appearance
set laststatus=2
set ruler
set number
" set relativenumber

"" get rid of any c indentation
set nocindent

"" mapping that executes a shell command in a new window
map <C-w>! :new\|%!

"" source the .vimrc.local in the home-directory when +eval is disabled (taken from *no-eval-feature*)
silent! while 0
    silent! source $HOME/.vimrc.local
silent! endwhile

""" everything after this needs evaluation to work
if has("eval")

""" default configuration

    "" rcfile script paths
    if has("unix") || &shellslash | let s:pathsep = '/' | else | let s:pathsep = '\' | endif
    let s:rcfilename = ".vimrc"
    let s:rcfilename_site = ".vimrc.local"
    let s:rcfilename_local = ".vimrc"

    " copy them into global variables that the user can access
    let g:home = has("unix")? $HOME : $USERPROFILE
    let g:rcfilename_global = join([g:home, s:rcfilename], s:pathsep)
    let g:rcfilename_site = join([g:home, s:rcfilename_site], s:pathsep)

    "" set the swap directory to point to the working directory
    set directory=.

    " if the linux or windows temp variable is set, then add those too
    if ! empty($TMP)
        set directory+=$TMP
    elseif ! empty($TMPDIR)
        set directory+=$TMPDIR
    endif

    "" coloring (syntax and filetype)
    call matchadd('ColorColumn', '\%81v', 0x100)

    syntax enable
    filetype on

    "" remove ":" from &isfname
    let &isfname = join(filter(split(&isfname,","),'v:val!~":"'),",")

    "" get rid of all the stupid/lame (emacs-like) autoindenting
    filetype indent off
    filetype plugin off

    "" gvim-specific settings
    if has("gui_running")
        colorscheme darkblue
        set guioptions=rL

        if has("gui_win32")
            set guifont=Courier_New:h10:cANSI
        elseif has("gui_gtk")
            set guifont=Courier\ New\ 12
        else
            echoerr "Unknown gui. Unable to set guifont to Courier 10."
        endif

    "" regular vim-specific settings
    else
        try
            colorscheme distinguished
        catch /^Vim\%((\a\+)\)\=:E185/
            colorscheme elflord
        endtry
    endif

    "" default plugin options

    " for the multiplesearch plugin [ http://www.vim.org/script.php?script_id=479 ]
    let g:MultipleSearchMaxColors=16
    let w:PHStatusLine = ''

    " for vim-incpy [ http://github.com/arizvisa/vim-incpy ]
    let g:incpy#Name = "interpreter"
    let g:incpy#WindowRatio = 1.0/8

""" useful key mappings

    "" copy current locations into the default register
    nmap ,cc :let @"=substitute(expand('%'),'\\','/','g').':'.line('.')<CR>:let @*=@"<CR>
    nmap ,cf :let @"=substitute(expand('%'),'\\','/','g')<CR>:let @*=@"<CR>
    nmap ,cp :let @"=substitute(expand('%:p'),'\\','/','g')<CR>:let @*=@"<CR>
    nmap ,.  :let @"=substitute(expand('%'),'\\','/','g').':'.line('.')."\n"<CR>

""" utility functions

    " Return the full path for the specified program by searching through $PATH
    function! Which(program)
        let sep = has("unix")? ':' : ';'
        let pathsep = (has("unix") || &shellslash)? '/' : '\'
        for p in split($PATH, sep)
            let path = join([substitute(p,(!has("unix") && &shellslash)?'\\':'/',pathsep,'g'),a:program], pathsep)
            if executable(path)
                return path
            endif
        endfor
        throw printf("Unable to locate %s in $PATH", a:program)
    endfunction

    " Replace the current buffer with the contents of the specified files concatenated together
    function! CatFiles(files)
        execute "%!cat " . join(a:files, ' ')
    endfunction

    " Output the syntax identifier that is used for the highlighter
    function! SyntaxId(expr)
        let pos = getpos(a:expr)
        let id = synID(pos[1], pos[2], 1)
        return synIDattr(id, "name")
    endfunction

    let g:rcfilename_history = exists("g:rcfilename_history")? g:rcfilename_history : [expand('~/.vimrc')]
    function! <SID>source_vimrc(path)
        if type(a:path) != v:t_string
            throw printf('E474: Invalid argument; expected a string: %s', a:path)
        endif
        if !exists('g:rcfilename_history')
            throw printf('E121: Undefined variable; not initialized: %s', 'g:rcfilename_history')
        endif

        " check that the file actually exists
        let l:realpath = fnamemodify(a:path, ":p")
        if !filereadable(l:realpath)
            throw printf('E210: Error trying to read filename; file is not readable: %s', l:realpath)
        endif

        " check if the path we're going to source has already been sourced once before, this way
        " we can skip over it if necessary.
        let l:found = v:false
        for l:item in g:rcfilename_history
            if l:item == l:realpath
                let l:found = v:true
            endif
        endfor

        " if we didn't find a match, then we can source the file without issue. otherwise, just
        " warn the user about it and don't do anything else.
        if !l:found
            silent echomsg printf('Sourcing file "%s" as requested by user.', a:path)
            execute printf("source %s", l:realpath)
            let g:rcfilename_history += [l:realpath]
        else
            silent echomsg printf('Refusing to source file "%s" due to having been previously sourced.', a:path)
        endif
    endfunction

""" autocommand configuration

    "" match and then jump to a specified regex whilst updating the +jumplist
    " XXX: look into using searchpair or searchpairpos to deal with nested braces
    function! s:matchjump_internal(pattern, ...)
        let [l:l, l:c] = call('searchpos', [a:pattern] + a:000)
        if [l:l, l:c] == [0, 0]
            throw printf('E486: Pattern not found: %s', a:pattern)
        endif
        execute printf('normal %dgg0%dl', l:l, l:c + 1)
    endfunction

    function! s:matchjump(pattern, ...)
        let F = function('s:matchjump_internal')
        try
            let _ =  call(F, [a:pattern] + a:000)
        catch /^E486:/
            echoerr v:exception
        endtry
    endfunction

    "" assign mappings that deal with braces for languages where vim support is weird
    function! s:map_braces()

        " find the previous/next brace at the current column
        nnoremap <silent> <buffer> { :call <SID>matchjump(printf('\%%%dc{\_.\\|\%<%dc{\_.', col('.'), col('.')), 'Wnb')<CR>
        onoremap <silent> <buffer> { :call <SID>matchjump(printf('\%%%dc{\_.\\|\%<%dc{\_.', col('.'), col('.')), 'Wnb')<CR>
        nnoremap <silent> <buffer> } :call <SID>matchjump(printf('\%%%dc{\_.\\|\%<%dc{\_.', col('.'), col('.')), 'Wn')<CR>
        onoremap <silent> <buffer> } :call <SID>matchjump(printf('\%%%dc{\_.\\|\%<%dc{\_.', col('.'), col('.')), 'Wn')<CR>

        " find the enclosing block/brace or the next block
        nnoremap <silent> <buffer> [[ :call <SID>matchjump(printf('\%%<%dc\zs{\_.', col('.')), 'Wnb')<CR>
        onoremap <silent> <buffer> [[ :call <SID>matchjump(printf('\%%<%dc\zs{\_.', col('.')), 'Wnb')<CR>
        nnoremap <silent> <buffer> ]] :call <SID>matchjump(printf('\%%>%dc\zs{\_.', col('.')), 'Wn')<CR>
        onoremap <silent> <buffer> ]] :call <SID>matchjump(printf('\%%>%dc\zs{\_.', col('.')), 'Wn')<CR>

        " aliases for the prior two mappings
        nnoremap <silent> <buffer> [] :call <SID>matchjump(printf('\%%<%dc\zs{\_.', col('.')), 'Wnb')<CR>
        onoremap <silent> <buffer> [] :call <SID>matchjump(printf('\%%<%dc\zs{\_.', col('.')), 'Wnb')<CR>
        nnoremap <silent> <buffer> ][ :call <SID>matchjump(printf('\%%>%dc\zs{\_.', col('.')), 'Wn')<CR>
        onoremap <silent> <buffer> ][ :call <SID>matchjump(printf('\%%>%dc\zs{\_.', col('.')), 'Wn')<CR>
    endfunction

    if has("autocmd")
        augroup assembler
            let g:asmsyntax='asm'
            autocmd!
            autocmd BufNewFile,BufRead *.asm,*.[sS],*.lst call dist#ft#FTasm()
            autocmd FileType assembler setlocal expandtab tabstop=2 shiftwidth=2
        augroup end

        augroup cs
            autocmd!
            autocmd FileType cs call s:map_braces()
        augroup end

        augroup java
            autocmd!
            autocmd FileType java call s:map_braces()
        augroup end

        augroup javascript
            autocmd!
            autocmd BufNewFile,BufRead Jakefile setf javascript
            autocmd FileType javascript setlocal expandtab tabstop=2 shiftwidth=2
        augroup end

        augroup make
            autocmd!
            autocmd FileType make setlocal noexpandtab
        augroup end

        augroup golang
            autocmd!
            autocmd BufNewFile,BufRead *.go setf go
            autocmd FileType go setlocal expandtab shiftwidth=4 tabstop=4
        augroup end

        autocmd! filetypedetect * *.as
        augroup actionscript
            autocmd!
            autocmd BufNewFile,BufRead *.as setf actionscript
            autocmd FileType actionscript setlocal noexpandtab fileformat=dos shiftwidth=4 tabstop=4
        augroup end
    endif

""" session auto-saving and things
    if has("mksession") && has("autocmd")
        let s:state = ".vim.session"

        set sessionoptions=blank,buffers,curdir,folds,help,options,tabpages,winsize
        let g:session_state = join([getcwd(),s:state], s:pathsep)

        let g:session = ((argc() == 0) && empty(v:this_session) && filereadable(g:session_state))? 1 : 0
        function! Session_save(filename)
            if g:session > 0
                echomsg printf('Saving current session to %s', a:filename)
                execute printf('mksession! %s', a:filename)
                if !filewritable(a:filename)
                    echoerr printf('Unable to save current session to %s', a:filename)
                endif
            endif
        endfunction
        function! Session_load(filename)
            if g:session > 0
                echomsg printf('Loading session from %s', a:filename)
                if filereadable(a:filename)
                    execute printf('source %s', a:filename)
                endif
            endif
        endfunction

        augroup session
            autocmd!
            autocmd VimEnter * call Session_load(g:session_state)
            autocmd VimLeave * call Session_save(g:session_state)
        augroup end
    endif

""" user-local .vimrc
    if filereadable(g:rcfilename_site)
        try
            call <SID>source_vimrc(g:rcfilename_site)
        catch
            echoerr printf("Error: unable to source user-local .vimrc : %s", g:rcfilename_site)
        endtry
    else
        if !filereadable(g:rcfilename_site) | echohl WarningMsg | echomsg printf("Warning: user-local .vimrc does not exist : %s", g:rcfilename_site) | echohl None | endif
    endif

""" directory-local .vimrc
    if has("autocmd")
        augroup rcfile_local
            " FIXME: instead of checking the path to see if it's g:home, it'd probably be better to
            "        check against the runtimepath or the global list.
            " FIXME: would be pretty cool if we saved the options via option_safe() and restored them
            "        with option_restore() if possible.
            execute printf("autocmd BufRead,BufNewFile * if expand('%%:p:h') != g:home && filereadable(join([expand('%%:p:h'),\"%s\"], s:pathsep)) | call %ssource_vimrc(join([expand('%%:p:h'), \"%s\"], s:pathsep)) | endif", s:rcfilename_local, expand('<SID>'), s:rcfilename_local)
        augroup end
    endif
endif
