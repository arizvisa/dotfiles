""" script locals and default configs
    if has("unix") || &shellslash | let s:pathsep = '/' | else | let s:pathsep = '\' | endif
    let s:rcfilename = ".vimrc"
    let s:rcfilename_site = ".vimrc.local"
    let s:rcfilename_local = ".vimrc"
    let s:state = ".vim.session"

    set sessionoptions=blank,buffers,curdir,folds,help,options,tabpages,winsize

""" general vim options
    set nocp
    set encoding=utf-8
    set fileformat=unix
    set fileformats=unix,dos
    set formatoptions=

    "" specify the property directory for swap files
    set directory=.
    if ! empty($TMP)
        set directory+=$TMP
    elseif ! empty($TMPDIR)
        set directory+=$TMPDIR
    endif

    "" enforce 4 space tabbing
    set ts=4
    set shiftwidth=4
    set expandtab
    set autowrite
    set autoindent

    "" no wordwrap
    set nowrap
    set textwidth=0
    set colorcolumn=81
    set nostartofline

    "" coloring
    syntax enable
    filetype on
    set hlsearch
    set visualbell

    "" overall appearance
    set laststatus=2
    set ruler
    set number
    "set relativenumber

    "" remove ":" from &isfname
    let &isfname = join(filter(split(&isfname,","),'v:val!~":"'),",")

    "" get rid of the stupid/lame (emacs-like) autoindenting
    set nocindent
    filetype indent off
    filetype plugin off

""" useful mappings
    "" execute shell command in a new window
    map <C-w>! :new\|%!

    "" copy current locations into the default register
    nmap ,cc :let @"=substitute(expand('%'),'\\','/','g').':'.line('.')<CR>:let @*=@"<CR>
    nmap ,cf :let @"=substitute(expand('%'),'\\','/','g')<CR>:let @*=@"<CR>
    nmap ,cp :let @"=substitute(expand('%:p'),'\\','/','g')<CR>:let @*=@"<CR>
    nmap ,.  :let @"=substitute(expand('%'),'\\','/','g').':'.line('.')."\n"<CR>

    "" for gvim
    if has("gui_running")
        colorscheme darkblue
        set guioptions=rL

        if has("gui_win32")
            set guifont=Courier_New:h10:cANSI
        elseif has("gui_gtk2")
            set guifont=Courier\ 10\ Pitch\ 10
        else
            echoerr "Unknown gui. Unable to set guifont to Courier 10."
        endif
    else
        try
            colorscheme distinguished
        catch /^Vim\%((\a\+)\)\=:E185/
            colorscheme elflord
        endtry
    endif

""" globals
    let g:HOME = has("windows")? $USERPROFILE : $HOME
    let g:rcfilename_global = join([g:HOME, s:rcfilename], s:pathsep)
    let g:rcfilename_site = join([g:HOME, s:rcfilename_site], s:pathsep)

""" utility functions
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

    function! Catfiles(files)
        execute "%!cat " . join(a:files, ' ')
    endfunction

    function! MapCtrlG()
        let p = getpos('.')
        let x = p[1] * p[2]
        execute 'python findTag("' . expand("%") . '", ' . x . ')'
        execute 'echo "' . escape(w:PHStatusLine, '"') . '"'
    endfunction

""" autocommand configuration
    function! s:map_braces()
            map <buffer> [m :execute '?\%' . col(".") . 'c{\_.\\|\%<' . col(".") . 'c{\_.'<CR>
            map <buffer> ]m :execute '/\%' . col(".") . 'c{\_.\\|\%<' . col(".") . 'c{\_.'<CR>

            map <buffer> [[ :execute '?\%<' . col(".") . 'c\zs{\_.'<CR>
            map <buffer> ]] :execute '/\%>' . col(".") . 'c\zs{\_.'<CR>w

            map <buffer> [] :execute '?\%<' . col(".") . 'c\zs{\_.'<CR>%
            map <buffer> ][ :execute '/\%>' . col(".") . 'c\zs{\_.'<CR>w%
    endfunction

    augroup cs
            autocmd!
            autocmd BufEnter,BufRead,BufNewFile *.cs call s:map_braces()
    augroup end

    augroup java
            autocmd!
            autocmd BufEnter,BufRead,BufNewFile *.cs call s:map_braces()
    augroup end

    autocmd BufNewFile,BufRead *.go setf go
    autocmd FileType go setlocal noexpandtab shiftwidth=4 tabstop=4

""" session auto-saving and things
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

""" default plugin options
    "" for the multiplesearch plugin [ http://www.vim.org/script.php?script_id=479 ]
    let g:MultipleSearchMaxColors=16
    let w:PHStatusLine = ''

    "" for vim-incpy [ http://github.com/arizvisa/vim-incpy ]
    let g:incpy#Name = "interpreter"
    let g:incpy#WindowRatio = 1.0/8

""" site-local .vimrc
    if !exists("g:vimrc_site") | let g:vimrc_site = 0 | endif
    if g:vimrc_site == 0 && filereadable(g:rcfilename_site)
        try
            exec printf("source %s", g:rcfilename_site)
            let g:vimrc_site += 1
        catch
            echoerr printf("Error: unable to source site-local .vimrc : %s", g:rcfilename_site)
        endtry
    else
        if !filereadable(g:rcfilename_site) | echohl WarningMsg | echomsg printf("Warning: site-local .vimrc does not exist : %s", g:rcfilename_site) | echohl None | endif
    endif

""" directory-local .vimrc
    augroup vimrc-directory-local
        exec printf("autocmd BufRead,BufNewFile * if expand('%%:p:h') != g:HOME && filereadable(join([expand('%%:p:h'),\"%s\"], s:pathsep)) | exec printf(\"source %%s\", join([expand('%%:p:h'), \"%s\"], s:pathsep)) | endif", s:rcfilename_local, s:rcfilename_local)
    augroup end

