""" general vim options (-eval)
set nocp
set encoding=utf-8
set fileencoding=utf-8
set fileformat=unix
set fileformats=unix,dos
set formatoptions=jtnbc
set display=lastline,uhex

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
set textwidth=80

set nostartofline
set nofixendofline

set noincsearch
set hlsearch
set visualbell

"" overall appearance
set laststatus=2
set number

if has('statusline') && has('byte_offset')
    "set statusline=%<%f\ %h%w%m%r%=%-0.(%l,%c%V\ (0x%O)%)\ %P
    set statusline=%<%f\ %h%w%m%r%=[%\{winnr()\}]\ %-0.(%l,%c%V\ (0x%O)%)\ %P
elseif has('byte_offset')
    set ruler
    "set rulerformat=%24(%=%.(%l,%c%V\ (0x%O)\ %P%)%)
    set rulerformat=%32(%=[%\{winnr()\}]\ %.(%l,%c%V\ (0x%O)\ %P%)%)
else
    set ruler
endif

" set some list characters corresponding to the gui or console
set list
if has('gui_running')
    set listchars=tab:˃·,trail:ˍ
else
    set listchars=tab:»·,trail:°
endif

" smoothscroll
if v:version >= 901
    set smoothscroll
endif

" number formats
if has('patch-9.1.0537')
    set nrformats=hex,octal,bin,blank
else
    set nrformats=hex,octal,bin
endif

" virtualedit
if has('virtualedit')
    set virtualedit=block
endif

"" get rid of any c indentation
set nocindent

"" mapping that executes a shell command in a new window
map <C-w>! :new\|%!

"" source the .vimrc.local in the home-directory when +eval is disabled (taken from *no-eval-feature*)
silent! while 0
    silent! source $HOME/.vimrc.local
silent! endwhile

""" default configuration
if has("eval")

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
    syntax enable
    filetype on

    " similar to colorcolumn, but only if there's a character there.
    autocmd BufEnter,WinEnter,TabEnter * call matchadd('ColorColumn', printf('\%%%dv', 1 + ((&textwidth > 0)? &textwidth : 80)), 0x100)

    "" remove ":" from &isfname
    let &isfname = join(filter(split(&isfname,","),'v:val!~":"'),",")

    "" get rid of all the stupid/lame (emacs-like) autoindenting
    filetype indent off
    filetype plugin on

    " if you need your editor to automatically insert a comment leader
    " while you're editing comments, then you're a real fucking idiot.
    autocmd FileType * setlocal formatoptions-=r formatoptions-=o

    "" gvim-specific settings
    if has("gui_running")
        colorscheme darkblue
        set guioptions=rL

        if has("gui_win32")
            set guifont=Courier_New:h10:cANSI
        elseif has("gui_gtk")
            set guifont=Courier\ New\ 12
        elseif has("gui") && has("osx")
            set guifont=CourierNewPSMT:h13
        else
            echoerr "Unknown gui. Unable to set guifont to Courier 10."
        endif

    "" regular vim-specific settings
    else
        let s:colorschemes = [has('nvim')? 'default' : 'distinguished', 'habamax', 'slate', 'lunaperche']
        for s:colorscheme in s:colorschemes
            try | execute printf('colorscheme %s', s:colorscheme) | break
            catch /^Vim\%((\a\+)\)\=:E185/ | endtry
        endfor
    endif
endif

"" default plugin options

" for the multiplesearch plugin [ http://www.vim.org/script.php?script_id=479 ]
if has("eval")
    let g:MultipleSearchMaxColors=16
    let w:PHStatusLine = ''
endif

" netrw plugin configuration
if has("eval")
    let g:netrw_nogx = v:true
    let g:netrw_banner = 0
    let g:netrw_keepj = 'keepj'
    let g:netrw_liststyle = 3
    let g:netrw_browse_split = 4
    let g:netrw_dirhistmax = 4

    let g:netrw_browsex_viewer = '-'
    let g:netrw_browsex_support_remote = v:false
    let g:netrw_winsize = 25

    """ netrw-noload
    let g:loaded_netrw = 1
    let g:loaded_netrwPlugin = 1

    let g:netrw_compress = 'xz'
    let g:netrw_compress = 'zstd'
    let g:netrw_decompress = {
    \   '.gz'  : 'gunzip' ,
    \   '.bz2' : 'bunzip2' ,
    \   '.zip' : 'unzip' ,
    \   '.tar' : 'tar -xvf',
    \   '.xz' : 'xz -d',
    \   '.zst' : 'zstd -d', '.z' : 'zstd -d',
    \   '.lzma' : 'lzma -d',
    \   '.7z' : '7z -x',
    \ }
endif

" enable the Man command from the man.vim filetype plugin
if exists(':Man') != 2 && !exists('g:loaded_man') && &filetype !=? 'man'
    runtime ftplugin/man.vim
endif

" copied from diff-original-file
if exists(':DiffOrig') != 2
    command DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis | wincmd p | diffthis
endif

""" useful key mappings
if has("eval")

    "" bring shift-tab back to life. we don't bother with <Tab> because it
    "" seems to interfere with jumplist navigation (<C-i> and <C-o>)...
    inoremap <S-Tab> <C-d>
    vnoremap <S-Tab> <
    nnoremap <S-Tab> <<

    " <Tab> doesn't mean anything in visual-mode, so we can use it.
    "inoremap <Tab> <Tab>
    vnoremap <Tab> >
    "nnoremap <Tab> >>

    " Adjusting indentation does not exit visual-mode,
    " since we're now using <Tab> for that.
    vnoremap > ><CR>gv
    vnoremap < <<CR>gv

    " <S-Space> is recognized by some terminals, so we discard it.
    tnoremap <S-Space> <Space>

    " Remap the 'w' window command (wincmd) so that visiting the
    " previous window can be performed on one side of the keyboard.
    noremap <silent> <C-w>w <Cmd>wincmd p<CR>
    noremap <silent> <C-w>W <Cmd>wincmd p<CR>
    noremap <silent> <C-w><C-w> <Cmd>wincmd p<CR>

    " Replace the original variations of the 'p' window command (wincmd),
    " with a mapping that jumps to the currently available preview window.
    noremap <silent> <C-w>p <Cmd>wincmd P<CR>
    noremap <silent> <C-w>P <Cmd>wincmd P<CR>
    noremap <silent> <C-w><C-p> <Cmd>wincmd P<CR>

    " Remap the original 'w' and 'W' commands to go "forward" and "backward"
    " between windows. We leave 'f' alone so we can still split-edit <cfile>.
    "noremap <silent> <C-w>f <Cmd>wincmd w<CR>
    noremap <silent> <C-w><C-f> <Cmd>wincmd w<CR>
    noremap <silent> <C-w>b <Cmd>wincmd W<CR>
    noremap <silent> <C-w><C-b> <Cmd>wincmd W<CR>

    " Display a mode-message when a new undo branch gets created. Unfortunately,
    " this doesn't work when using the gui because the mode bar doesn't appear
    " to get rendered before our call to :sleep.
    if !has('gui')
        inoremap <silent> <C-g>u <C-g>u<Cmd>echohl ModeMsg<Bar>echomsg"-- NEW UNDO BRANCH --"<Bar>echohl None<Bar>sleep 500m<CR>
        inoremap <silent> <C-g><C-u> <C-g>u<Cmd>echohl ModeMsg<Bar>echomsg"-- NEW UNDO BRANCH --"<Bar>echohl None<Bar>sleep 500m<CR>
    endif

    "" The following mappings are just for copying the current location and some
    "" lines into the default register, current selection, or clipboard.

    let g:mapleader = ','

        "" normalize a file path for whatever platform we're on
        function! <SID>normalpath(path)
            return substitute(a:path, '\\', '/', 'g')
        endfunction

        "" (functions) copy current location and any lines if a count is given
        function! <SID>normallines(count)
            let l:line = line(".")
            return v:count > 1? printf("%d-%d", l:line, a:count - 1 + l:line) : l:line
        endfunction
        function! <SID>normaltext(count)
            let l:items = getline(".", a:count - 1 + line("."))
            return a:count? join([""] + l:items + [""], "\n") : "\n"
        endfunction

        "" (functions) copy current location and any lines if a range is given
        function! <SID>visuallines()
            let [l:start, l:stop] = [line("'<"), line("'>")]
            return l:start == l:stop? l:start : printf("%d-%d", l:start, l:stop)
        endfunction
        function! <SID>visualtext(mode)
            let l:lines = getline("'<", "'>")
            if a:mode == "V"
                let l:items = l:lines
            elseif a:mode == "v"
                let [l:start, l:stop] = [charcol("'<") - 1, charcol("'>") - 1]
                let [l:first, l:rest, l:last] = [l:lines[0], len(l:lines) > 2? l:lines[1:-2] : [], l:lines[-1]]
                let l:items = len(l:lines) > 1? [l:first[l:start:]] + l:rest + [l:last[:l:stop]] : len(l:lines) > 0? [l:first[l:start : l:stop]] : l:lines
            elseif a:mode == ""
                let l:sliced = printf("v:val[%d:%d]", col("'<") - 1, col("'>") - 1)
                let l:items = map(l:lines, l:sliced)
            else
                throw printf('Unable to return visual text using an invalid mode (%s).', a:mode)
            endif
            return join([""] + l:items + [""], "\n")
        endfunction

        " Copy current path, filename (relative), location (line number), or
        " the location with code to the x-selection and clipboard registers.
        nnoremap <silent> <Leader>cp <Cmd>let @"=<SID>normalpath(expand('%:~'))<CR><Cmd>let @+=@"<CR><Cmd>let @*=@"<CR>
        nnoremap <silent> <Leader>cf <Cmd>let @"=<SID>normalpath(expand('%:.'))<CR><Cmd>let @+=@"<CR><Cmd>let @*=@"<CR>
        noremap <silent> <Leader>cl <Cmd>let @"=<SID>normalpath(expand('%:.')) . ':' . <SID>normallines(v:count)<CR><Cmd>let @+=@"<CR><Cmd>let @*=@"<CR>
        noremap <silent> <Leader>cc <Cmd>let @"=<SID>normalpath(expand('%:.')) . ':' . <SID>normallines(v:count) . <SID>normaltext(v:count)<CR><Cmd>let @+=@"<CR><Cmd>let @*=@"<CR>

        " We can't use a command mapping (<Cmd>) in visual or select mode since it
        " seems to change the result of the "visualmode" function. So, we assign
        " the copy location and with code mappings separately from the others.
        xnoremap <silent> <Leader>cl :<C-U>let @"=<SID>normalpath(expand('%:.')) . ':' . <SID>visuallines()<CR><Cmd>let @+=@"<CR><Cmd>let @*=@"<CR>
        xnoremap <silent> <Leader>cc :<C-U>let @"=<SID>normalpath(expand('%:.')) . ':' . <SID>visuallines() . <SID>visualtext(visualmode())<CR><Cmd>let @+=@"<CR><Cmd>let @*=@"<CR>

    unlet g:mapleader

    "" Miscellaneous utilities
    nnoremap gs <Cmd>echomsg SyntaxIds('.')<CR>
    "noremap <silent> <F6> <Cmd>Lexplore<CR>
    noremap <silent> <F6> <Cmd>NERDTreeToggle<CR>

    " Quickfix-related mappings
    if has('quickfix')
        noremap <silent> <F5> <Cmd>if getqflist({'winid':0}).winid == 0 \| copen \| else \| cclose \| endif<CR>
        autocmd QuickFixCmdPost * copen
        if has('cscope')
            set cscopequickfix=s-,c-,d-,i-,t-,e-,a-
        endif
    endif
endif

""" utility functions
if has("eval")

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
        throw printf('Unable to locate %s in $PATH', a:program)
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

    function! SyntaxIds(expr)
        let pos = getpos(a:expr)
        let ids = synstack(pos[1], pos[2])
        return mapnew(ids, 'synIDattr(v:val, "name")')
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
            execute printf('source %s', l:realpath)
            let g:rcfilename_history += [l:realpath]
        else
            silent echomsg printf('Refusing to source file "%s" due to having been previously sourced.', a:path)
        endif
    endfunction
endif

""" autocommand configuration
if has("eval") && has("autocmd")
    function! s:apply_layout_(info, type, layout)

        " Iterate through each item in our layout in order to extract the window
        " information for each id that's stored.
        for item in a:layout
            let l:layout_t = item[0]

            " If our item type is a column or a row, then we're going to need to
            " treat the items as a layout and recurse into it. For safety, we will
            " also verify that it's of the correct type.
            if match(['row', 'col'], '^' . l:layout_t . '$') >= 0
                call assert_equal(type(item[1]), v:t_list)
                call s:apply_layout_(a:info, l:layout_t, item[1])
                continue
            endif

            " Otherwise this should be a leaf and will actually be responsible for
            " creating and formatting the window at our current point in the layout.
            call assert_equal(l:layout_t, 'leaf')
            call assert_equal(type(item[1]), v:t_number)
            let l:info = a:info[item[1]]

            " Now that we have the correct window information, we can use it to
            " split our current window with the saved buffer and dimensions. Our
            " type parameter determines whether we use the "split" or "vsplit"
            " commands which in itself chooses whether we use the width or height.
            if a:type == 'col'
                let [N, split_cmd] = [l:info['height'], 'split']
            elseif a:type == 'row'
                let [N, split_cmd] = [l:info['width'], 'vsplit']
            else
                throw printf('E474: Invalid argument; not sure how to handle unknown layout type: %s', a:type)
            endif

            " Now we can actually split out our window. First store the command
            " that selects the correct buffer, and then use it when doing the split.
            let switch_buffer = printf('buffer %d', l:info['bufnr'])
            execute printf('%d%s +%s', N, split_cmd, fnameescape(switch_buffer))
        endfor
    endfunction

    function! s:apply_layout(info, layout)
        let [layout_t, items] = a:layout

        " Grab the information for our current window so that we know how to
        " switch back to it after applying the layout.
        let l:tabnr = tabpagenr()
        let l:current = tabpagewinnr(l:tabnr)
        let l:current_info = getwininfo()

        " Now we grab all of the windows for the current tab. This is because
        " when we apply our layout, all of the splitting is going to happen
        " via the currently selected window and we're going to need to use
        " this list in order to know which windows we'll need to close after
        " we apply the new layout.
        let l:windows = []
        for info in l:current_info
            if info['tabnr'] == l:tabnr
                let l:windows = add(l:windows, info['winnr'])
            endif
        endfor

        " Now we can apply our layout to the current tab by calling our
        " recursive case using our parameters. Afterwards, we can just
        " iterate through the window numbers we saved, and close them
        " one-by-one.
        call s:apply_layout_(a:info, layout_t, items)

        for winnr in l:windows
            execute printf('%dclose', winnr)
        endfor

        " Before we return, we now can switch back to the window that
        " was previously in focus.
        execute printf('%dwincmd w', l:current)

        " collects the dimensions of each window in the tab
        ":let cmd = winrestcmd()
        ":{winnr}resize {size}, :vertical :{winnr}resize {size}
    endfunction

    function! SaveLayout(tabnr)
        let l:nr = a:tabnr

        " Figure out which tabinfo is ours, and verify the tabinfo matches.
        for info in gettabinfo()
            if info['tabnr'] == l:nr
                break
            endif
        endfor
        if info['tabnr'] != l:nr
            throw printf('E92: Unable to find information on current tab; tab number is not listed in tab information: %d', tabpagenr())
        endif
        let l:tabinfo = info

        " Iterate through all of the window information, and grab all the
        " windows for the current tab. Afterwards we pivot this list into
        " a dictionary using the window id as its key. This is because the
        " layout uses the window id which is unique per vim instance.
        let items = []
        for info in getwininfo()
            if info['tabnr'] == l:tabinfo['tabnr']
                let items = add(items, info)
            endif
        endfor

        let l:windowinfo = {}
        for item in items
            let id = item['winid']
            let l:windowinfo[id] = item
        endfor

        " As a sanity check, we'll walk through the window ids in our
        " tabinfo and verify that each id is within our window info.
        for id in l:tabinfo['windows']
            let ok = exists('l:windowinfo[id]')
            call assert_true(ok, printf('W14: Unable to store window information for tab %d; window id was not found: %d', l:tabinfo['tabnr'], id))
        endfor

        " Now we have our tab information and window information for the
        " tab that we can return. We also need the actual layout, so we'll
        " include that in our result too.
        let l:layout = winlayout(l:tabinfo['tabnr'])
        return [l:windowinfo, l:layout]
    endfunction

    function! RestoreLayout(tabnr, state)
        let l:nr = a:tabnr
        let [l:windowinfo, l:layout] = a:state

        " We need to select the tab the user wants to restore the given
        " state over, but first we save our current window id and then
        " select the tab the layout is being restored to.
        let [l:ctab, l:cwin] = [tabpagenr(), winnr()]
        execute printf('%dtabnext', l:nr)

        " Now that we're at the right place and we've saved the old place,
        " we need to apply the layout.
        if !s:apply_layout(l:windowinfo, l:layout)
            throw printf('W14: Unable to apply layout to tab: %d', l:nr)
        endif

        " Afterwards, we can just jump back to the tabnumber and window id.
        execute printf('%dtabnext', l:ctab)
        execute printf('%dwincmd w', l:cwin)
    endfunction

    " Execute a normal mode command for every line in a visual mode
    " selection. This takes care to honor the visually-selected column.
    function! VisualNormalCommand(command)
        let [l:cleft, l:cright] = [col("'<") - 1, col("'>") - 1]
        let [l:left, l:right] = [min([l:cleft, l:cright]), max([l:cleft, l:cright])]
        let [l:top, l:bottom] = [line("'<"), line("'>")]
        if l:cleft > 0 && l:cleft == l:cright
            exec printf("%d,%dnormal 0%dl%s", l:top, l:bottom, l:cleft, a:command)
        elseif l:cleft > 0 && l:cleft < l:cright
            exec printf("%d,%dnormal 0%dl%dx%s", l:top, l:bottom, l:cleft, l:cright - l:cleft, a:command)
        elseif l:cleft == l:cright
            exec printf("%d,%dnormal 0%s", l:top, l:bottom, a:command)
        else
            exec printf("%d,%dnormal 0%dx%s", l:top, l:bottom, l:cright - l:cleft, a:command)
        endif
    endfunction

    "" allow for window zoom/unzoom in the current tab
    function! s:toggle_zoom(state)
        let l:tabnr = tabpagenr()

        " If we currently have a zoom state, then we need to restore
        " what the user has given us.
        if exists("a:state[l:tabnr]")
            let l:state = remove(a:state, l:tabnr)

            " All we need to do is take the popped state, and then restore
            " the layout to its tab.
            call RestoreLayout(l:tabnr, l:state)

        " Otherwise we save our current window state, and then zoom
        " in on the current window.
        else
            " Grab the layout for the current tab number.
            let l:nr = l:tabnr
            let l:state = SaveLayout(l:nr)

            " Now we just need to push our window information and the layout
            " into our state parameter keyed by the tab number.
            if !exists('a:state[l:nr]') | let a:state[l:nr] = [] | endif
            let a:state[l:nr] = add(a:state[l:nr], l:state)
        endif
    endfunction

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
if has("eval")
    if filereadable(g:rcfilename_site)
        try
            call <SID>source_vimrc(g:rcfilename_site)
        catch
            echoerr printf('Error: unable to source user-local .vimrc : %s', g:rcfilename_site)
        endtry
    else
        if !filereadable(g:rcfilename_site) | echohl WarningMsg | echomsg printf('Warning: user-local .vimrc does not exist : %s', g:rcfilename_site) | echohl None | endif
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

""" plugin manager configuration.
if has("eval")
    let g:plug_window = '$tabnew'

    call plug#begin()
    Plug 'https://github.com/arizvisa/vim-incpy.git'
    Plug 'https://github.com/mg979/vim-visual-multi'
    Plug 'https://github.com/tpope/vim-sleuth'
    Plug 'https://github.com/tpope/vim-surround'

    " XXX: tried really fucking hard to use netrw, but it fails at creating
    "      files in the current selected directory (%) and then the difference
    "      between :Lexplore and :Vexplore doesn't always use the previous
    "      window to edit a file. pretty fucking stupid. ..
    Plug 'https://github.com/preservim/nerdtree'

    " additional text objects
    Plug 'https://github.com/wellle/targets.vim'
    Plug 'https://github.com/michaeljsmith/vim-indent-object'
    Plug 'https://github.com/jeetsukumaran/vim-indentwise'
    Plug 'https://github.com/coderifous/textobj-word-column.vim'

    " miscellaneous
    Plug 'https://github.com/lpinilla/vim-codepainter'
    call plug#end()

    " check if the plugins have been installed, and install them if not.
    if !exists("g:plug_home")
        echohl WarningMsg | echomsg "Unable to determine the plugin home directory (junegunn/vim-plug might not be installed correctly)." | echohl None

    elseif !isdirectory(g:plug_home)
        echohl ErrorMsg | echomsg printf("Plugin directory has not yet been created at %s.", g:plug_home) | echohl None
        echohl WarningMsg | echomsg printf("The following %d plugin%s %s been configured:", len(g:plugs), (len(g:plugs) == 1)? "" : "s", (len(g:plugs) == 1)? "has" : "have") | echohl None
        for plugin in keys(g:plugs)
            echomsg printf("%s : %s", plugin, g:plugs[plugin]['uri'])
        endfor

        " FIXME: it would be better if this used a preview or quickfix window (rather than a tab).
        echohl WarningMsg | echomsg printf("Proceeding to install %splugin%s into directory at %s.", (len(g:plugs) == 1)? "" : printf("%d ", len(g:plugs)), (len(g:plugs) == 1)? "" : "s", g:plug_home) | echohl None
        PlugInstall
    endif
endif

""" configuration for specific plugins
if has("eval")
    let g:sleuth_no_filetype_indent_on = 1
    let g:VM_add_cursor_at_pos_no_mappings = 1
    let g:NERDTreeMapHelp = ''

    " https://gist.github.com/wellle/9289224?permalink_comment_id=1182925
    function! s:TargetsAppend(type, ...)
        normal! `]
        if a:type == 'char'
            call feedkeys("a", 'n')
        else
            call feedkeys("o", 'n')
        endif
    endfunction
    function! s:TargetsInsert(type, ...)
        normal! `[
        if a:type == 'char'
            call feedkeys("i", 'n')
        else
            call feedkeys("O", 'n')
        endif
    endfunction
    nnoremap <silent> <Leader>a <Cmd>set opfunc=<SID>TargetsAppend<CR>g@
    nnoremap <silent> <Leader>i <Cmd>set opfunc=<SID>TargetsInsert<CR>g@
endif
