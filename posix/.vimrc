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
    set noautoindent
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
    "set sessionoptions=blank,buffers,curdir,folds,help,options,tabpages,winsize
    if has("unix") || &shellslash | let s:pathsep = '/' | else | let s:pathsep = '\' | endif
    let g:session_file = join([getcwd(),".vim.session"], s:pathsep)
    if (argc() == 0) && empty(v:this_session) && filereadable(g:session_file)
        let g:session = 1
    else
        let g:session = 0
    endif

    function! Session_save(filename)
        if g:session > 0
            echomsg 'Saving current session to ' . a:filename
            execute 'mksession! ' . a:filename
            if !filewritable(a:filename)
                echoerr 'Unable to save current session to ' . a:filename
            endif
        endif
    endfunction
    function! Session_load(filename)
        if g:session > 0
            echomsg 'Loading session from ' . a:filename
            if filereadable(a:filename)
                execute 'source ' . a:filename
            endif
        endif
    endfunction

    augroup session
        autocmd!
        autocmd VimEnter * call Session_load(g:session_file)
        autocmd VimLeave * call Session_save(g:session_file)
    augroup end

""" plugin options
    "" for the multiplesearch plugin [ http://www.vim.org/script.php?script_id=479 ]
    let g:MultipleSearchMaxColors=16
    let w:PHStatusLine = ''

    "map <C-g> :call MapCtrlG()<CR>
    "let g:incpy#Program = "c:/ocaml/bin/ocaml.exe"
    "let g:incpy#Program = "c:/python27/python -i"
    "let g:incpy#Program = "c:/users/user/pypy/pypy.exe -i -u -B"
    "let g:incpy#Program = "c:/MinGW/msys/1.0/bin/bash.exe -i"
    "let g:incpy#Program = "c:/Program Files (x86)/Microsoft SDKs/F#/3.0/Framework/v4.0/fsi.exe --readline- --checked+ --tailcalls+ --consolecolors- --fullpaths"

    let g:incpy#Name = "internal-python"
    let g:incpy#Program = ""
    let g:incpy#WindowRatio = 1.0/8
    "let g:incpy#WindowPreview = 1
    "let g:incpy#ProgramFollow = 0
    "let g:incpy#ProgramStrip = 0

""" Disable vim's syntax coloring for ruby because it crashes my version of gvim (7.4)
    autocmd! filetypedetect * *.rb
