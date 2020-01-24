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

if has("cscope")
    let s:rcfilename = ".vimrc"
    let s:pathsep = (has("unix") || &shellslash)? '/' : '\'
    let s:listsep = has("unix")? ":" : ";"

    let s:cstype = v:none
    let s:cstype_description = { "gtags-cscope" : "GNU Global", "cscope" : "Cscope" }
    let s:cstype_database = { "gtags-cscope" : "GTAGS", "cscope" : "cscope.out" }

    let &cscopeverbose=1

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

    function! cscope#map()
        "echomsg "Enabling normal-mode maps for cscope in buffer " | echohl LineNr | echon bufnr("%") | echohl None | echon " (" | echohl MoreMsg | echon bufname("%") | echohl None | echon ")."
        nnoremap <buffer> <C-_>c :cscope find c <C-R>=expand("<cword>")<CR><CR>
        nnoremap <buffer> <C-_>d :cscope find d <C-R>=expand("<cword>")<CR><CR>
        nnoremap <buffer> <C-_>e :cscope find e <C-R>=expand("<cword>")<CR><CR>
        nnoremap <buffer> <C-_>f :cscope find f <C-R>=expand("<cword>")<CR><CR>
        nnoremap <buffer> <C-_>g :cscope find g <C-R>=expand("<cword>")<CR><CR>
        nnoremap <buffer> <C-_>i :cscope find i ^<C-R>=expand("<cfile>")<CR>$<CR>
        nnoremap <buffer> <C-_>s :cscope find s <C-R>=expand("<cword>")<CR><CR>
        nnoremap <buffer> <C-_>t :cscope find t <C-R>=expand("<cword>")<CR><CR>
    endfunction

    function! cscope#unmap()
        "echomsg "Disabling normal-mode maps for cscope in buffer " | echohl LineNr | echon bufnr("%") | echohl None | echon " (" | echohl MoreMsg | echon bufname("%") | echohl None | echon ")."
        silent! nunmap <buffer> <C-_>c
        silent! nunmap <buffer> <C-_>d
        silent! nunmap <buffer> <C-_>e
        silent! nunmap <buffer> <C-_>f
        silent! nunmap <buffer> <C-_>g
        silent! nunmap <buffer> <C-_>i
        silent! nunmap <buffer> <C-_>s
        silent! nunmap <buffer> <C-_>t
    endfunction

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

        " break the path into its directory and filename components
        let l:directory=s:basedirectory(l:argpath)
        let l:path=fnamemodify(l:argpath, printf(":p:gs?%s?/?", s:pathsep))

        " store the path in GTAGSROOT in order to deal with gtags-cscope which
        " doesn't take the target tag database as a parameter
        let $GTAGSROOT = fnameescape(l:directory)

        " if a database is available, then add the cscope_db
        execute printf("silent cscope add %s %s", fnameescape(l:path), fnameescape(fnamemodify(l:directory, ":p:h")))
        exec printf("echomsg \"Added %s database: \" | echohl MoreMsg | echon \"%s\" | echohl None", s:csdescription, l:path)

        " add an autocmd for setting keyboard mappings when in a sub-directory
        " relative to the database, and sourcing a .vimrc in the same directory
        " if one exists
        augroup cscope
            let l:base=fnamemodify(l:directory, printf(":p:gs?%s?/?", s:pathsep))
            exec printf("autocmd BufEnter,BufRead,BufNewFile %s* call cscope#map() | if filereadable(\"%s%s\") | source %s%s | endif", l:base, l:base, s:rcfilename, l:base, s:rcfilename)
            exec printf("autocmd BufDelete %s* call cscope#unmap()", l:base)
        augroup end
    endfunction

    " create a command that calls add_cscope directly
    command! -nargs=1 -complete=file AddCscope call s:add_cscope(<f-args>)

    set cscopetagorder=0

    " try and find a valid executable for cscope
    if !exists("&cscopeprg") || !filereadable(&cscopeprg)
        echoerr printf("The tool specified as &cscopeprg (%s) is either undefined or not found.", &cscopeprg)

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

        echomsg printf("Searching for a replacement for &cscopeprg: %s", s:csprog_types)
        for s:csfilename in s:csprog_types
            let s:cscopeprg = v:none
            try
                let s:cscopeprg=s:which(s:csfilename)
            catch
                let s:cscopeprg=v:none
            endtry
            if s:cscopeprg != v:none | break | endif
        endfor

    else
        " if the user specified a valid program, then we should be able
        " to safely use it.
        let s:cscopeprg=&cscopeprg
    endif

    " now we have a valid program, lets use it to determine what database type we should be using
    if !empty(s:cscopeprg)
        let s:cstype = fnamemodify(s:cscopeprg, ":t:r")
        if !has_key(s:cstype_database, s:cstype)
            throw printf("Unable to determine the cscope database type for \"%s\".", s:csprog_key)
        endif

        let s:csdescription = s:cstype_description[s:cstype]
        let s:csdatabase = s:cstype_database[s:cstype]

        " let the user know if we had to figure out the right program
        if s:cscopeprg != &cscopeprg
            echomsg printf("Decided upon a %s (%s) database for navigation: %s", s:csdescription, s:cstype, s:cscopeprg)
        endif
    else
        throw printf("Unable to identify a valid program for %s.", "&cscopeprg")
    endif

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
        echomsg printf("Found %s database in current working directory: %s", s:csdescription, s:cscope_db)
    else
        for s:db in split(s:cscope_db, s:listsep)
            echomsg printf("Found %s database specified in environment CSCOPE_DB: %s", s:csdescription, s:db)
        endfor
    endif

    " iterate through each cscope_db
    for s:db in split(s:cscope_db, s:listsep)
        echomsg printf("Loading %s database: %s", s:csdescription, s:db)

        let s:verbosity = &cscopeverbose
        let &cscopeverbose = 0
        try
            call s:add_cscope(s:db)
        catch
            echoerr printf("Error loading %s database at %s -> %s", s:csdescription, s:db, v:exception)
        endtry
        let &cscopeverbose = s:verbosity
    endfor
endif

