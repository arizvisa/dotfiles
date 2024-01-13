if exists("b:current_syntax")
    finish
endif

let s:cpoptions_save = &cpoptions
set cpoptions&vim

""" global settings
syntax case match
syntax sync maxlines=64

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
\    '\*\?->', '|', '^',
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

syn keyword prologBuiltin_metacall apply call call_cleanup call_with_depth_limit call_with_inference_limit ignore not once setup_call_catcher_cleanup setup_call_cleanup undo
highlight default link prologBuiltin_metacall prologBuiltin
syn keyword prologBuiltin_flag create_prolog_flag current_prolog_flag set_prolog_flag
highlight link prologBuiltin_flag prologBuiltin
syn keyword prologBuiltin_tabling abolish_all_tables abolish_module_tables abolish_nonincremental_tables abolish_private_tables abolish_shared_tables abolish_table_subgoals current_table not_exists tabled_call tnot untable
highlight link prologBuiltin_tabling prologBuiltin
syn keyword prologBuiltin_trace prolog_trace_interception prolog_skip_frame prolog_skip_level
highlight link prologBuiltin_trace prologBuiltin
syn keyword prologBuiltin_environment prolog_current_frame prolog_current_choice prolog_cut_to prolog_frame_attribute deterministic
highlight link prologBuiltin_environment prologBuiltin

syn keyword prologTopLevel prolog prolog:called_by prolog:hook prolog:meta_goal prolog:message_line_element prolog:message_prefix_hook prolog_edit:edit_command prolog_edit:edit_source prolog_edit:load prolog_edit:locate prolog:debug_control_hook prolog_edit:edit_command prolog_edit:edit_source prolog_edit:locate prolog:help_hook
syn keyword prologTopLevel abort break expand_answer expand_query halt gxref attach_packs edit
syn keyword prologTopLevel message_hook message_property message_to_string print_message print_message_lines thread_message_hook version
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
syn keyword prologLibrary_shlib use_foreign_library compat_arch load_foreign_library unload_foreign_library current_foreign_library reload_foreign_library
highlight link prologLibrary_shlib prologLibrary
syn keyword prologLibrary_prolog_xref xref_called xref_clean xref_comment xref_current_source xref_defined xref_definition_line xref_done xref_exported xref_hook xref_meta xref_meta_src xref_mode xref_module xref_op xref_option xref_prolog_flag xref_public_list xref_source xref_source_file xref_uses_file
highlight link prologLibrary_prolog_xref prologLibrary
syn keyword prologLibrary_prolog_pack pack_attach pack_info pack_install pack_list pack_list_installed pack_property pack_rebuild pack_remove pack_search pack_upgrade pack_url_file
highlight link prologLibrary_prolog_pack prologLibrary

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

" FIXME: numbers can also include the _ as a separator (that gets ignored)
" FIXME: we can also include Inf [+-]?\sd+[.]\sd+Inf or 1.5NaN or nan.
"syn match prologNumber '[-+]\=\<\d\+\.\d\+\>'
syn match prologNumber '[-+]\=\<\d\+\.\d\+\%[NaN]\>'
syn match prologNumber '[-+]\=\<\d\+\.\d\+\%[Inf]\>'
syn match prologNumber '[-+]\=inf\>'
syn match prologNumber '[-+]\=nan\>'
syn match prologNumber '[-+]\=\<\d\+r\d\+\>'

" hopefully the rest of these numbers work...
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
syn match prologSpecialCharacter ';'
syn match prologSpecialCharacter '!'
syn match prologSpecialCharacter '[^\$]\zs\$\ze\_[^\$]'
syn match prologSpecialCharacter '[()[:space:][:alnum:]]\zs:-\ze'
syn match prologSpecialCharacter '[()[:space:][:alnum:]]\zs?-\ze'
syn match prologSpecialCharacter '[()[:space:][:alnum:]]\zs-->\ze'
syn match prologSpecialCharacter '^'
syn match prologSpecialCharacter '|'
syn match prologSpecialCharacter '{|}'
syn match prologSpecialCharacter '\[|\]'
syn match prologSpecialCharacter '\<_\w*\>'

" add the '~' character used by package(func)
let without_tilde = s:exclude_dict(s:prologSymbols, ['~', '.'])
let tilde_pattern = printf('[[:space:][:alnum:]%s]\zs%s\ze\_[[:space:][:alnum:]%s]', join(values(without_tilde), ""), '\~', join(values(without_tilde), ""))
execute printf("syn match prologSpecialCharacter '%s'", tilde_pattern)
highlight link prologSpecialCharacter prologSpecial
syn match prologSpecial '^:-\s*$'

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

execute printf('syntax match prologOperator "%s"', join(all_operators, '\|'))

""" Conditions and compilation related things
syn keyword prologDirective_words contained module meta_predicate multifile dynamic det
syn keyword prologDirective_words contained discontiguous public non_terminal use_module
syn keyword prologDirective_conditionals contained if elif else endif
syn keyword prologDirective_autoload contained autoload_path make_library_index reload_library_index
syn keyword prologDirective_save contained autoload_all qsave_program volatile
syn keyword prologDirective_shlib contained use_foreign_library compat_arch load_foreign_library unload_foreign_library current_foreign_library reload_foreign_library
syn keyword prologDirective_hook contained attr_unify_hook exception file_search_path goal_expansion library_directory message_hook message_prefix_hook message_property portray prolog_list_goal prolog_load_file resource term_expansion
syn keyword prologDirective_events contained prolog_listen prolog_unlisten
syn keyword prologDirective_tabling contained table
syn keyword prologDirective_trace contained prolog_trace_interception prolog_skip_frame prolog_skip_level

highlight link prologDirective_words prologDirective
highlight link prologDirective_conditionals prologDirective
highlight link prologDirective_autoload prologDirective
highlight link prologDirective_save prologDirective
highlight link prologDirective_shlib prologDirective
highlight link prologDirective_hook prologDirective
highlight link prologDirective_events prologDirective
highlight link prologDirective_tabling prologDirective

"syn keyword prologOption_create_prolog_flag_option contained access type keep
"syn keyword prologOption_current_prolog_flag_option contained abi_version access_level address_bits agc_close_streams agc_margin allow_dot_in_atom allow_variable_name_as_functor android android_api answer_write_options apple arch argv associated_file autoload back_quotes backtrace backtrace_depth backtrace_goal_depth backtrace_show_lines bounded break_level c_cc c_cflags character_escapes character_escapes_unicode char_conversion c_ldflags c_libplso c_libs cmake_build_type colon_sets_calling_context color_term compiled_at compile_meta_arguments conda console_menu cpu_count dde debug debugger_show_context debugger_write_options debug_on_error debug_on_interrupt determinism_error dialect double_quotes editor emacs_inferior_process encoding executable executable_format exit_status file_name_case_handling file_name_variables file_search_cache_time float_max float_max_integer float_min float_overflow float_rounding float_undefined float_underflow float_zero_div gc gc_thread generate_debug_info gmp_version gui heartbeat history home hwnd integer_rounding_function iso large_files last_call_optimisation libswipl malloc max_answers_for_subgoal max_answers_for_subgoal_action max_arity max_char_code max_integer max_procedure_arity max_rational_size max_rational_size_action max_table_answer_size max_table_answer_size_action max_table_subgoal_size max_table_subgoal_size_action max_tagged_integer message_context min_integer min_tagged_integer mitigate_spectre msys2 occurs_check on_error on_warning open_shared_object optimise optimise_unify os_argv packs path_max pid pipe portable_vmi posix_shell prefer_rationals print_write_options prompt_alternatives_on protect_static_code qcompile rational_syntax readline report_error resource_database runtime sandboxed_load saved_program shared_home shared_object_extension shared_object_search_path shared_table_space shift_check signals stack_limit stream_type_check string_stack_tripwire system_thread_id table_incremental table_shared table_space table_subsumptive threads timezone tmp_dir toplevel_goal toplevel_list_wfs_residual_program toplevel_mode toplevel_name_variables toplevel_print_anon toplevel_print_factorized toplevel_prompt toplevel_residue_vars toplevel_var_size trace_gc traditional tty_control unix unknown unload_foreign_libraries user_flags var_prefix verbose verbose_autoload verbose_file_search verbose_load version version_data version_git vmi_builtin warn_autoload warn_override_implicit_import windows wine_version win_file_access_check write_attributes write_help_with_overstrike xpce xpce_version xref
"syn keyword prologOption_qsave_program contained autoload class emulator foreign goal init_file map obfuscate op stack_limit stand_alone toplevel undefined verbose
"syn keyword prologOption_open_resource contained type encoding bom
"syn keyword prologOption_resource contained include exclude
"syn keyword prologOption_register_irl_scheme contained open access time size
"syn keyword prologOption_open contained alias bom buffer close_on_abort create encoding eof_action locale lock newline reposition type wait
"syn keyword prologOption_open_create contained read write execute default all
"syn keyword prologOption_stream_property contained alias buffer buffer_size bom close_on_abort close_on_exec encoding end_of_stream eof_action error file_name file_no input locale mode newline nlink output position reposition representation_errors timeout type tty write_errors
"syn keyword prologOption_set_stream contained alias buffer buffer_size close_on_abort close_on_exec encoding eof_action file_name line_position locale newline timeout type record_position representation_errors tty
"syn keyword prologOption_load_foreign_library contained install
"syn keyword prologOption_autoload contained false explicit user user_or_explicit tree
"syn keyword prologOption_compile_meta_arguments contained false control always
"syn keyword prologOption_file_name_case_handling contained case_sensitive case_preserving case_insensitive
"syn keyword prologOption_pack_install contained url package_directory global insecure interactive silent upgrade rebuild test git link
"syn keyword prologOption_pack_property contained directory version title author download readme todo
"syn keyword prologOption_pack_attach contained duplicate search
"syn keyword prologOption_prolog_listen contained as name abort erase break frame_finished thread_exit thread_start this_thread_exit
"syn keyword prologOption_exception contained undefined_predicate undefined_global_variable
"syn keyword prologOption_prolog_trace_interception contained call redo unify exit fail exception cut_call cut_exit
"syn keyword prologOption_prolog_frame_attribute contained alternative has_alternative goal parent_goal predicate_indicator clause level parent context_module top hidden skipped pc argument
"syn keyword prologOption_prolog_choice_attribute contained parent frame type pc clause

syn match prologSpecialCharacter '^:-' nextgroup=prologDirective_words,prologDirective_conditionals,prologDirective_autoload,prologDirective_save,prologDirective_shlib,prologDirective_hook,prologdirective_events,prologDirective_tabling skipwhite

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

" take over the default prolog.vim syntax.
let b:current_syntax = 'prolog'
