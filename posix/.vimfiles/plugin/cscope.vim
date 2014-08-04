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
" this script depends on the `which` command for finding the path to cscope.
" I also included my nmap mappings because well...I'm lazy and just cut/pasted
" this from my normal .vimrc
" apologies for the sloppiness.
"

" follow symbolic links to return a 'normalized' path
function! s:namei(dir)
    let prevwd=getcwd()
    execute "chdir ".a:dir
    let r=getcwd()    
    execute "chdir ".prevwd
    return r
endfunction

" source dir/.vimrc if its not in $HOME
function! s:do_source(dir)
    if (a:dir !=# s:namei($HOME)) && (filereadable(a:dir."/.vimrc"))
        execute "source" a:dir."/.vimrc"
    endif
endfunction

" source a glob of files
function! s:do_globsource(path)
    let files=glob(a:path)
    while files != ""
        let next=stridx(files, "\n")
        if next == -1
            let next=strlen(files)
        endif

        if filereadable(strpart(files, 0, next))
            execute "source" strpart(files, 0, next)
        endif

        let files=strpart(files, next+1)
    endwhile
endfunction

" cscope phun
if has("cscope")
    set csto=0
    " XXX: all this jazz is actually to prevent vim from recursively
    "      including this file. it actuallly doesn't work for all cases.
    "      but...it works for all of mine. ;)

    " cheat and use `which` to find out where cscope is
    let cscope_location=system("which cscope")
    let &cscopeprg=substitute(cscope_location, "\n", "", "")
    unlet cscope_location

    let cscope_db=$CSCOPE_DB
    let cscope_dir=$CSCOPE_DIR

    " if db wasn't specified check current dir for cscope.out
    if cscope_db == "" && filereadable("./cscope.out")
        let cscope_db=getcwd()."/cscope.out"
    endif

    " if !dir, rip it out of cscope_db
    if cscope_dir == ""
        let cscope_dir=strpart(cscope_db, 0, strridx(cscope_db, "/"))
    endif

    " strip final slash from cscope_dir jic
    if strridx(cscope_dir, "/") == strlen(cscope_dir)-1
        let cscope_dir=strpart(cscope_dir, 0, strlen(cscope_dir)-1)
    endif

    set nocsverb
    if (cscope_db != "") && (cscope_dir != "")
        execute "cscope add" cscope_db cscope_dir
        call s:do_source(cscope_dir)
    endif
    set csverb

    " 'normal-mode' map
    nmap <C-_>c :cscope find c <C-R>=expand("<cword>")<CR><CR>
    nmap <C-_>d :cscope find d <C-R>=expand("<cword>")<CR><CR>
    nmap <C-_>e :cscope find e <C-R>=expand("<cword>")<CR><CR>
    nmap <C-_>f :cscope find f <C-R>=expand("<cword>")<CR><CR>
    nmap <C-_>g :cscope find g <C-R>=expand("<cword>")<CR><CR>
    nmap <C-_>i :cscope find i ^<C-R>=expand("<cfile>")<CR>$<CR>
    nmap <C-_>s :cscope find s <C-R>=expand("<cword>")<CR><CR>
    nmap <C-_>t :cscope find t <C-R>=expand("<cword>")<CR><CR>

    " source $CWD/.vimrc
    if (getcwd() !=# cscope_dir)
        call s:do_source(getcwd())
    endif

endif

