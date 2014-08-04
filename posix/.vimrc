" we don't need any vi compatibility
set nocp
set encoding=utf-8
set novisualbell

" swap directories
set directory=.
if ! empty($TMP)
    set directory+=$TMP
elseif ! empty($TMPDIR)
    set directory+=$TMPDIR
endif

" enforce 4 space tabbing
set ts=4
set shiftwidth=4
set expandtab
set autowrite
set nostartofline

set nowrap
set textwidth=0
syntax enable
filetype on

set hls

set laststatus=2
set ruler
set visualbell

set fileformats=unix,dos
set formatoptions=

" get rid of the stupid/lame (emacs-like) autoindenting
set noautoindent
set nocindent
filetype indent off
filetype plugin off

" for the multiplesearch plugin [ http://www.vim.org/script.php?script_id=479 ]
let g:MultipleSearchMaxColors=16

" for gvim
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

function Catfiles(files)
    execute "%!cat " . join(a:files, ' ')
endfunction

function MapCtrlG()
    let p = getpos('.')
    let x = p[1] * p[2]
    execute 'python findTag("' . expand("%") . '", ' . x . ')'
    execute 'echo "' . escape(w:PHStatusLine, '"') . '"'
endfunction
let w:PHStatusLine = ''

"map <C-g> :call MapCtrlG()<CR>
map <C-w>! :new\|%!
"let g:incpy#Program = "c:/ocamlms/bin/ocaml.exe"
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
