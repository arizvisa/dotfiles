" cscope w/ custom .vimrc files
" by salc@gmail.com
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
" CSCOPE_DB is the paths to each cscope.out file you want to use.
" if the variable isn't specified, the current directory is checked

let s:rcfilename = ".vimrc"
let s:csfilename = "cscope"
let s:pathsep = (!has("unix") && &shellslash)? '\' : '/'

if has("cscope")
    function! s:which(program)
        let sep = has("unix")? ':' : ';'
        let pathsep = (has("unix") || &shellslash)? '/' : '\'
        for p in split($PATH, sep)
            let path = join([substitute(p, s:pathsep, pathsep, 'g'), a:program], pathsep)
            if executable(path)
                return path
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

    function! s:map_cscope()
        nmap <buffer> <C-_>c :cscope find c <C-R>=expand("<cword>")<CR><CR>
        nmap <buffer> <C-_>d :cscope find d <C-R>=expand("<cword>")<CR><CR>
        nmap <buffer> <C-_>e :cscope find e <C-R>=expand("<cword>")<CR><CR>
        nmap <buffer> <C-_>f :cscope find f <C-R>=expand("<cword>")<CR><CR>
        nmap <buffer> <C-_>g :cscope find g <C-R>=expand("<cword>")<CR><CR>
        nmap <buffer> <C-_>i :cscope find i ^<C-R>=expand("<cfile>")<CR>$<CR>
        nmap <buffer> <C-_>s :cscope find s <C-R>=expand("<cword>")<CR><CR>
        nmap <buffer> <C-_>t :cscope find t <C-R>=expand("<cword>")<CR><CR>
    endfunction

    set cscopetagorder=0
    " cheat and use `which` to find out where cscope is
    if empty(&cscopeprg)
        try
            let &cscopeprg=s:which(s:csfilename)
        catch
            let &cscopeprg=s:which(s:csfilename . ".exe")
        endtry
    endif

    let cscope_db=$CSCOPE_DB

    " if db wasn't specified check current dir for cscope.out
    if empty(cscope_db) && filereadable("cscope.out")
        let cscope_db=join([getcwd(),"cscope.out"], s:pathsep)
    endif

    " only add the autocmds to the cscope group
    augroup cscope
        " iterate through each cscope_db
        for db in split(cscope_db, ':')
            let directory=s:basedirectory(db)

            if filereadable(db)
                " if a database is available, then add the cscope_db
                set nocscopeverbose
                execute printf("cscope add %s %s", fnameescape(db), fnameescape(directory))
                set cscopeverbose

                " also add the autocmd for setting mappings and sourcing a local .vimrc
                let absolute=fnamemodify(directory, ":p")
                exec printf("autocmd BufEnter,BufRead,BufNewFile %s* if filereadable(\"%s%s\") \| source %s%s \| endif \| call s:map_cscope()", absolute, absolute, s:rcfilename, absolute, s:rcfilename)
            else
                echoerr printf("cscope database %s does not exist", db)
            endif
        endfor
    augroup end
endif

