if version < 600
    syntax clear
elseif exists('b:current_syntax')
    finish
endif

let s:cpoptions_save = &cpoptions
set cpoptions&vim

syn case match
setlocal iskeyword&vim

let &l:iskeyword='@,48-57,192-255,#,%,-'

syntax keyword extensibleKeyword let if for while fn
syntax keyword extensibleBuiltin break cd eval exec match
syntax keyword extensibleBuiltin false true
syntax keyword extensibleBuiltin fork if limit newpgrp result return throw time true umask
syntax keyword extensibleBuiltin unwind-protect var vars wait whatis while %read
syntax keyword extensibleHookable %and %append %background %backquote %batch-loop %close
syntax keyword extensibleHookable %count %create %dup %eval-noprint %eval-print %exec-failure
syntax keyword extensibleHookable %exit-on-false %flatten %here %home %interactive-loop
syntax keyword extensibleHookable %noeval-noprint %noeval-print %not %one %open %open-append
syntax keyword extensibleHookable %open-create %open-write %openfile %or %parse %pathsearch
syntax keyword extensibleHookable %pipe %prompt %readfrom %seq %whatis %writeto
syntax keyword extensibleUtility %apids %fsplit %is-interactive %newfd %run %split %var
syntax keyword extensiblePrimitive access forever throw catch fork umask
syntax keyword extensiblePrimitive echo if wait exec newpgrp exit result
syntax keyword extensiblePrimitive apids here read close home run count newfd seq dup
syntax keyword extensiblePrimitive openfile split flatten parse var fsplit pipe whatis
syntax keyword extensiblePrimitive batchloop exitonfalse isinteractive
syntax keyword extensiblePrimitive sethistory setnoexport setsignals
syntax keyword extensiblePrimitive execfailure limit readfrom time
syntax keyword extensiblePrimitive %exec-failure limit %readfrom %writeto
syntax keyword extensiblePrimitive $&collect $&noreturn $&primitives $&version

" TODO: don't use numerical matches, instead opting for clusters and such.
" TODO: the following patterns should be highlighted: <={...}, !, ^
" TODO: would be nice to match variables inside `{...} expressions.
" TODO: would be nice to match variables inside $var(blah ... blah) indexing.
" TODO: would be nice to match symbols (-, +, /, *, %, &, |, &&, ||) as operators.

syntax match extensibleComment '#.*'
syntax match extensibleStringSingle +'[^']*'+
syntax match extensibleStringDouble +"[^"]*"+
syntax match extensibleVariableCommand1 '`{[^}]*}'
syntax match extensibleVariableCommand2 '`\<[0-9A-Za-z_]\+\>'
"syntax match extensibleVariableResult '<={[^}]*}'
"syntax match extensibleVariableReference1 '\<-[0-9A-Za-z_\-]\+\>'
syntax match extensibleVariableReference2 '\$#\?[0-9A-Za-z_\-]\+'
syntax match extensibleVariableReference3 '\$\*'
syntax match extensibleNumber1 '\<[1-9][0-9]*\>'
syntax match extensibleNumber2 '\<[0-9]\>'
syntax match extensibleCharacter '\\0[0-9]\{2\}'
syntax match extensibleCharacter +\\[;'"]+
syntax match extensibleSpecial1 '\.\{3\}'
syntax match extensibleSpecial2 '\~'
syntax match extensibleSpecial3 '\~\~'
syntax match extensibleSpecial4 '\*'

highlight link extensibleKeyword Operator
highlight link extensibleBuiltin Statement
highlight link extensibleHookable Keyword
highlight link extensibleUtility Keyword
highlight link extensiblePrimitive Special
highlight link extensibleComment Comment
highlight link extensibleVariable Tag
highlight link extensibleStringSingle String
highlight link extensibleStringDouble String
highlight link extensibleVariableCommand1 Identifier
highlight link extensibleVariableCommand2 Identifier
"highlight link extensibleVariableResult Normal
"highlight link extensibleVariableReference1 Identifier
highlight link extensibleVariableReference2 Identifier
highlight link extensibleVariableReference3 Identifier
highlight link extensibleNumber1 Number
highlight link extensibleNumber2 Number
highlight link extensibleCharacter String
highlight link extensibleSpecial1 Special
highlight link extensibleSpecial2 Special
highlight link extensibleSpecial3 Operator
highlight link extensibleSpecial4 Special

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save
