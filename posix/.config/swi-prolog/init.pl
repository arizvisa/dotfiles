:- use_module(library(prolog_pack)).

%- http://packs.ndrix.com/func/index.html
:- not(prolog_pack:current_pack(func)) -> pack_install(func); true.
:- use_module(library(func)).

%- http://packs.ndrix.com/spawn/index.html
:- not(prolog_pack:current_pack(spawn)) -> pack_install(spawn); true.
:- use_module(library(spawn)).

%- http://packs.ndrix.com/mavis/index.html
:- not(prolog_pack:current_pack(quickcheck)) -> (format("WARNING: Do not run the post-installation scripts for ~w~n", [quickcheck]), pack_install(quickcheck)); true.
:- not(prolog_pack:current_pack(mavis)) -> pack_install(mavis); true.
:- use_module(library(mavis)).

%- https://www.swi-prolog.org/pack/list?p=dcgutils
:- not(prolog_pack:current_pack(dcgutils)) -> pack_install(dcgutils); true.
%:- use_module(library(dcg_core)).
:- use_module(library(dcg_progress)).

%- https://github.com/kamahen/edcg
:- not(prolog_pack:current_pack(edcg)) -> pack_install(edcg); true.
:- use_module(library(edcg)).

%- https://github.com/jamesnvc/lsp_server
%:- not(prolog_pack:current_pack(lsp_server)) -> pack_install(lsp_server); true.
