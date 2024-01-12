if exists("b:current_syntax")
    finish
endif

let s:cpoptions_save = &cpoptions
set cpoptions&vim

""" global settings
syntax case match
syntax sync maxlines=128

""" character classes
let s:char_type_UC = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_'
let s:char_type_LC = 'abcdefghijklmnopqrstuvwxyz'
let s:char_type_DI = '0123456789'
let s:char_type_PU = '(),[]{|}'
let s:char_type_SY = '#$&*+-./:<=>?@\^~'
let s:char_type_SP = "\x09\x0a\x0b\x0c\x0d\x20"
let s:char_type_AC = s:char_type_UC + s:char_type_LC

""" tables used for symbol conversion
let s:prologSymbols = {
\   '.': '\.', '(': '(', ')': ')', ':': ':', '!': '!', '+': '+', '-': '-', '<': '\<', '=': '=', '>': '\>', '&': '&', '*': '*',
\   '/': '/', ';': ';', '?': '?', '[': '\[', ']': '\]', '^': '\^', '{': '{', '|': '|', '}': '}', '~': '\~', '\': '\\', '$' : '$'
\ }

let s:prologSymbolPairs_open =  {'(' : ')', '[' : ']', '{' : '}'}
let s:prologSymbolPairs_close = {')' : '(', ']': '[', '}' : '{'}
let s:prologSymbolPairs = extendnew(s:prologSymbolPairs_open, s:prologSymbolPairs_close )

" add all the operators including some of the clp(fd) ones.
let s:operators = [
\    '\*\?->', '|',
\    '<',
\    '=',
\    '=\.\.',
\    '=@=', '\\=@=',
\    '=:=',
\    '=<',
\    '==',
\    '=\\=',
\    '>',
\    '>=',
\    '@<', '@=<', '@>', '@>=',
\    '\\=',
\    '\\==',
\    'as', 'is', 'of', 'in', '\<ins\>', '>:<', ':<',
\    '\\+',
\    '+', '-', '/\\', '\\/', 'xor',
\    '?',
\    '\*', '/', '//', 'div', 'rdiv', '<<', '>>', 'mod', 'rem',
\    '\*\*',
\    '\\',
\    '[[:digit:]]\@!\.[[:digit:]]\@!',
\] + [
\    '#/\\',
\    '#<',
\    '#<==',
\    '#<===>',
\    '#=',
\    '#=<',
\    '#==>',
\    '#>',
\    '#>=',
\    '#\\',
\    '#\\',
\    '#\\/',
\    '#\\=',
\]

""" basic tools for acting on symbols
function! s:make_binary_patterns(key, symbols)
    let escaped_groupings = join(map(keys(s:prologSymbolPairs), 's:prologSymbols[v:val]'), "")
    return [
\       '[_[:alnum:][:space:]' .. escaped_groupings .. ']\@!\zs' .. a:symbols .. '\ze\_[_[:alnum:][:space:]' .. escaped_groupings .. ']',
\       '[_[:alnum:][:space:]' .. escaped_groupings .. ']\@=\zs' .. a:symbols .. '\ze\_[_[:alnum:][:space:]' .. escaped_groupings .. ']'
\   ]
endfunction

function! s:make_nonunary_patterns(key, symbol)
    let escaped_groupings = join(map(keys(s:prologSymbolPairs), 's:prologSymbols[v:val]'), "")
    return [
"\       '[[:alnum:]' .. escaped_groupings .. ']\@!\zs' .. a:symbol .. '\ze\_[[:alpha:][:space:]' .. escaped_groupings .. ']',
\       '\>[[:space:]]*\zs' .. a:symbol .. '\ze\_[_[:alpha:][:space:]' .. escaped_groupings .. ']',
\       '[' .. escaped_groupings .. '][[:space:]]*\zs' .. a:symbol .. '\ze\_[_[:alpha:][:space:]' .. escaped_groupings .. ']',
\       '\>' ..       '\zs' .. a:symbol .. '\ze\_[[:digit:][:space:]' .. escaped_groupings .. ']',
\                     '\zs' .. a:symbol .. '\ze[-+][[:digit:]]',
\   ]
endfunction

function! s:exclude_list(items, excluded)
    let result = []
    for value in a:items
        if index(a:excluded, value) < 0 | let result = add(result, value) | endif
    endfor
    return result
endfunction

function! s:exclude_dict(dict, keys)
    let result = {}
    for k in keys(a:dict)
        if index(a:keys, k) < 0 | let result[k] = a:dict[k] | endif
    endfor
    return result
endfunction

function! s:slice_dict(dict, keys)
    let result = []
    for k in keys(a:dict)
        if index(a:keys, k) >= 0 | add(result, a:dict[k]) | endif
    endfor
    return result
endfunction

""" <mustafa-voice>it starts...</mustafa-voice>
syn keyword prologBuiltin true false repeat phrase call_dcg op catch throw catch_with_backtrace
syn keyword prologBuiltin bagof findall findnsols setof forall dynamic compile_predicates
syn keyword prologBuiltin current_format_predicate format format_predicate swritef writef
syn keyword prologBuiltin is_list keysort length memberchk msort predsort sort
syn keyword prologBuiltin abs acos acosh asin asinh atan atan2 atanh between bounded_number ceil ceiling cmpr copysign cos cosh denominator div divmod erf erfc eval exp float float_class float_fractional_part float_integer_part float_parts floor getbit integer lgamma log log10 lsb max maxr min minr msb nexttoward nth_integer_root_and_remainder numerator plus popcount powm random rational rationalize round roundtoward sign sin sinh sqrt succ tan tanh truncate
syn keyword prologBuiltin char_conversion char_type code_type collation_key current_char_conversion downcase_atom locale_sort normalize_space upcase_atom
syn keyword prologBuiltin current_locale locale_create locale_destroy locale_property set_locale
syn keyword prologBuiltin atom_chars atom_codes atom_concat atomic_concat atomic_list_concat atom_length atom_number atom_prefix atom_to_term char_code name number_chars number_codes sub_atom sub_atom_icasechk term_to_atom
syn keyword prologBuiltin arg compound_name_arguments compound_name_arity copy_term copy_term_nat duplicate_term functor is_most_general_term nb_linkarg nb_setarg nonground numbervars same_term setarg term_singletons term_variables var_number
syn keyword prologBuiltin portray print prompt prompt1 read read_clause read_term read_term_from_atom read_term_with_history write write_canonical write_length writeln writeq write_term
syn keyword prologBuiltin clause clause_property current_atom current_blob current_flag current_functor current_key current_op current_predicate dwim_predicate nth_clause predicate_property
syn keyword prologBuiltin abolish assert asserta assertz copy_predicate_clauses current_transaction current_trie erase instance is_trie recorda recorded recordz redefine_system_predicate retract retractall snapshot term_hash transaction transaction_updates trie_delete trie_destroy trie_gen trie_gen_compiled trie_insert trie_lookup trie_new trie_property trie_term trie_update variant_hash variant_sha1
syn keyword prologBuiltin apply call call_cleanup call_with_depth_limit call_with_inference_limit ignore not once setup_call_catcher_cleanup setup_call_cleanup undo
syn keyword prologBuiltin compare reset shift shift_for_copy unify_with_occurs_check subsumes_term term_subsumer unifiable
syn keyword prologBuiltin at_end_of_stream copy_stream_data fill_buffer flush_output get get0 get_byte get_char get_code get_single_char nl peek_byte peek_char peek_code peek_string put put_byte put_char put_code read_pending_chars read_pending_codes set_end_of_stream skip tab ttyflush with_tty_raw
syn keyword prologBuiltin append close collect_wd current_input current_output current_stream fast_read fast_term_serialized fast_write getwd is_stream open open_null_stream register_iri_scheme see seeing seek seen set_input set_output set_prolog_IO set_stream set_stream_position set_system_IO stream_pair stream_position_data stream_property tell telling told with_output_to
syn keyword prologBuiltin acyclic_term atom atomic blob callable compound cyclic_term float ground integer nonvar number rational string var
syn keyword prologBuiltin noprotocol protocol protocola protocolling
syn keyword prologBuiltin absolute_file_name access_file chdir delete_directory delete_file directory_files exists_directory exists_file expand_file_name file_base_name file_directory_name file_name_extension is_absolute_file_name make_directory prolog_to_os_filename read_link rename_file same_file size_file time_file tmp_file tmp_file_stream working_directory
syn keyword prologBuiltin getenv setenv setlocale shell unsetenv
syn keyword prologBuiltin date date_time_stamp date_time_value day_of_the_week format_time get_time parse_time stamp_date_time time
syn keyword prologBuiltin apple_current_locale_identifier win_add_dll_directory win_exec win_folder win_get_user_preferred_ui_languages win_process_modules win_registry_get_value win_remove_dll_directory win_shell
syn keyword prologBuiltin window_title win_has_menu win_insert_menu win_insert_menu_item win_window_color win_window_pos
syn keyword prologBuiltin close_dde_conversation dde_current_connection dde_current_service dde_execute dde_poke dde_register_service dde_request dde_unregister_service open_dde_conversation
syn keyword prologBuiltin b_getval b_setval nb_current nb_delete nb_getval nb_linkval nb_setval
syn keyword prologBuiltin at_halt cancel_halt consult encoding ensure_loaded exists_source expand_file_search_path file_search_path include initialization initialize library_directory load_files make prolog_file_type prolog_load_context require source_file source_file_property source_location unload_file
syn keyword prologBuiltin compile_aux_clauses dcg_translate_rule expand_goal expand_term goal_expansion qcompile term_expansion var_property
syn keyword prologBuiltin current_signal on_signal prolog_alert_signal
syn keyword prologBuiltin byte_count character_count line_count line_position wait_for_input
syn keyword prologBuiltin set_random random_property current_arithmetic_function
syn keyword prologBuiltin tty_get_capability tty_goto tty_put tty_size
syn keyword prologBuiltin dwim_match sleep wildcard_match
highlight link prologBuiltin prologKeyword

syn keyword prologTopLevel abort break expand_answer expand_query halt prolog
syn keyword prologTopLevel edit prolog_edit:edit_command prolog_edit:edit_source prolog_edit:load prolog_edit:locate
syn keyword prologTopLevel message_hook message_property message_to_string print_message print_message_lines prolog:message_line_element prolog:message_prefix_hook thread_message_hook version
syn keyword prologTopLevel debug debugging leash nodebug nospy nospyall notrace spy style_check trace tracing unknown visible
syn keyword prologTopLevel gdebug gspy gtrace guitracer noguitracer
syn keyword prologTopLevel profile profile_data profile_procedure_data statistics show_profile
syn keyword prologTopLevel garbage_collect garbage_collect_atoms garbage_collect_clauses malloc_property prolog_stack_property set_malloc set_prolog_gc_thread set_prolog_stack thread_idle trim_heap trim_stacks
highlight link prologTopLevel prologSpecial

syn keyword prologExtension atomics_to_string atom_string get_string_code number_string open_string read_string split_string string_bytes string_chars string_code string_codes string_concat string_length string_lower string_upper sub_string term_string text_to_string
syn keyword prologExtension b_set_dict del_dict dict_create dict_pairs get get_dict is_dict nb_link_dict nb_set_dict put put_dict select_dict
highlight link prologExtension prologKeyword

syn match prologLibrary '\<\w\+:\w\+\>'
syn keyword prologLibrary_lists member append append prefix select selectchk select selectchk nextto delete nth0 nth1 nth0 nth1 last proper_length same_length reverse permutation flatten clumped subseq max_member min_member max_member min_member sum_list max_list min_list numlist is_set list_to_set intersection union subset subtract memberchk
highlight link prologLibrary_lists prologLibrary
syn keyword prologLibrary_aggregate aggregate aggregate_all foreach free_variables 
highlight link prologLibrary_aggregate prologLibrary
syn keyword prologLibrary_aggregate_predicate count sum min max set bag
highlight link prologLibrary_aggregate_predicate Operator
syn keyword prologLibrary_apply convlist exclude foldl include maplist partition scanl
highlight link prologLibrary_apply prologLibrary
syn keyword prologLibrary_assoc assoc_to_keys assoc_to_list assoc_to_values del_assoc del_max_assoc del_min_assoc empty_assoc get_assoc is_assoc list_to_assoc map_assoc max_assoc min_assoc gen_assoc ord_list_to_assoc put_assoc
highlight link prologLibrary_assoc prologLibrary
syn keyword prologLibrary_dicts dict_fill dict_keys dict_size dicts_join dicts_same_keys dicts_same_tag dicts_slice dicts_to_compounds dicts_to_same_keys
highlight link prologLibrary_dicts prologLibrary
syn keyword prologLibrary_occurs contains_term contains_var free_of_term free_of_var occurrences_of_term occurrences_of_var sub_term sub_term_shared_variables sub_var
highlight link prologLibrary_occurs prologLibrary
syn keyword prologLibrary_option dict_options merge_options meta_options option select_option
highlight link prologLibrary_option prologLibrary
syn keyword prologLibrary_ordsets is_ordset list_to_ord_set ord_add_element ord_del_element ord_disjoint ord_empty ord_intersect ord_intersection ord_memberchk ord_selectchk ord_seteq ord_subset ord_subtract ord_symdiff ord_union
highlight link prologLibrary_ordsets prologLibrary
syn keyword prologLibrary_pairs group_pairs_by_key map_list_to_pairs pairs_keys pairs_keys_values pairs_values transpose_pairs
highlight link prologLibrary_pairs prologLibrary
syn keyword prologLibrary_random getrand maybe random random_between random_member random_numlist random_perm2 random_permutation random_select random_subseq randseq randset setrand
highlight link prologLibrary_random prologLibrary
syn keyword prologLibrary_rbtrees is_rbtree list_to_rbtree ord_list_to_rbtree rb_apply rb_clone rb_delete rb_del_max rb_del_min rb_empty rb_fold rb_in rb_insert rb_insert_new rb_keys rb_lookup rb_map rb_max rb_min rb_new rb_next rb_partial_map rb_previous rb_size rb_update rb_visit
highlight link prologLibrary_rbtrees prologLibrary
syn keyword prologLibrary_solution_sequences call_nth distinct group_by limit offset order_by reduced
highlight link prologLibrary_solution_sequences prologLibrary
syn keyword prologLibrary_varnumbers max_var_number numbervars varnumbers varnumbers_names
highlight link prologLibrary_varnumbers prologLibrary
syn keyword prologLibrary_simplex constraint gen_state maximize minimize objective variable_value
highlight link prologLibrary_simplex prologLibrary
syn keyword prologLibrary_yall is_lambda lambda_calls
highlight link prologLibrary_yall prologLibrary
syn keyword prologLibrary_intercept intercept intercept_all nb_intercept_all send_signal send_silent_signal
highlight link prologLibrary_intercept prologLibrary

" prolog.vim has no idea what an atom is apparently.
"syn region prologAtom start='\w' end='\>'
"syn region prologClause start='\w\+' end='\>'

" prolog.vim author seemed to fuck this one up.
"syn match prologNumber '\<\(\u\|_\)\(\w\)*\>'

" this next pattern is not greedy enough, so we split it into one that matches
" more than 1 digit, and another for just a single digit that is sitting alone.
"syn match prologNumber '\<\d\+\>'
syn match prologNumber '[-+]\=\<\d\d\+\>'
syn match prologNumber '[-+]\=\<\d\>'
syn match prologNumber '[-+]\=\<\d\+\>'

" hopefully the rest of these numbers work...
syn match prologNumber '[-+]\=\<\d\+\.\d\+\>'
syn match prologNumber '[-+]\=\<\d\+[eE][-+]\=\d\+\>'
syn match prologNumber '[-+]\=\<\d\+\.\d\+[eE][-+]\=\d\+\>'
syn match prologNumber "[-+]\=\<0'[\\]\?.\>"
syn match prologNumber '[-+]\=\<0b[0-1]\+\>'
syn match prologNumber '[-+]\=\<0o\o\+\>'
syn match prologNumber '[-+]\=\<0x\x\+\>'

" ...and we might as well add these too, because prolog is awesome.
syn match prologNumber "[-+]\=\<2'[0-1]\+\>"
syn match prologNumber "[-+]\=\<3'[0-2]\+\>"
syn match prologNumber "[-+]\=\<4'[0-3]\+\>"
syn match prologNumber "[-+]\=\<5'[0-4]\+\>"
syn match prologNumber "[-+]\=\<6'[0-5]\+\>"
syn match prologNumber "[-+]\=\<7'[0-6]\+\>"
syn match prologNumber "[-+]\=\<8'[0-7]\+\>"
syn match prologNumber "[-+]\=\<9'[0-8]\+\>"
syn match prologNumber "[-+]\=\<10'[0-9]\+\>"
syn match prologNumber "[-+]\=\<11'[0-9a]\+\>"
syn match prologNumber "[-+]\=\<12'[0-9ab]\+\>"
syn match prologNumber "[-+]\=\<13'[0-9abc]\+\>"
syn match prologNumber "[-+]\=\<14'[0-9abcd]\+\>"
syn match prologNumber "[-+]\=\<15'[0-9abcde]\+\>"
syn match prologNumber "[-+]\=\<16'[0-9abcdef]\+\>"
highlight link prologNumber Number

syn match prologVariable '\<\(\u\|_\)\(\w\)*\>'
highlight link prologVariable Identifier

" add some missing special characters
syn match prologSpecialCharacter  ";"
syn match prologSpecialCharacter  "!"
syn match prologSpecialCharacter  "[^\$]\zs\$\ze\_[^\$]"
syn match prologSpecialCharacter  "[()[:space:][:alnum:]]\zs:-\ze"
syn match prologSpecialCharacter  "[()[:space:][:alnum:]]\zs?-\ze"
syn match prologSpecialCharacter  "[()[:space:][:alnum:]]\zs-->\ze"
syn match prologSpecialCharacter  "^"
syn match prologSpecialCharacter  "|"
syn match prologSpecialCharacter  "{|}"
syn match prologSpecialCharacter  "\[|\]"
syn match prologSpecialCharacter '\<_\w*\>'

" add the '~' character used by package(func)
let without_tilde = s:exclude_dict(s:prologSymbols, ['~', '.'])
let tilde_pattern = printf('[[:space:][:alnum:]%s]\zs%s\ze\_[[:space:][:alnum:]%s]', join(values(without_tilde), ""), '\~', join(values(without_tilde), ""))
execute printf("syn match prologSpecialCharacter '%s'", tilde_pattern)
highlight link prologSpecialCharacter prologSpecial
syn match prologSpecial '^:-\s*$'

" split up all the operators by symbols or words. this way we can escape them differently.
let _operator_words = filter(copy(s:operators), 'v:val =~ "^\\a\\a*$"')
let _operator_nonunary = filter(copy(s:operators), 'v:val =~ "^[+-]$"')
let _operator_binaries = s:exclude_list(copy(s:operators), _operator_words + _operator_nonunary)

let operator_words = mapnew(_operator_words, '"\\<" .. v:val .. "\\>"')
let operator_nonunary = mapnew(_operator_nonunary, function('s:make_nonunary_patterns'))
let operator_binaries = mapnew(_operator_binaries, function('s:make_binary_patterns'))

let all_operators = flatten(operator_words) + flatten(operator_binaries) + flatten(operator_nonunary)
if len(all_operators) < len(s:operators)
    throw printf("Expected at least %d operators, but only %d were available", len(s:operators), len(all_operators))
endif

execute printf('syntax match prologOperator "%s"', join(all_operators, '\|'))

""" Conditions and compilation related things
syn keyword prologDirective_words contained module meta_predicate multifile dynamic det
syn keyword prologDirective_words contained discontiguous public non_terminal use_module
syn keyword prologDirective_conditionals contained if elif else endif
"syn match prologDirectiveStart '^:-'
highlight link prologDirective_words prologDirective
highlight link prologDirective_conditionals prologDirective

syn match prologDirective '^:-\s*\a\+' contains=prologDirective_words contains=prologDirective_conditionals
"syn region matchgroup=prologOperator start='^:-' end='\.\s\|\.$' contains=prologDirective_words,prologDirective_conditionals contains=ALLBUT,prologClause contains=@NoSpell

""" Matches stolen from prolog.vim
"syn match   prologCharCode  +0'\\\=.+
"syn match   prologCharCode  +0'\\\=.+
"highlight default link prologCharCode       Special
syn match   prologQuestion  +?-.*\.+    contains=prologNumber

""" Regions stolen from prolog.vim
syn region   prologString   start=+"+   skip=+\\\\\|\\"+    end=+"+ contains=@Spell
syn region   prologAtom     start=+'+   skip=+\\\\\|\\'+    end=+'+

" FIXME: the prolog.vim author didn't seem to try too hard when defining this...
syn region   prologClause   matchgroup=prologClauseHead start='^\a\w*' matchgroup=Normal end='\.\s\|\.$' contains=ALLBUT,prologClause contains=@NoSpell
"syn region   prologClause   matchgroup=prologClauseHead start=+^\s*[a-z]\w*+ matchgroup=Normal end=+\.\s\|\.$+ contains=ALLBUT,prologClause contains=@NoSpell

syn region   prologString   start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell
syn region   prologAtom     start=+'+ skip=+\\\\\|\\'+ end=+'+

" Comments
syn match   prologLineComment   +%.*+                   contains=@Spell
syn region  prologCComment      start=+/\*+ end=+\*/+   contains=@Spell
syn match   prologCCommentError "\*/"

highlight link prologLineComment    prologComment
highlight link prologCComment       prologComment
highlight link prologCCommentError  prologError

""" highlighting stolen from prolog.vim
highlight link prologNumber         Number
highlight link prologAtom           Constant
highlight link prologString         String
highlight link prologOperator       Operator
highlight link prologComment        Comment
highlight link prologOption         Tag
highlight link prologQuestion       PreProc
highlight link prologSpecial        Special
highlight link prologError          Error
highlight link prologKeyword        Keyword

highlight link prologClauseHead     Constant
highlight link prologClause         Normal
highlight link prologInterpreter    NonText
highlight link prologLibrary        Type
highlight link prologDirective      PreProc

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save

" take over the prolog.vim syntax.
let b:current_syntax = 'prolog'
