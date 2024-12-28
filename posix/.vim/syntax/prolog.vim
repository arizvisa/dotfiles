if exists("b:current_syntax")
    finish
endif

let s:cpoptions_save = &cpoptions
set cpoptions&vim

""" global settings
syntax case match
syntax sync minlines=1 maxlines=0

""" character classes
let s:char_type_UC = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ_'
let s:char_type_LC = 'abcdefghijklmnopqrstuvwxyz'
let s:char_type_DI = '0123456789'
let s:char_type_PU = '(),[]{|}'
let s:char_type_SY = '#$&*+-./:<=>?@\^~'
let s:char_type_SP = "\x09\x0a\x0b\x0c\x0d\x20"
let s:char_type_AC = s:char_type_UC .. s:char_type_LC
"let s:char_type_WC = s:char_type_UC .. s:char_type_LC .. s:char_type_DI .. s:char_type_PU
let s:char_type_WC = s:char_type_UC .. s:char_type_LC .. s:char_type_DI

""" tables used for symbol conversion
let s:prologSymbols = {
\   '.': '\.', '(': '(', ')': ')', ':': ':', '!': '!', '+': '+', '-': '-', '<': '\<', '=': '=', '>': '\>', '&': '&', '*': '*', '#': '#',
\   '/': '/', ';': ';', '?': '?', '[': '\[', ']': '\]', '^': '\^', '{': '{', '|': '|', '}': '}', '~': '\~', '\': '\\', '$' : '$', '@': '@'
\ }

let s:prologSymbolPairs_open =  {'(' : ')', '[' : ']', '{' : '}'}
let s:prologSymbolPairs_close = {')' : '(', ']': '[', '}' : '{'}
let s:prologSymbolPairs = extendnew(s:prologSymbolPairs_open, s:prologSymbolPairs_close)

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
\    '[[:digit:][:space:]]\@!\.[[:digit:][:space:]]\@!',
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
    let escaped_symbols = s:escape_string(s:char_type_SY)
    let escaped_words_and_punctuation = s:escape_string(s:char_type_WC .. s:char_type_PU)

    return [
\       '[^' .. escaped_symbols .. ']\+\zs' .. a:symbols .. '\ze\_[^' .. escaped_symbols .. ']',
\       '\>[^' .. escaped_symbols .. ']\?\zs' .. a:symbols .. '\ze\_[[:space:]' .. escaped_words_and_punctuation .. ']',
\   ]
endfunction

function! s:make_nonunary_patterns(key, symbol)
    let escaped_groupings_open = join(s:escape_list(keys(s:prologSymbolPairs_open)), '')
    let escaped_groupings_close = join(s:escape_list(keys(s:prologSymbolPairs_close)), '')
    let escaped_words = s:escape_string(s:char_type_WC)
    let escaped_symbols = s:escape_string(s:char_type_SY)
    let ignore_nan_inf = '\(inf\|nan\)\@!'
    return [
\       '\>' .. '[[:space:]]*\zs' .. a:symbol .. '\ze[[:space:]]*' .. '\<' .. ignore_nan_inf,
\       '[' .. escaped_words .. escaped_groupings_close .. ']\zs' .. a:symbol .. '\ze[^\-\+' .. escaped_groupings_close .. ']',
\       '\>[^' .. escaped_symbols .. ']\?\zs' .. a:symbol .. '\ze' .. ignore_nan_inf .. '\_[[:space:]' .. escaped_words .. s:escape_string(s:char_type_PU) .. ']',
\   ]
endfunction

function! s:exclude_string(string, excluded)
    let items = split(a:string, '\zs')
    return join(s:exclude_list(items, split(a:excluded, '\zs')), '')
endfunction

function! s:escape_string(string)
    let items = split(a:string, '\zs')
    let result = s:escape_list(items)
    return join(result, '')
endfunction

function! s:exclude_list(items, excluded)
    let result = []
    for value in a:items
        if index(a:excluded, value) < 0 | let result = add(result, value) | endif
    endfor
    return result
endfunction

function! s:escape_list(items)
    return mapnew(a:items, 'has_key(s:prologSymbols, v:val)? s:prologSymbols[v:val] : v:val')
endfunction

function! s:compare_length(item1, item2)
    return strlen(a:item1) < strlen(a:item2)? -1 : strlen(a:item1) == strlen(a:item2)? 0 : +1
endfunction
function! s:sort_list_by_length(items)
    return sort(copy(a:items), function('s:compare_length'))
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

""" <mufasa-voice>it starts...</mufasa-voice>
syntax keyword prologBuiltin_ contained true false repeat phrase call_dcg op catch throw catch_with_backtrace
syntax keyword prologBuiltin_ contained bagof findall findnsols setof forall dynamic compile_predicates
syntax keyword prologBuiltin_ contained current_format_predicate format format_predicate swritef writef
syntax keyword prologBuiltin_ contained is_list keysort length memberchk msort predsort sort
syntax keyword prologBuiltin_ contained abs acos acosh asin asinh atan atan2 atanh between bounded_number ceil ceiling cmpr copysign cos cosh denominator div divmod erf erfc eval exp float float_class float_fractional_part float_integer_part float_parts floor getbit integer lgamma log log10 lsb max maxr min minr msb nexttoward nth_integer_root_and_remainder numerator plus popcount powm random rational rationalize round roundtoward sign sin sinh sqrt succ tan tanh truncate
syntax keyword prologBuiltin_ contained char_conversion char_type code_type collation_key current_char_conversion downcase_atom locale_sort normalize_space upcase_atom
syntax keyword prologBuiltin_ contained current_locale locale_create locale_destroy locale_property set_locale
syntax keyword prologBuiltin_ contained atom_chars atom_codes atom_concat atomic_concat atomic_list_concat atom_length atom_number atom_prefix atom_to_term char_code name number_chars number_codes sub_atom sub_atom_icasechk term_to_atom
syntax keyword prologBuiltin_ contained arg compound_name_arguments compound_name_arity copy_term copy_term_nat duplicate_term functor is_most_general_term nb_linkarg nb_setarg nonground numbervars same_term setarg term_singletons term_variables var_number
syntax keyword prologBuiltin_ contained portray print prompt prompt1 read read_clause read_term read_term_from_atom read_term_with_history write write_canonical write_length writeln writeq write_term
syntax keyword prologBuiltin_ contained clause clause_property current_atom current_blob current_flag current_functor current_key current_op current_predicate dwim_predicate nth_clause predicate_property
syntax keyword prologBuiltin_ contained abolish assert asserta assertz copy_predicate_clauses current_transaction current_trie erase instance is_trie recorda recorded recordz redefine_system_predicate retract retractall snapshot term_hash transaction transaction_updates trie_delete trie_destroy trie_gen trie_gen_compiled trie_insert trie_lookup trie_new trie_property trie_term trie_update variant_hash variant_sha1
syntax keyword prologBuiltin_ contained compare reset shift shift_for_copy unify_with_occurs_check subsumes_term term_subsumer unifiable
syntax keyword prologBuiltin_ contained at_end_of_stream copy_stream_data fill_buffer flush_output get get0 get_byte get_char get_code get_single_char nl peek_byte peek_char peek_code peek_string put put_byte put_char put_code read_pending_chars read_pending_codes set_end_of_stream skip tab ttyflush with_tty_raw
syntax keyword prologBuiltin_ contained append close collect_wd current_input current_output current_stream fast_read fast_term_serialized fast_write getwd is_stream open open_null_stream register_iri_scheme see seeing seek seen set_input set_output set_prolog_IO set_stream set_stream_position set_system_IO stream_pair stream_position_data stream_property tell telling told with_output_to
syntax keyword prologBuiltin_ contained acyclic_term atom atomic blob callable compound cyclic_term float ground integer nonvar number rational string var
syntax keyword prologBuiltin_ contained noprotocol protocol protocola protocolling
syntax keyword prologBuiltin_ contained absolute_file_name access_file chdir delete_directory delete_file directory_files exists_directory exists_file expand_file_name file_base_name file_directory_name file_name_extension is_absolute_file_name make_directory prolog_to_os_filename read_link rename_file same_file size_file time_file tmp_file tmp_file_stream working_directory
syntax keyword prologBuiltin_ contained getenv setenv setlocale shell unsetenv
syntax keyword prologBuiltin_ contained date date_time_stamp date_time_value day_of_the_week format_time get_time parse_time stamp_date_time time
syntax keyword prologBuiltin_ contained apple_current_locale_identifier win_add_dll_directory win_exec win_folder win_get_user_preferred_ui_languages win_process_modules win_registry_get_value win_remove_dll_directory win_shell
syntax keyword prologBuiltin_ contained window_title win_has_menu win_insert_menu win_insert_menu_item win_window_color win_window_pos
syntax keyword prologBuiltin_ contained close_dde_conversation dde_current_connection dde_current_service dde_execute dde_poke dde_register_service dde_request dde_unregister_service open_dde_conversation
syntax keyword prologBuiltin_ contained b_getval b_setval nb_current nb_delete nb_getval nb_linkval nb_setval
syntax keyword prologBuiltin_ contained at_halt cancel_halt consult encoding ensure_loaded exists_source expand_file_search_path file_search_path include initialization initialize library_directory load_files make prolog_file_type prolog_load_context require source_file source_file_property source_location unload_file
syntax keyword prologBuiltin_ contained compile_aux_clauses dcg_translate_rule expand_goal expand_term goal_expansion qcompile term_expansion var_property
syntax keyword prologBuiltin_ contained current_signal on_signal prolog_alert_signal
syntax keyword prologBuiltin_ contained byte_count character_count line_count line_position wait_for_input
syntax keyword prologBuiltin_ contained set_random random_property current_arithmetic_function
syntax keyword prologBuiltin_ contained tty_get_capability tty_goto tty_put tty_size
syntax keyword prologBuiltin_ contained dwim_match sleep wildcard_match
syntax cluster prologBuiltin add=prologBuiltin_

syntax keyword prologBuiltin_metacall contained apply call call_cleanup call_with_depth_limit call_with_inference_limit ignore not once setup_call_catcher_cleanup setup_call_cleanup undo
syntax cluster prologBuiltin add=prologBuiltin_metacall
syntax keyword prologBuiltin_flag contained create_prolog_flag current_prolog_flag set_prolog_flag
syntax cluster prologBuiltin add=prologBuiltin_flag
syntax keyword prologBuiltin_tabling contained abolish_all_tables abolish_module_tables abolish_nonincremental_tables abolish_private_tables abolish_shared_tables abolish_table_subgoals current_table not_exists tabled_call tnot untable
syntax cluster prologBuiltin add=prologBuiltin_tabling
syntax keyword prologBuiltin_trace contained prolog_trace_interception prolog_skip_frame prolog_skip_level
syntax cluster prologBuiltin add=prologBuiltin_trace
syntax keyword prologBuiltin_environment contained prolog_current_frame prolog_current_choice prolog_cut_to prolog_frame_attribute deterministic
syntax cluster prologBuiltin add=prologBuiltin_environment
syntax keyword prologBuiltin_chr contained chr_module current_chr_constraint chr_leash chr_notrace chr_trace chr_show_store find_chr_constraint
syntax cluster prologBuiltin add=prologBuiltin_chr

highlight link prologBuiltin_ prologKeyword
highlight link prologBuiltin_metacall prologKeyword
highlight link prologBuiltin_flag prologKeyword
highlight link prologBuiltin_tabling prologKeyword
highlight link prologBuiltin_trace prologKeyword
highlight link prologBuiltin_environment prologKeyword
highlight link prologBuiltin_chr prologKeyword

syntax keyword prologTopLevel contained prolog prolog:called_by prolog:hook prolog:meta_goal prolog:message_line_element prolog:message_prefix_hook prolog_edit:edit_command prolog_edit:edit_source prolog_edit:load prolog_edit:locate prolog:debug_control_hook prolog_edit:edit_command prolog_edit:edit_source prolog_edit:locate prolog:help_hook
syntax keyword prologTopLevel contained abort break expand_answer expand_query halt gxref attach_packs edit
syntax keyword prologTopLevel contained message_hook message_property message_to_string print_message print_message_lines thread_message_hook version
syntax keyword prologTopLevel contained debug debugging leash nodebug nospy nospyall notrace spy style_check trace tracing unknown visible
syntax keyword prologTopLevel contained gdebug gspy gtrace guitracer noguitracer
syntax keyword prologTopLevel contained profile profile_data profile_procedure_data statistics show_profile
syntax keyword prologTopLevel contained garbage_collect garbage_collect_atoms garbage_collect_clauses malloc_property prolog_stack_property set_malloc set_prolog_gc_thread set_prolog_stack thread_idle trim_heap trim_stacks
highlight link prologTopLevel prologSpecial

syntax keyword prologExtension_string contained atomics_to_string atom_string get_string_code number_string open_string read_string split_string string_bytes string_chars string_code string_codes string_concat string_length string_lower string_upper sub_string term_string text_to_string
highlight link prologExtension_string prologExtension
syntax keyword prologExtension_dicts contained b_set_dict del_dict dict_create dict_pairs get get_dict is_dict nb_link_dict nb_set_dict put put_dict select_dict
highlight link prologExtension_dicts prologExtension
highlight link prologExtension prologKeyword
syntax cluster prologExtension contains=prologExtension_dicts,prologExtension_string
syntax cluster prologBuiltin add=@prologExtension

syntax match prologLibrary_qualified contained '\<\w\+:\w\+\>'
syntax cluster prologLibrary contains=prologLibrary_qualified
syntax keyword prologLibrary_lists contained member append append prefix select selectchk select selectchk nextto delete nth0 nth1 nth0 nth1 last proper_length same_length reverse permutation flatten clumped subseq max_member min_member max_member min_member sum_list max_list min_list numlist is_set list_to_set intersection union subset subtract memberchk
syntax cluster prologLibrary add=prologLibrary_lists
syntax keyword prologLibrary_aggregate contained aggregate aggregate_all foreach free_variables
syntax cluster prologLibrary add=prologLibrary_aggregate
syntax keyword prologLibrary_aggregate_predicate contained count sum min max set bag
syntax cluster prologLibrary add=prologLibrary_aggregate_predicate
syntax keyword prologLibrary_apply contained convlist exclude foldl include maplist partition scanl
syntax cluster prologLibrary add=prologLibrary_apply
syntax keyword prologLibrary_assoc contained assoc_to_keys assoc_to_list assoc_to_values del_assoc del_max_assoc del_min_assoc empty_assoc get_assoc is_assoc list_to_assoc map_assoc max_assoc min_assoc gen_assoc ord_list_to_assoc put_assoc
syntax cluster prologLibrary add=prologLibrary_assoc
syntax keyword prologLibrary_dicts contained dict_fill dict_keys dict_size dicts_join dicts_same_keys dicts_same_tag dicts_slice dicts_to_compounds dicts_to_same_keys
syntax cluster prologLibrary add=prologLibrary_dicts
syntax keyword prologLibrary_occurs contained contains_term contains_var free_of_term free_of_var occurrences_of_term occurrences_of_var sub_term sub_term_shared_variables sub_var
syntax cluster prologLibrary add=prologLibrary_occurs
syntax keyword prologLibrary_option contained dict_options merge_options meta_options option select_option
syntax cluster prologLibrary add=prologLibrary_option
syntax keyword prologLibrary_ordsets contained is_ordset list_to_ord_set ord_add_element ord_del_element ord_disjoint ord_empty ord_intersect ord_intersection ord_memberchk ord_selectchk ord_seteq ord_subset ord_subtract ord_symdiff ord_union
syntax cluster prologLibrary add=prologLibrary_ordsets
syntax keyword prologLibrary_pairs contained group_pairs_by_key map_list_to_pairs pairs_keys pairs_keys_values pairs_values transpose_pairs
syntax cluster prologLibrary add=prologLibrary_pairs
syntax keyword prologLibrary_random contained getrand maybe random random_between random_member random_numlist random_perm2 random_permutation random_select random_subseq randseq randset setrand
syntax cluster prologLibrary add=prologLibrary_random
syntax keyword prologLibrary_rbtrees contained is_rbtree list_to_rbtree ord_list_to_rbtree rb_apply rb_clone rb_delete rb_del_max rb_del_min rb_empty rb_fold rb_in rb_insert rb_insert_new rb_keys rb_lookup rb_map rb_max rb_min rb_new rb_next rb_partial_map rb_previous rb_size rb_update rb_visit
syntax cluster prologLibrary add=prologLibrary_rbtrees
syntax keyword prologLibrary_solution_sequences contained call_nth distinct group_by limit offset order_by reduced
syntax cluster prologLibrary add=prologLibrary_solution_sequences
syntax keyword prologLibrary_varnumbers contained max_var_number numbervars varnumbers varnumbers_names
syntax cluster prologLibrary add=prologLibrary_varnumbers
syntax keyword prologLibrary_simplex contained constraint gen_state maximize minimize objective variable_value
syntax cluster prologLibrary add=prologLibrary_simplex
syntax keyword prologLibrary_yall contained is_lambda lambda_calls
syntax cluster prologLibrary add=prologLibrary_yall
syntax keyword prologLibrary_intercept contained intercept intercept_all nb_intercept_all send_signal send_silent_signal
syntax cluster prologLibrary add=prologLibrary_intercept
syntax keyword prologLibrary_shlib contained use_foreign_library compat_arch load_foreign_library unload_foreign_library current_foreign_library reload_foreign_library
syntax cluster prologLibrary add=prologLibrary_shlib
syntax keyword prologLibrary_prolog_xref contained xref_called xref_clean xref_comment xref_current_source xref_defined xref_definition_line xref_done xref_exported xref_hook xref_meta xref_meta_src xref_mode xref_module xref_op xref_option xref_prolog_flag xref_public_list xref_source xref_source_file xref_uses_file
syntax cluster prologLibrary add=prologLibrary_prolog_xref
syntax keyword prologLibrary_prolog_pack contained pack_attach pack_info pack_install pack_list pack_list_installed pack_property pack_rebuild pack_remove pack_search pack_upgrade pack_url_file
syntax cluster prologLibrary add=prologLibrary_prolog_pack
syntax keyword prologLibrary_nb_set contained add_nb_set empty_nb_set gen_nb_set nb_set_to_list size_nb_set
syntax cluster prologLibrary add=prologLibrary_nb_set
syntax keyword prologLibrary_error contained current_encoding current_type domain_error existence_error has_type instantiation_error is_of_type must_be permission_error representation_error resource_error syntax_error type_error uninstantiation_error
syntax cluster prologLibrary add=prologLibrary_error

highlight link prologLibrary_qualified  prologLibrary
highlight link prologLibrary_lists prologLibrary
highlight link prologLibrary_aggregate prologLibrary
highlight link prologLibrary_aggregate_predicate prologLibrary
highlight link prologLibrary_apply prologLibrary
highlight link prologLibrary_assoc prologLibrary
highlight link prologLibrary_dicts prologLibrary
highlight link prologLibrary_occurs prologLibrary
highlight link prologLibrary_option prologLibrary
highlight link prologLibrary_ordsets prologLibrary
highlight link prologLibrary_pairs prologLibrary
highlight link prologLibrary_random prologLibrary
highlight link prologLibrary_rbtrees prologLibrary
highlight link prologLibrary_solution_sequences prologLibrary
highlight link prologLibrary_varnumbers prologLibrary
highlight link prologLibrary_simplex prologLibrary
highlight link prologLibrary_yall prologLibrary
highlight link prologLibrary_intercept prologLibrary
highlight link prologLibrary_shlib prologLibrary
highlight link prologLibrary_prolog_xref prologLibrary
highlight link prologLibrary_prolog_pack prologLibrary
highlight link prologLibrary_nb_set prologLibrary
highlight link prologLibrary_error prologLibrary

" prolog.vim has no idea what an atom is apparently.
"syn region prologAtom start='\w' end='\>'
"syn region prologClause start='\w\+' end='\>'

" prolog.vim author seemed to fuck this one up.
"syn match prologNumber '\<\(\u\|_\)\(\w\)*\>'

" this next pattern is not greedy enough, so we split it into one that matches
" more than 1 digit, and another for just a single digit that is sitting alone.
"syn match prologNumber '\<\d\+\>'
syntax match prologNumber contained '[-+]\=\<\d\d\+\>'
syntax match prologNumber contained '[-+]\=\<\d\>'
syntax match prologNumber contained '[-+]\=\<\d\+\>'

" FIXME: numbers can also include the _ as a separator (that gets ignored)
" FIXME: we can also include Inf [+-]?\sd+[.]\sd+Inf or 1.5NaN or nan.
"syntax match prologNumber '[-+]\=\<\d\+\.\d\+\>' contained
syntax match prologNumber contained '[-+]\=\<\d\+\.\d\+\%[NaN]\>'
syntax match prologNumber contained '[-+]\=\<\d\+\.\d\+\%[Inf]\>'
syntax match prologNumber contained '[-+]\=inf\>'
syntax match prologNumber contained '[-+]\=nan\>'
syntax match prologNumber contained '[-+]\=\<\d\+r\d\+\>'

" hopefully the rest of these numbers work...
syntax match prologNumber contained '[-+]\=\<\d\+[eE][-+]\=\d\+\>'
syntax match prologNumber contained '[-+]\=\<\d\+\.\d\+[eE][-+]\=\d\+\>'
syntax match prologNumber contained "[-+]\=\<0'[\\]\?."
syntax match prologNumber contained '[-+]\=\<0b[0-1]\+\>'
syntax match prologNumber contained '[-+]\=\<0o\o\+\>'
syntax match prologNumber contained '[-+]\=\<0x\x\+\>'

" ...and we might as well add these too, because prolog is awesome.
syntax match prologNumber contained "[-+]\=\<2'[0-1]\+\>"
syntax match prologNumber contained "[-+]\=\<3'[0-2]\+\>"
syntax match prologNumber contained "[-+]\=\<4'[0-3]\+\>"
syntax match prologNumber contained "[-+]\=\<5'[0-4]\+\>"
syntax match prologNumber contained "[-+]\=\<6'[0-5]\+\>"
syntax match prologNumber contained "[-+]\=\<7'[0-6]\+\>"
syntax match prologNumber contained "[-+]\=\<8'[0-7]\+\>"
syntax match prologNumber contained "[-+]\=\<9'[0-8]\+\>"
syntax match prologNumber contained "[-+]\=\<10'[0-9]\+\>"
syntax match prologNumber contained "[-+]\=\<11'[0-9a]\+\>"
syntax match prologNumber contained "[-+]\=\<12'[0-9ab]\+\>"
syntax match prologNumber contained "[-+]\=\<13'[0-9abc]\+\>"
syntax match prologNumber contained "[-+]\=\<14'[0-9abcd]\+\>"
syntax match prologNumber contained "[-+]\=\<15'[0-9abcde]\+\>"
syntax match prologNumber contained "[-+]\=\<16'[0-9abcdef]\+\>"
highlight link prologNumber Number

syntax match prologVariable contained '\<\(\u\|_\)\(\w\)*\>'
highlight link prologVariable Identifier

" add some missing special characters
syntax match prologSpecialCharacter contained ';'
syntax match prologSpecialCharacter contained '!'
syntax match prologSpecialCharacter contained '@'
syntax match prologSpecialCharacter contained '[^\$]\zs\$\ze\_[^\$]'
"syntax match prologSpecialCharacter '[()[:space:][:alnum:]]\zs:-\ze'
"syntax match prologSpecialCharacter '[()[:space:][:alnum:]]\zs?-\ze'
"syntax match prologSpecialCharacter '[()[:space:][:alnum:]]\zs-->\ze'
"syntax match prologSpecialCharacter '[()[:space:][:alnum:]]\zs=>\ze'
syntax match prologSpecialCharacter contained '\^'
syntax match prologSpecialCharacter contained '|'
syntax match prologSpecialCharacter contained '{|}'
syntax match prologSpecialCharacter contained '\[|\]'

"syn region prologConstraintRule matchgroup=prologConstraintName start='^\a\w*' matchgroup=Normal end='\.\s\|\.$' contains=prologConstraints contains=@NoSpell
"syn match prologSpecialCharacter_CHR_Rule '\zs<=>\ze'
"syn match prologSpecialCharacter_CHR_Rule '\zs==>\ze'
"syn match prologSpecialCharacter_CHR_Rule '\zs\\\ze'
"
"highlight link prologConstraintRule     Constant
"highlight link prologSpecialCharacter_CHR_Rule         Special

" add the '~' character used by package(func)
let without_tilde = s:exclude_dict(s:prologSymbols, ['~', '.'])
let tilde_pattern = printf('[[:space:][:alnum:]%s]\zs%s\ze\_[[:space:][:alnum:]%s]', join(values(without_tilde), ""), '\~', join(values(without_tilde), ""))
execute printf("syn match prologSpecialCharacter '%s'", tilde_pattern)
highlight link prologSpecialCharacter prologSpecial
"syntax match prologSpecial '^:-\s*$'

" split up all the operators by symbols or words. this way we can escape them differently.
let _sorted_operators = reverse(s:sort_list_by_length(s:operators))
let _operator_words = filter(copy(_sorted_operators), 'v:val =~ "^\\a\\a*$"')
let _operator_nonunary = filter(copy(_sorted_operators), 'v:val =~ "^[+-]$"')
let _operator_binaries = s:exclude_list(copy(_sorted_operators), _operator_words + _operator_nonunary)

let operator_words = mapnew(_operator_words, '"\\<" .. v:val .. "\\>"')
let operator_nonunary = mapnew(_operator_nonunary, function('s:make_nonunary_patterns'))
let operator_binaries = mapnew(_operator_binaries, function('s:make_binary_patterns'))

let all_operators = flatten(operator_words) + flatten(operator_binaries) + flatten(operator_nonunary)
if len(all_operators) < len(s:operators)
    throw printf("Expected at least %d operators, but only %d were available", len(s:operators), len(all_operators))
endif

execute printf('syntax match prologOperator contained "%s"', join(all_operators, '\|'))

""" Conditions and compilation related things
syntax keyword prologDirective_words contained module meta_predicate multifile dynamic det
syntax keyword prologDirective_words contained discontiguous public non_terminal use_module
syntax keyword prologDirective_conditionals contained if elif else endif
syntax keyword prologDirective_autoload contained autoload_path make_library_index reload_library_index
syntax keyword prologDirective_save contained autoload_all qsave_program volatile
syntax keyword prologDirective_shlib contained use_foreign_library compat_arch load_foreign_library unload_foreign_library current_foreign_library reload_foreign_library
syntax keyword prologDirective_hook contained attr_unify_hook exception file_search_path goal_expansion library_directory message_hook message_prefix_hook message_property portray prolog_list_goal prolog_load_file resource term_expansion
syntax keyword prologDirective_events contained prolog_listen prolog_unlisten
syntax keyword prologDirective_tabling contained table
syntax keyword prologDirective_trace contained prolog_trace_interception prolog_skip_frame prolog_skip_level
syntax keyword prologDirective_chr contained chr_constraint chr_type

syntax cluster prologDirective add=prologDirective_words
syntax cluster prologDirective add=prologDirective_words
syntax cluster prologDirective add=prologDirective_conditionals
syntax cluster prologDirective add=prologDirective_autoload
syntax cluster prologDirective add=prologDirective_save
syntax cluster prologDirective add=prologDirective_shlib
syntax cluster prologDirective add=prologDirective_hook
syntax cluster prologDirective add=prologDirective_events
syntax cluster prologDirective add=prologDirective_tabling
syntax cluster prologDirective add=prologDirective_trace
syntax cluster prologDirective add=prologDirective_chr

highlight link prologDirective_words prologDirective
highlight link prologDirective_conditionals prologDirective
highlight link prologDirective_autoload prologDirective
highlight link prologDirective_save prologDirective
highlight link prologDirective_shlib prologDirective
highlight link prologDirective_hook prologDirective
highlight link prologDirective_events prologDirective
highlight link prologDirective_tabling prologDirective
highlight link prologDirective_chr prologDirective

syntax keyword prologOption_use_module_option contained library
syntax keyword prologOption_create_prolog_flag_option contained access type keep
syntax keyword prologOption_current_prolog_flag_option contained abi_version access_level address_bits agc_close_streams agc_margin allow_dot_in_atom allow_variable_name_as_functor android android_api answer_write_options apple arch argv associated_file autoload back_quotes backtrace backtrace_depth backtrace_goal_depth backtrace_show_lines bounded break_level c_cc c_cflags character_escapes character_escapes_unicode char_conversion c_ldflags c_libplso c_libs cmake_build_type colon_sets_calling_context color_term compiled_at compile_meta_arguments conda console_menu cpu_count dde debug debugger_show_context debugger_write_options debug_on_error debug_on_interrupt determinism_error dialect double_quotes editor emacs_inferior_process encoding executable executable_format exit_status file_name_case_handling file_name_variables file_search_cache_time float_max float_max_integer float_min float_overflow float_rounding float_undefined float_underflow float_zero_div gc gc_thread generate_debug_info gmp_version gui heartbeat history home hwnd integer_rounding_function iso large_files last_call_optimisation libswipl malloc max_answers_for_subgoal max_answers_for_subgoal_action max_arity max_char_code max_integer max_procedure_arity max_rational_size max_rational_size_action max_table_answer_size max_table_answer_size_action max_table_subgoal_size max_table_subgoal_size_action max_tagged_integer message_context min_integer min_tagged_integer mitigate_spectre msys2 occurs_check on_error on_warning open_shared_object optimise optimise_unify os_argv packs path_max pid pipe portable_vmi posix_shell prefer_rationals print_write_options prompt_alternatives_on protect_static_code qcompile rational_syntax readline report_error resource_database runtime sandboxed_load saved_program shared_home shared_object_extension shared_object_search_path shared_table_space shift_check signals stack_limit stream_type_check string_stack_tripwire system_thread_id table_incremental table_shared table_space table_subsumptive threads timezone tmp_dir toplevel_goal toplevel_list_wfs_residual_program toplevel_mode toplevel_name_variables toplevel_print_anon toplevel_print_factorized toplevel_prompt toplevel_residue_vars toplevel_var_size trace_gc traditional tty_control unix unknown unload_foreign_libraries user_flags var_prefix verbose verbose_autoload verbose_file_search verbose_load version version_data version_git vmi_builtin warn_autoload warn_override_implicit_import windows wine_version win_file_access_check write_attributes write_help_with_overstrike xpce xpce_version xref
syntax keyword prologOption_qsave_program contained autoload class emulator foreign goal init_file map obfuscate op stack_limit stand_alone toplevel undefined verbose
syntax keyword prologOption_open_resource contained type encoding bom
syntax keyword prologOption_resource contained include exclude
syntax keyword prologOption_register_irl_scheme contained open access time size
syntax keyword prologOption_open contained alias bom buffer close_on_abort create encoding eof_action locale lock newline reposition type wait
syntax keyword prologOption_open_create contained read write execute default all
syntax keyword prologOption_stream_property contained alias buffer buffer_size bom close_on_abort close_on_exec encoding end_of_stream eof_action error file_name file_no input locale mode newline nlink output position reposition representation_errors timeout type tty write_errors
syntax keyword prologOption_set_stream contained alias buffer buffer_size close_on_abort close_on_exec encoding eof_action file_name line_position locale newline timeout type record_position representation_errors tty
syntax keyword prologOption_load_foreign_library contained install
syntax keyword prologOption_autoload contained false explicit user user_or_explicit tree
syntax keyword prologOption_compile_meta_arguments contained false control always
syntax keyword prologOption_file_name_case_handling contained case_sensitive case_preserving case_insensitive
syntax keyword prologOption_pack_install contained url package_directory global insecure interactive silent upgrade rebuild test git link
syntax keyword prologOption_pack_property contained directory version title author download readme todo
syntax keyword prologOption_pack_attach contained duplicate search
syntax keyword prologOption_prolog_listen contained as name abort erase break frame_finished thread_exit thread_start this_thread_exit
syntax keyword prologOption_exception contained undefined_predicate undefined_global_variable
syntax keyword prologOption_prolog_trace_interception contained call redo unify exit fail exception cut_call cut_exit
syntax keyword prologOption_prolog_frame_attribute contained alternative has_alternative goal parent_goal predicate_indicator clause level parent context_module top hidden skipped pc argument
syntax keyword prologOption_prolog_choice_attribute contained parent frame type pc clause

syntax cluster prologDirectiveOption add=prologOption_use_module_option
syntax cluster prologDirectiveOption add=prologOption_create_prolog_flag_option
syntax cluster prologDirectiveOption add=prologOption_current_prolog_flag_option
syntax cluster prologDirectiveOption add=prologOption_qsave_program
syntax cluster prologDirectiveOption add=prologOption_open_resource
syntax cluster prologDirectiveOption add=prologOption_resource
syntax cluster prologDirectiveOption add=prologOption_register_irl_scheme
syntax cluster prologDirectiveOption add=prologOption_open
syntax cluster prologDirectiveOption add=prologOption_open_create
syntax cluster prologDirectiveOption add=prologOption_stream_property
syntax cluster prologDirectiveOption add=prologOption_set_stream
syntax cluster prologDirectiveOption add=prologOption_load_foreign_library
syntax cluster prologDirectiveOption add=prologOption_autoload
syntax cluster prologDirectiveOption add=prologOption_compile_meta_arguments
syntax cluster prologDirectiveOption add=prologOption_file_name_case_handling
syntax cluster prologDirectiveOption add=prologOption_pack_install
syntax cluster prologDirectiveOption add=prologOption_pack_property
syntax cluster prologDirectiveOption add=prologOption_pack_attach
syntax cluster prologDirectiveOption add=prologOption_prolog_listen
syntax cluster prologDirectiveOption add=prologOption_exception
syntax cluster prologDirectiveOption add=prologOption_prolog_trace_interception
syntax cluster prologDirectiveOption add=prologOption_prolog_frame_attribute
syntax cluster prologDirectiveOption add=prologOption_prolog_choice_attribute

highlight link prologOption_use_module_option prologKeyword
highlight link prologOption_create_prolog_flag_option prologKeyword
highlight link prologOption_current_prolog_flag_option prologKeyword
highlight link prologOption_qsave_program prologKeyword
highlight link prologOption_open_resource prologKeyword
highlight link prologOption_resource prologKeyword
highlight link prologOption_register_irl_scheme prologKeyword
highlight link prologOption_open prologKeyword
highlight link prologOption_open_create prologKeyword
highlight link prologOption_stream_property prologKeyword
highlight link prologOption_set_stream prologKeyword
highlight link prologOption_load_foreign_library prologKeyword
highlight link prologOption_autoload prologKeyword
highlight link prologOption_compile_meta_arguments prologKeyword
highlight link prologOption_file_name_case_handling prologKeyword
highlight link prologOption_pack_install prologKeyword
highlight link prologOption_pack_property prologKeyword
highlight link prologOption_pack_attach prologKeyword
highlight link prologOption_prolog_listen prologKeyword
highlight link prologOption_exception prologKeyword
highlight link prologOption_prolog_trace_interception prologKeyword
highlight link prologOption_prolog_frame_attribute prologKeyword
highlight link prologOption_prolog_choice_attribute prologKeyword

""" Matches stolen from prolog.vim
"syn match   prologCharCode  +0'\\\=.+
"syn match   prologCharCode  +0'\\\=.+
"highlight default link prologCharCode       Special
syn match   prologQuestion  +?-.*\.+    contains=prologNumber

""" Regions stolen from prolog.vim
syn region   prologString       contained start=+"+   skip=+\\\\\|\\"+  end=+"+ contains=@Spell
syn region   prologAtom         contained start=+'+   skip=+\\\\\|\\'+  end=+'+
syn region   prologCharCodes    contained start=+`+   skip=+\\\\\|\\`+  end=+`+ contains=@Spell

syntax match prologAnonymousVariable contained '[^\$]\zs\$\u\w*\ze\_[^\$]'
syntax match prologAnonymousVariable contained '\<_\w*\>'
highlight link prologAnonymousVariable prologSpecial

" FIXME: the prolog.vim author didn't seem to try too hard when defining this...
syntax match prologDefineRule ':-' skipwhite skipempty contained
"syntax region prologDefineRule start=':-\s*$' skipwhite skipempty contains=@prologBodyToken nextgroup=@prologRuleBody end='\.\s*$'
syntax match prologEndingRule '\.\ze\s*\_[%]'
highlight link prologDefineRule prologSpecial
highlight link prologEndingRule prologSpecial

syn match prologDefineConstraintRule '[^[:space:]]\s*\zs-->\ze\s*'
syn match prologDefineCHRRule '[^[:space:]]\s*\zs==>\ze\s*'
syn match prologDefineCHRRule '[^[:space:]]\s*\zs<=>\ze\s*'
syn match prologDefineCHRType '[^[:space:]]\s*\zs--->\ze\s*'
syntax cluster prologDefineConstraint contains=prologDefineConstraintRule,prologDefineCHRRule,prologDefineCHRType
highlight link prologDefineConstraint prologSpecial
highlight link prologDefineConstraintRule prologSpecial
highlight link prologDefineCHRRule prologSpecial
highlight link prologDefineCHRType prologSpecial

syntax region prologRuleBodyMultiple keepend
\   matchgroup=prologDefineRule skipwhite skipempty start='\zs:-\ze'
\   contains=@prologBodyToken,@prologComment skip="%.*$"
\   matchgroup=prologEndingRule excludenl end='\.\ze\s*\_[%]'
syntax region prologRuleBodyNoHead keepend
\   matchgroup=prologDefineRule skipwhite skipempty start='^\zs:-\ze'
\   contains=@prologBodyToken,@prologComment skip="%.*$"
\   matchgroup=prologEndingRule excludenl end='\.\ze\s*\_[%]'
syntax region prologRuleBodySingle oneline
\   matchgroup=prologDefineRule skipwhite start='^\zs:-\ze.'
\   contains=@prologBodyToken,@prologDirective,@prologDirectiveOption,@prologDefineConstraint
\   matchgroup=prologEndingRule end='\.\ze\s*\_[%]'
syntax cluster prologRuleBody contains=prologRuleBodySingle,prologRuleBodyMultiple,prologRuleBodyNoHead

" multi-line regions
syntax region prologConstraintBody keepend
\   matchgroup=prologDefineConstraint skipwhite skipempty start='-->>\?'
\   contains=@prologBodyToken,@prologComment
\   matchgroup=prologEndingRule end='\.\ze\s*\_[%]'
syntax region prologCHRBody keepend
\   matchgroup=prologDefineConstraint skipwhite skipempty start='==>>\?'
\   contains=@prologBodyToken,@prologComment
\   matchgroup=prologEndingRule end='\.\ze\s*\_[%]'
syntax region prologCHRBody keepend
\   matchgroup=prologDefineConstraint skipwhite skipempty start='<=>'
\   contains=@prologBodyToken,@prologComment
\   matchgroup=prologEndingRule end='\.\ze\s*\_[%]'
syntax region prologGuardedRuleBody keepend
\   matchgroup=prologDefineConstraint skipwhite skipempty start='=>'
\   contains=@prologBodyToken,@prologComment
\   matchgroup=prologEndingRule end='\.\ze\s*\_[%]'
syntax cluster prologBody contains=prologRuleBody,prologConstraintBody,prologCHRBody,prologGuardedRuleBody

" XXX: highlighting doesn't seem to work inside a cluster, so this is more a reference than anything else.
syntax cluster prologToken contains=prologAtom,prologNumber,prologOperator,prologVariable,prologAnonymousVariable,prologSpecialCharacter
syntax cluster prologBodyToken contains=@prologBuiltin,@prologLibrary,@prologToken,prologString,prologCharCodes,prologTopLevel
syntax cluster prologHeadParenthesesToken contains=@prologToken,prologStringprologCharCodes,

syntax match prologHead '^\zs\a[[:alnum:]_:]*\ze\s*(' skipwhite keepend nextgroup=prologHeadParentheses
syntax region prologHeadParentheses start='\zs(' contains=@prologHeadParenthesesToken end=')\ze' nextgroup=prologNextHead,@prologBody contained
syntax match prologHead '^\zs\a[[:alnum:]_:]*\ze\s*\(:-\|=>\|-->\|==>\|<=>\|\.\)' skipwhite keepend

" XXX: it might be better to explicitly match the head continuation
"      characters (',' and '\\') before chaining the the next head.
syntax match prologHead '^\zs\a[[:alnum:]_:]*\ze\s*[,\\]\@=' skipwhite keepend nextgroup=prologNextHead
highlight link prologNextHead prologHead

syntax match prologNextHead '[\\@]\s*\a[[:alnum:]_:]*\ze\s*(' skipwhite keepend nextgroup=prologHeadParentheses contains=prologSpecialCharacter,prologCHRSpecialCharacter
syntax match prologNextHead '[\\@]\s*\a[[:alnum:]_:]*\ze\s*[,\\]\@=' skipwhite keepend nextgroup=prologNextHead  contains=prologSpecialCharacter,prologCHRSpecialCharacter
syntax match prologNextHead '[\\@]\s*\a[[:alnum:]_:]*\ze\s*\(:-\|=>\|-->\|==>\|<=>\|\.\)\@=' skipwhite keepend nextgroup=@prologBody contains=prologSpecialCharacter,prologCHRSpecialCharacter
syntax match prologNextHead '[,]\zs\s*\a[[:alnum:]_:]*\s*\ze(' skipwhite keepend nextgroup=prologHeadParentheses
syntax match prologNextHead '[,]\zs\s*\a[[:alnum:]_:]*\s*\ze[,\\]\@=' skipwhite keepend nextgroup=prologNextHead
syntax match prologNextHead '[,]\zs\s*\a[[:alnum:]_:]*\s*\ze\(:-\|=>\|-->\|==>\|<=>\|\.\)\@=' skipwhite keepend nextgroup=@prologBody contains=prologSpecialCharacter

syntax match prologCHRName '^\zs\a\w*\s*@' skipwhite keepend nextgroup=prologCHRHead,prologNextHead contains=prologCHRSpecialCharacter
highlight link prologCHRName prologQuestion
syntax match prologCHRHead '\a\w*\s*(\@=' skipwhite keepend nextgroup=prologHeadParentheses contained
syntax match prologCHRHead '\a\w*\s*[,]\@=' skipwhite keepend nextgroup=prologNextHead contained
syntax match prologCHRHead '\a\w*\s*[\\]\@=' skipwhite keepend nextgroup=prologNextHead contained contains=prologCHRSpecialCharacter
syntax match prologCHRHead '\zs\a\w*\ze\s*\(:-\|=>\|-->\|==>\|<=>\|\.\)\@=' skipwhite keepend nextgroup=@prologBody contained
highlight link prologCHRHead prologHead

syntax match prologCHRSpecialCharacter contained '\\'
syntax match prologCHRSpecialCharacter contained '@'
highlight link prologCHRSpecialCharacter prologSpecial

" Strings and Atoms
syntax region prologString start=+"+ skip=+\(\\\\\)\|\(\\\)\|\(\c$\)"+ end=+"+ contains=@Spell
syntax region prologAtom start=+'+ skip=+\(\\\\\)\|\(\\\)\|\(\c$\)'+ end=+'+
syntax region prologCharCodes start=+`+ skip=+\(\\\\\)\|\(\\\)\|\(\c$\)"+ end=+`+ contains=@Spell

" Comments
syn match   prologLineComment   +%.*+                   contains=@Spell
syn region  prologCComment      start=+/\*+ end=+\*/+   contains=@Spell
syn match   prologCCommentError "\*/"
syntax cluster prologComment contains=prologLineComment,prologCComment,prologCCommentError

highlight link prologLineComment    prologComment
highlight link prologCComment       prologComment
highlight link prologCCommentError  prologError

""" highlighting stolen from prolog.vim
highlight link prologNumber         Number
highlight link prologAtom           Constant
highlight link prologString         String
highlight link prologCharCodes      String
highlight link prologOperator       Operator
highlight link prologComment        Comment
highlight link prologOption         Tag
highlight link prologQuestion       PreProc
highlight link prologSpecial        Special
highlight link prologError          Error
highlight link prologKeyword        Keyword

highlight link prologHead           Constant
highlight link prologInterpreter    NonText
highlight link prologLibrary        Type
highlight link prologDirective      PreProc

let &cpoptions = s:cpoptions_save
unlet s:cpoptions_save

" take over the default prolog.vim syntax.
let b:current_syntax = 'prolog'
