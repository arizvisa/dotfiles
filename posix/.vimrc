""" general vim options (-eval)
set nocp
set encoding=utf-8
set fileencoding=utf-8
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
    filetype plugin on

    " if you need your editor to automatically insert a comment leader
    " while you're commenting, then you're seriously a real fucking idiot.
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

""" useful key mappings

    "" bring shift-tab back to life. we don't bother with <Tab> because it
    "" seems to interfere with jumplist navigation (<C-i> and <C-o>)...
    inoremap <S-Tab> <C-d>
    vnoremap <S-Tab> <
    nnoremap <S-Tab> <<

    " <Tab> doesn't mean anything in visual-mode, so we can use it.
    "inoremap <Tab> <Tab>
    vnoremap <Tab> >
    "nnoremap <Tab> >>
    nnoremap gs <Cmd>echomsg SyntaxIds('.')<C-M>

    "" these mappings are just for copying the current location and some lines
    "" into the default register, current selection, or clipboard.

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
            endif
            return join([""] + l:items + [""], "\n")
        endfunction

        "" copy current path
        nnoremap <silent> <Leader>cp :let @"=<SID>normalpath(expand('%:p'))<CR>:let @*=@"<CR>
        nnoremap <silent> <Leader>cp+ :let @"=<SID>normalpath(expand('%:p'))<CR>:let @+=@"<CR>

        "" copy current filename
        nnoremap <silent> <Leader>cf :let @"=<SID>normalpath(expand('%:~'))<CR>:let @*=@"<CR>
        nnoremap <silent> <Leader>cf+ :let @"=<SID>normalpath(expand('%:~'))<CR>:let @+=@"<CR>

        "" copy current location and any lines if a range or selection is given
        noremap <silent> <Leader>. :<C-U>let @"=<SID>normalpath(expand('%:.')) . ':' . <SID>normallines(v:count) . <SID>normaltext(v:count)<CR>:let @*=@"<CR>
        noremap <silent> <Leader>.+ :<C-U>let @"=<SID>normalpath(expand('%:.')) . ':' . <SID>normallines(v:count) . <SID>normaltext(v:count)<CR>:let @+=@"<CR>
        xnoremap <silent> <Leader>. :<C-U>let @"=<SID>normalpath(expand('%:.')) . ':' . <SID>visuallines() . <SID>visualtext(visualmode())<CR>:let @*=@"<CR>
        xnoremap <silent> <Leader>.+ :<C-U>let @"=<SID>normalpath(expand('%:.')) . ':' . <SID>visuallines() . <SID>visualtext(visualmode())<CR>:let @+=@"<CR>

    unlet g:mapleader

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

""" autocommand configuration
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
