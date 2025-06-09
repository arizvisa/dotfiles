" cscope w/ custom .vimrc files
" by arizvisa@gmail.com
"
" more often than anything when I'm auditing code, people use
" different settings than I do. so my ts=4 will fuck up when I'm viewing
" the code for those nasty gnu projects.
" applications also tend to have multiple directories. which means as I'm
" navigating the project at the shell, and editing a file, I have to csc
" add the cscope db for the project everytime I run an instance of vim.
"
" to solve these problems, this script does 2 things.
" [1] it reads a ':'-separated list of db's from an environment variable: CSCOPE_DB
" [2] it sources a .vimrc from the directory of each CSCOPE_DB
"
" CSCOPE_DB is the list of paths to each database file you want to use.
" if the variable isn't specified, the current directory is checked

" FIXME:
"        we need to overload the quickfix commands to that we can add locations
"        to the tagstack. specifically:
"
"        * `copen`
"        * `cnext` and `cprev`
"        * etc.. etc.
"

if has("cscope")
    let s:rcfilename = fnamemodify($MYVIMRC, ":t")
    let s:pathsep = (has("unix") || &shellslash)? '/' : '\'
    let s:listsep = has("unix")? ":" : ";"

    let s:cstype = v:null
    let s:cstype_description = { "gtags-cscope" : "GNU Global", "cscope" : "Cscope" }
    let s:cstype_database = { "gtags-cscope" : "GTAGS", "cscope" : "cscope.out" }

    let &cscopeverbose=1

    """ logging utilities
    function! s:information(...)
        echomsg printf("%s: [%s] %s", expand("<script>:t"), 'INFO', call("printf", a:000))
    endfunction
    function! s:warning(...)
        echohl WarningMsg
        echomsg printf("%s: [%s] %s", expand("<script>:t"), 'WARN', call("printf", a:000))
        echohl None
    endfunction
    function! s:fatal(...)
        echohl ErrorMsg
        echomsg printf("%s: [%s] %s", expand("<script>:t"), 'FATAL', call("printf", a:000))
        echohl None
    endfunction

    """ file path utilities
    function! s:which(program)
        let l:sep = has("unix")? ':' : ';'
        let l:pathsep = (has("unix") || &shellslash)? '/' : '\'
        for l:p in split($PATH, l:sep)
            let l:path = join([substitute(l:p, s:pathsep, l:pathsep, "g"), a:program], l:pathsep)
            if executable(l:path)
                return l:path
            endif
        endfor
        throw printf("Unable to locate %s in $PATH", a:program)
    endfunction

    function! s:basedirectory(path)
        if !isdirectory(a:path) && !filereadable(a:path)
            throw printf("%s does not exist", a:path)
        endif
        if isdirectory(a:path)
            return a:path
        endif
        return s:basedirectory(fnamemodify(a:path, ":h"))
    endfunction

    """ key mappings
    function! cscope#map()
        "echomsg "Enabling normal-mode maps for cscope in buffer " | echohl LineNr | echon bufnr("%") | echohl None | echon " (" | echohl MoreMsg | echon bufname("%") | echohl None | echon ")."
        if has("gui_running") && !has("win32")
            nnoremap <buffer> <C-S-_>c :lcscope find c <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-S-_>d :lcscope find d <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-S-_>e :lcscope find e <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-S-_>f :lcscope find f <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-S-_>g :lcscope find g <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-S-_>i :lcscope find i ^<C-R>=expand("<cfile>")<CR>$<CR>
            nnoremap <buffer> <C-S-_>s :lcscope find s <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-S-_>t :lcscope find t <C-R>=expand("<cword>")<CR><CR>
        else
            nnoremap <buffer> <C-_>c :lcscope find c <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-_>d :lcscope find d <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-_>e :lcscope find e <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-_>f :lcscope find f <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-_>g :lcscope find g <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-_>i :lcscope find i ^<C-R>=expand("<cfile>")<CR>$<CR>
            nnoremap <buffer> <C-_>s :lcscope find s <C-R>=expand("<cword>")<CR><CR>
            nnoremap <buffer> <C-_>t :lcscope find t <C-R>=expand("<cword>")<CR><CR>
        endif
    endfunction

    function! cscope#unmap()
        "echomsg "Disabling normal-mode maps for cscope in buffer " | echohl LineNr | echon bufnr("%") | echohl None | echon " (" | echohl MoreMsg | echon bufname("%") | echohl None | echon ")."
        if has("gui_running") && !has("win32")
            silent! nunmap <buffer> <C-S-_>c
            silent! nunmap <buffer> <C-S-_>d
            silent! nunmap <buffer> <C-S-_>e
            silent! nunmap <buffer> <C-S-_>f
            silent! nunmap <buffer> <C-S-_>g
            silent! nunmap <buffer> <C-S-_>i
            silent! nunmap <buffer> <C-S-_>s
            silent! nunmap <buffer> <C-S-_>t
        else
            silent! nunmap <buffer> <C-_>c
            silent! nunmap <buffer> <C-_>d
            silent! nunmap <buffer> <C-_>e
            silent! nunmap <buffer> <C-_>f
            silent! nunmap <buffer> <C-_>g
            silent! nunmap <buffer> <C-_>i
            silent! nunmap <buffer> <C-_>s
            silent! nunmap <buffer> <C-_>t
        endif
    endfunction

    " re-trigger autocmd events for the current buffer
    function! s:trigger_buffer_events(path)
        let l:argpath=isdirectory(a:path)? join([a:path, s:csdatabase], s:pathsep) : a:path
        let l:directory=fnamemodify(s:basedirectory(l:argpath), ":p")
        let l:path=fnamemodify(l:argpath, printf(":p:gs?%s?/?", s:pathsep))
        let l:base=fnamemodify(l:directory, printf(":p:gs?%s?/?", s:pathsep))
        exec printf("doautocmd cscope BufEnter %s**", l:base)
    endfunction

    """ cscope-related utilities
    function! s:add_cscope(path)
        " check if we were given a directory or just a straight-up path
        if isdirectory(a:path)
            let l:argpath=join([a:path, s:csdatabase], s:pathsep)
        else
            let l:argpath=a:path
        endif

        " make sure the path we determined is readable
        if !filereadable(l:argpath)
            throw printf("File \"%s\" does not exist", l:argpath)
        endif

        " break the path into its directory (absolute) and filename components
        let l:directory=fnamemodify(s:basedirectory(l:argpath), ":p")
        let l:path=fnamemodify(l:argpath, printf(":p:gs?%s?/?", s:pathsep))

        " store the path in GTAGSROOT in order to deal with gtags-cscope which
        " doesn't take the target tag database as a parameter
        let $GTAGSROOT = fnameescape(l:directory)

        " if a database is available, then add the cscope_db
        if s:cstype == "gtags-cscope"
            " gtags-cscope apparently handles the -P prefix differently...
            execute printf("silent cscope add %s %s", fnameescape(l:path), fnameescape(fnamemodify(getcwd(), ":p:h")))
        else
            " cscope apparently needs the path prefix
            execute printf("silent cscope add %s %s", fnameescape(l:path), fnameescape(fnamemodify(l:directory, ":p:h")))
        endif
        exec printf("echomsg \"Added %s database: \" | echohl MoreMsg | echon \"%s\" | echohl None", s:csdescription, l:path)

        " add an autocmd for setting keyboard mappings when in a sub-directory
        " relative to the database, and sourcing a .vimrc in the same directory
        " if one exists
        augroup cscope
            let l:base=fnamemodify(l:directory, printf(":p:gs?%s?/?", s:pathsep))
            exec printf("autocmd BufEnter,BufRead,BufNewFile %s** call cscope#map() | if filereadable(\"%s%s\") | source %s%s | endif", l:base, l:base, s:rcfilename, l:base, s:rcfilename)
            exec printf("autocmd BufDelete %s** call cscope#unmap()", l:base)
        augroup end

        call s:trigger_buffer_events(a:path)
    endfunction

    " create a command that calls add_cscope directly
    command! -nargs=1 -complete=file AddCscope call s:add_cscope(<f-args>)

    set cscopetagorder=0

    " try and find a valid executable for cscope
    if !exists("&cscopeprg") || !filereadable(&cscopeprg)
        call s:warning("The tool specified as &cscopeprg (%s) is either undefined or not found.", &cscopeprg)

        if !exists("&cscopeprg") || empty(&cscopeprg)
            let s:csprog_types = keys(s:cstype_database)
        else
            let s:csprog_type = fnamemodify(&cscopeprg, ":t:r")
            if has_key(s:cstype_database, s:csprog_type)
                let s:csprog_types = [ s:csprog_type ] + keys(s:cstype_database)
            else
                let s:csprog_types = keys(s:cstype_database)
            endif
        endif

        call s:information("Searching for a replacement for &cscopeprg: %s", s:csprog_types)
        for s:csfilename in s:csprog_types
            let s:cscopeprg = v:null
            try
                let s:cscopeprg=s:which(s:csfilename)
            catch
                let s:cscopeprg=v:null
            endtry
            if s:cscopeprg != v:null | break | endif
        endfor

    else
        " if the user specified a valid program, then we should be able
        " to safely use it.
        let s:cscopeprg=&cscopeprg
    endif

    " now we have a valid program, lets use it to determine what database type we should be using
    try | if !empty(s:cscopeprg)
        let s:cstype = fnamemodify(s:cscopeprg, ":t:r")
        if !has_key(s:cstype_database, s:cstype)
            throw printf("Unable to determine the cscope database type for \"%s\".", s:csprog_key)
        endif

        let s:csdescription = s:cstype_description[s:cstype]
        let s:csdatabase = s:cstype_database[s:cstype]

        " let the user know if we had to figure out the right program
        if s:cscopeprg != &cscopeprg
            call s:information("Decided upon %s (%s) for navigation: %s", s:csdescription, s:cstype, s:cscopeprg)
            let &cscopeprg = s:cscopeprg
        endif
    else
        throw printf("Unable to identify a valid program for %s.", "&cscopeprg")

    " If we caught any kind of exception, we need to bail because nothing works.
    endif | catch
        call s:fatal(v:exception)
        finish
    endtry

    " check if tmpdir was defined. if not set it to something
    " because cscope requires it.
    if has("win32") && (!exists("$TMPDIR") || empty($TMPDIR))
        let $TMPDIR=$TEMP
    endif

    " pass the environment variable to a local variable
    let s:cscope_db=$CSCOPE_DB

    " if db wasn't specified check current dir for cscope.out
    if empty(s:cscope_db) && filereadable(s:csdatabase)
        let s:cscope_db=join([getcwd(), s:csdatabase], s:pathsep)
        call s:information("Found %s database in current working directory: %s", s:csdescription, s:cscope_db)
    else
        for s:db in split(s:cscope_db, s:listsep)
            call s:information("Found %s database specified in environment CSCOPE_DB: %s", s:csdescription, s:db)
        endfor
    endif

    " iterate through each cscope_db
    for s:db in split(s:cscope_db, s:listsep)
        call s:information("Loading %s database: %s", s:csdescription, s:db)

        let s:verbosity = &cscopeverbose
        let &cscopeverbose = 0
        try
            call s:add_cscope(s:db)
        catch
            call s:warning("Error loading %s database at %s -> %s", s:csdescription, s:db, v:exception)
        endtry
        let &cscopeverbose = s:verbosity
    endfor

    " if the current working directory isn't underneath the current database,
    " then warn the user about it so that they aren't surprised why their
    " queries don't work.
    if !empty(s:cscope_db)
        let is_valid_subdirectory = v:false
        for s:db in split(s:cscope_db, s:listsep)
            if stridx(getcwd(), fnamemodify(s:db, ':p:h')) == 0
                let is_valid_subdirectory = v:true
            endif
        endfor

        if ! is_valid_subdirectory
            call s:warning("Current directory is not a subdirectory of the following %s databases:", s:csdescription)
            let databases = split(s:cscope_db, s:listsep)
            for index in range(len(databases))
                let s:db = databases[index]
                call s:warning("    [%d] %s", 1 + index, s:db)
            endfor
            call s:warning("Querying from files in the current directory may produce undesired results.")
        endif
        unlet is_valid_subdirectory
    endif
endif
