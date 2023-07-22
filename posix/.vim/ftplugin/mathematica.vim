"Vim filetype plugin
" Language: Mathematica
" Maintainer: R. Menon <rsmenon@icloud.com>
" Last Change: Feb 26, 2013

" Initialization {
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim
"}

setlocal ts=2
setlocal sw=2

" Cleanup {
let &cpo = s:cpo_save
unlet s:cpo_save
"}

" vim: set foldmarker={,} foldlevel=0 foldmethod=marker:
