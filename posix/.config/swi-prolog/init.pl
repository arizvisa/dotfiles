:- use_module(library(prolog_pack)).

%- https://www.swi-prolog.org/pack/list?p=func
:- not(prolog_pack:current_pack(function_expansion)) -> pack_install(function_expansion); true.
:- not(prolog_pack:current_pack(list_util)) -> pack_install(list_util); true.
:- not(prolog_pack:current_pack(func)) -> pack_install(func); true.
:- use_module(library(func)).

%- https://www.swi-prolog.org/pack/list?p=spawn
:- not(prolog_pack:current_pack(spawn)) -> pack_install(spawn); true.
:- use_module(library(spawn)).

%- https://www.swi-prolog.org/pack/list?p=mavis
:- not(prolog_pack:current_pack(list_util)) -> pack_install(list_util); true.
:- not(prolog_pack:current_pack(quickcheck)) -> (format("WARNING: Do not run the post-installation scripts for ~w~n", [quickcheck]), pack_install(quickcheck)); true.
:- not(prolog_pack:current_pack(mavis)) -> pack_install(mavis); true.
:- use_module(library(mavis)).

%- https://www.swi-prolog.org/pack/list?p=dcgutils
:- not(prolog_pack:current_pack(genutils)) -> pack_install(genutils); true.
:- not(prolog_pack:current_pack(dcgutils)) -> pack_install(dcgutils); true.
%:- use_module(library(dcg_core)).
:- use_module(library(dcg_progress)).

%- https://www.swi-prolog.org/pack/list?p=edcg -> https://github.com/kamahen/edcg.git
%:- not(prolog_pack:current_pack(edcg)) -> pack_install(edcg); true.
:- not(prolog_pack:current_pack(edcg)) -> pack_install('https://github.com/kamahen/edcg.git', [git(true), version('0.9.1.8')]); true.
:- use_module(library(edcg)).

%- https://github.com/ptarau/AnswerStreamGenerators/lazy_streams-0.5.0
:- not(prolog_pack:current_pack(lazy_streams)) -> pack_install('https://github.com/arizvisa/lazy_streams.git', [git(true), version('0.5.0')]); true.
%:- use_module(library(lazy_streams)).

%- https://www.swi-prolog.org/pack/list?p=lsp_server
%:- not(prolog_pack:current_pack(lsp_server)) -> pack_install(lsp_server); true.
