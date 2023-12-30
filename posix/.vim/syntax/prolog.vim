if exists("b:current_syntax")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

" prolog.vim uses "fail" as its keyword.
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
syn keyword prologBuiltin clause clause_property current_atom current_blob current_flag current_functor current_key current_predicate dwim_predicate nth_clause predicate_property
syn keyword prologBuiltin abolish assert asserta assertz copy_predicate_clauses current_transaction current_trie erase instance is_trie recorda recorded recordz redefine_system_predicate retract retractall snapshot term_hash transaction transaction_updates trie_delete trie_destroy trie_gen trie_gen_compiled trie_insert trie_lookup trie_new trie_property trie_term trie_update variant_hash variant_sha1
syn keyword prologBuiltin apply call call_cleanup call_with_depth_limit call_with_inference_limit ignore not once setup_call_catcher_cleanup setup_call_cleanup undo
syn keyword prologBuiltin compare reset shift shift_for_copy unify_with_occurs_check subsumes_term term_subsumer unifiable
syn keyword prologBuiltin at_end_of_stream copy_stream_data fill_buffer flush_output get get0 get_byte get_char get_code get_single_char nl peek_byte peek_char peek_code peek_string put put_byte put_char put_code read_pending_chars read_pending_codes set_end_of_stream skip tab ttyflush with_tty_raw
syn keyword prologBuiltin append close collect_wd current_input current_output current_stream fast_read fast_term_serialized fast_write getwd is_stream open open_null_stream register_iri_scheme see seeing seek seen set_input set_output set_prolog_IO set_stream set_stream_position set_system_IO stream_pair stream_position_data stream_property tell telling told with_output_to
highlight link prologBuiltin prologKeyword

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

highlight link prologLibrary Identifier

syn keyword prologIdentifier dynamic multifile discontiguous public non_terminal
highlight link prologIdentifier Identifier

" prolog.vim has no idea what an atom is apparently.
"syn region prologAtom start='\w' end='\>'
"syn region prologClause start='\w\+' end='\>'

"syn region   prologString   start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell
"syn region   prologAtom     start=+'+ skip=+\\\\\|\\'+ end=+'+
"syn region   prologClause   matchgroup=prologClauseHead start=+^\s*[a-z]\w*+ matchgroup=Normal end=+\.\s\|\.$+ contains=ALLBUT,prologClause contains=@NoSpell

syn match prologNumber '\<\(\u\|_\)\(\w\)*\>'
syn match prologNumber '\<\d\+\>'
syn match prologNumber '\<\d\+\.\d\+\>'
syn match prologNumber '\<\d\+[eE][-+]\=\d\+\>'
syn match prologNumber '\<\d\+\.\d\+[eE][-+]\=\d\+\>'
syn match prologNumber "\<0'[\\]\?.\>"
syn match prologNumber '\<0b[0-1]\+\>'
syn match prologNumber '\<0o\o\+\>'
syn match prologNumber '\<0x\x\+\>'
highlight link prologNumber Number

syn match prologVariable '\<\(\u\|_\)\(\w\)*\>'
highlight link prologVariable Identifier

" add some missing special character
syn match prologSpecialCharacter  ";"
syn match prologSpecialCharacter  "!"
syn match prologSpecialCharacter  ":-"
syn match prologSpecialCharacter  "?-"
syn match prologSpecialCharacter  "-->"
syn match prologSpecialCharacter  "^"
syn match prologSpecialCharacter  "|"

" FIXME
syn match prologSpecialCharacter  "~"
syn match prologSpecialCharacter  "_"

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
\    '\<as\>', '\<is\>', '\<of\>', '\<in\>', '\<ins\>', '>:<', ':<',
\    '\\+',
\    '+', '-', '/\\', '\\/', 'xor',
\    '?',
\    '*', '/', '//', 'div', 'rdiv', '<<', '>>', 'mod', 'rem',
\    '**',
\    '\\',
\    '.',
\    '$',
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

execute printf('syntax match prologOperator "%s"', join(s:operators, '\|'))

" Regions
syn match    prologCharCode +0'\\\=.+
syn region   prologString   start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=@Spell
syn region   prologAtom     start=+'+ skip=+\\\\\|\\'+ end=+'+
syn region   prologClause   matchgroup=prologClauseHead start=+^\s*[a-z]\w*+ matchgroup=Normal end=+\.\s\|\.$+ contains=ALLBUT,prologClause contains=@NoSpell

"   :sy region par1 matchgroup=par1 start=/(/ end=/)/ contains=par2
"   :sy region par2 matchgroup=par2 start=/(/ end=/)/ contains=par3 contained
"   :sy region par3 matchgroup=par3 start=/(/ end=/)/ contains=par1 contained
"   :hi par1 ctermfg=red guifg=red
"   :hi par2 ctermfg=blue guifg=blue
"   :hi par3 ctermfg=darkgreen guifg=darkgreen

let &cpo = s:cpo_save
unlet s:cpo_save
