""" Text-properties / Virtual-text test for annotation of plaintext files.
""" XXX: This is _very_ preliminary and still being experimented with.

if exists('g:loaded_annotation') && g:loaded_annotation
  finish
elseif !has('textprop')
  echohl WarningMsg | echomsg printf("Refusing to load the annotation.vim plugin due to the host editor missing the \"%s\" feature.", 'textprop') | echohl None
  finish
endif
let g:loaded_annotation = v:true

""" FIXME: the things in this script need to be renamed and refactored into
"""        their own autoload library as the `annotation#frontend` namespace.
let g:annotation_property = 'annotation'

augroup annotations
  autocmd!

  " Managing the scope of a buffer by adding and removing the annotation state.
  autocmd BufRead * call annotation#frontend#add_buffer(expand('<abuf>'))
  autocmd BufAdd * call annotation#frontend#add_buffer(expand('<abuf>'))
  autocmd BufDelete * call annotation#frontend#del_buffer(expand('<abuf>'))

  " Loading and saving the annotations associated with a buffer.
  autocmd BufReadPost * call annotation#frontend#load_buffer(expand('<abuf>'), expand('<afile>'))
  autocmd BufWritePost * call annotation#frontend#save_buffer(expand('<abuf>'), expand('<afile>'))
  autocmd BufLeave * call annotation#frontend#save_buffer(expand('<abuf>'), expand('<afile>'))

  " Add the initial empty buffer that exists on startup.
  autocmd VimEnter * call annotation#frontend#add_buffer(expand('<abuf>'))
  autocmd SessionLoadPost * call s:LoadAnnotionsForBuffers()

  " If vim is leaving, then try and save the current buffer.
  autocmd VimLeavePre * call annotation#frontend#save_buffer(expand('<abuf>'), expand('<afile>'))
augroup END

call prop_type_add(g:annotation_property, {'highlight': 'DiffText', 'override': v:true})

function! s:LoadAnnotionsForBuffers()
  let filtered = []
  for bufinfo in getbufinfo()
    if exists('bufinfo.name')
      call add(filtered, bufinfo)
    endif
  endfor

  " Iterate through all of the buffers where we have a path, add if they don't
  " exist and then try to load them.
  for bufinfo in filtered
    if !bufloaded(bufinfo.bufnr)
      call bufload(bufinfo.bufnr)
    endif
    if bufloaded(bufinfo.bufnr)
      call annotation#frontend#load_buffer(bufinfo.bufnr, bufinfo.name)
    endif
  endfor
endfunction

function! ModifyProperty(bufnum, lnum, col)
  let property = annotation#property#get(a:bufnum, a:col, a:lnum, g:annotation_property)
  if empty(property)
    throw printf('annotation.MissingPropertyError: no property was found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
  endif
  call ModifyPropertyItem(a:bufnum, property)
endfunction

function! ModifyPropertyItem(bufnum, property)
  let property = annotation#state#getprop(a:bufnum, a:property.id)
  call annotation#menu#modify(property)
endfunction

function! AddProperty(bufnum, lnum, col, end_lnum, end_col)
  let property = annotation#frontend#add_property(a:bufnum, a:lnum, a:col, a:end_lnum, a:end_col)
  call annotation#menu#add(property)
endfunction

function! RemoveProperty(bufnum, lnum, col)
  let current = annotation#property#get(a:bufnum, a:col, a:lnum, g:annotation_property)
  if !empty(current)
    call annotation#frontend#del_property(a:bufnum, a:lnum, a:col, current['id'])
  endif
endfunction

function! ShowProperty(bufnum, lnum, col)
  call annotation#frontend#show_property_data(a:bufnum, a:lnum, a:col, funcref('GetPropertyData'))
endfunction

function! GetPropertyData(property)
  let [property, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)
  let notes = exists('data.notes')? data.notes : {}

  let res = []
  for id in sort(keys(notes))
    call add(res, printf('%s: %s', 1 + len(res), notes[id]))
  endfor
  return res
endfunction

" FIXME: should check for overlapping properties too.
function! AddOrModifyProperty(bufnum, y, x, lnum, col, end_lnum, end_col)
  let ids = annotation#state#find_bounds(a:bufnum, a:col, a:lnum, a:end_col, a:end_lnum)
  let properties = mapnew(ids, 'annotation#state#getprop(a:bufnum, v:val)')
  let current = annotation#property#get(a:bufnum, a:x, a:y, g:annotation_property)

  " If there is no text at the specified line number, then we throw up an error
  " since there's no content that can be selected. Currently we do not support
  " annotations spanning multiple lines.. when we do this code will need fixing.
  let content = getline(a:lnum)
  if empty(ids) && empty(current) && !strwidth(content) && a:lnum == a:end_lnum
    echohl ErrorMsg | echomsg printf("annotation.MissingContentError: unable to add an annotation due to line %d having no columns (%d).", a:lnum, strwidth(content)) | echohl None

  " If there are no annotations found, then go ahead and add a new one.
  elseif empty(ids) && empty(current)
    let maxcol = 1 + strwidth(getline(a:end_lnum))
    call AddProperty(a:bufnum, a:lnum, a:col, a:end_lnum, min([a:end_col, maxcol]))

  " If there were some annotation ids, then we can go ahead and modify it.
  elseif !empty(current)
    call ModifyPropertyItem(a:bufnum, current)

  " Check the span of a single line to figure out the annotation to modify.
  elseif a:lnum == a:end_lnum
    let filtered = annotation#property#filter_by_span(properties, a:col, a:end_col, a:lnum)
    let property = filtered[0]
    call ModifyPropertyItem(a:bufnum, property)
  endif
endfunction

function! CursorForward(bufnum, lnum, col)
  let [x, y] = annotation#property#scanforward(a:bufnum, a:col, a:lnum, g:annotation_property)
  if [a:col, a:lnum] != [x, y]
    let res = (cursor(y, x) < 0)? v:false : v:true
  else
    let res = v:false
  endif
  return res
endfunction

function! CursorBackward(bufnum, lnum, col)
  let [x, y] = annotation#property#scanbackward(a:bufnum, a:col, a:lnum, g:annotation_property)
  if [a:col, a:lnum] != [x, y]
    let res = (cursor(y, x) < 0)? v:false : v:true
  else
    let res = v:false
  endif
  return res
endfunction

xmap <C-m>n <Esc><Cmd>call AddOrModifyProperty(bufnr(), line('.'), col('.'), getpos("'<")[1], getpos("'<")[2], getpos("'>")[1], 1 + getpos("'>")[2])<CR>
nmap <C-m>n <Esc><Cmd>call AddOrModifyProperty(bufnr(), line('.'), col('.'), line('.'), 1 + match(getline('.'), '\S'), line('.'), col('$'))<CR>
nmap <C-m>d <Cmd>call RemoveProperty(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
nmap <C-m>? <Cmd>call ShowProperty(bufnr(), getpos('.')[1], getpos('.')[2])<CR>

nmap <C-m>[ <Cmd>call CursorBackward(bufnr(), line('.'), col('.'))<CR>
nmap <C-m>] <Cmd>call CursorForward(bufnr(), line('.'), col('.'))<CR>
nmap <C-m><C-[> <Cmd>call CursorBackward(bufnr(), line('.'), col('.'))<CR>
nmap <C-m><C-]> <Cmd>call CursorForward(bufnr(), line('.'), col('.'))<CR>
