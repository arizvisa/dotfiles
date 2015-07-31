" cscope w/ custom .vimrc files
" by siflus@gmail.com
"
" more often than anything when I'm auditting code, people use
" different settings than I do. so my ts=4 will fuck up when I'm viewing
" the code for those nasty gnu projects.
" applications also tend to have multiple directories. which means as I'm
" navigating the project at the shell, and editting a file, I have to csc
" add the cscope db for the project everytime I run vim
"
" to solve these problems, this script does 2 things.
" [1] it reads from the environment 2 vars. CSCOPE_DB and CSCOPE_DIR
" [2] it sources a .vimrc from multiple locations
"
" CSCOPE_DB is the path to the cscope.out file you want to use
" CSCOPE_DIR is the base directory that the cscope.out file resides in
"
" if CSCOPE_DIR isn't set, the directory is ripped from the path to CSCOPE_DB
" at this point, it then sources the .vimrc at the same location as CSCOPE_DB
" and then looks in the $CWD for a .vimrc to source as well.
"

let s:rcfilename = ".vimrc"
let s:csfilename = "cscope"

if has("cscope")
    " follow symbolic links to return a 'normalized' path
    function! s:namei_directory(dir)
        let wd=resolve(simplify(a:dir))
        if !isdirectory(a:dir)
            throw printf("%s is not a directory", wd)
        endif

        let prevwd=getcwd()
        execute printf("chdir %s", fnameescape(wd))
        let result=getcwd()
        execute printf("chdir %s", fnameescape(prevwd))
        return result
    endfunction

    " source dir/.vimrc if its not in $HOME
    function! s:source(dir)
        let realdir=s:namei_directory(a:dir)
        let sourcefile=fnameescape(printf("%s/%s", realdir, s:rcfilename))
        if (realdir !=# s:namei_directory($HOME)) && (filereadable(sourcefile))
            execute printf("source %s", sourcefile)
        endif
    endfunction

    " source a glob of files
    function! s:globsource(path)
        let files=glob(a:path)
        while files != ""
            let next=stridx(files, "\n")
            if next == -1
                let next=strlen(files)
            endif

            if filereadable(strpart(files, 0, next))
                execute printf("source %s", fnameescape(strpart(files, 0, next)))
            endif

            let files=strpart(files, next+1)
        endwhile
    endfunction

    function! s:which(program)
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
    let cscope_dir=$CSCOPE_DIR

    " if db wasn't specified check current dir for cscope.out
    if empty(cscope_db) && filereadable("./cscope.out")
        let cscope_db=getcwd()."/cscope.out"
    endif

    " if !dir, rip it out of cscope_db
    if empty(cscope_dir)
        let cscope_dir=strpart(cscope_db, 0, strridx(cscope_db, "/"))
    endif

    " strip final slash from cscope_dir jic
    if strridx(cscope_dir, "/") == strlen(cscope_dir)-1
        let cscope_dir=strpart(cscope_dir, 0, strlen(cscope_dir)-1)
    endif

    set nocscopeverbose
    if !empty(cscope_dir) && !isdirectory(cscope_dir)
        echoerr printf("plugin/cscope.vim : cscope_dir=\"%s\" : Is not a valid directory", cscope_dir)
    elseif !empty(cscope_dir) && !empty(cscope_db)
        call s:source(cscope_dir)
        execute printf("cscope add %s %s", fnameescape(cscope_db), fnameescape(cscope_dir))
    endif
    set cscopeverbose

    " 'normal-mode' map
    augroup cscope
        autocmd!
        autocmd BufEnter,BufRead,BufNewFile *.c,*.h,*.cc,*.cpp,*.hh call s:map_cscope()
"        autocmd BufLeave *.c,*.h call s:unmap_cscope()
    augroup end

    " source $CWD/.vimrc
    if (getcwd() !=# cscope_dir)
        call s:source(getcwd())
    endif
endif

