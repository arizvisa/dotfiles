""" Text-properties / Virtual-text test for annotation of plaintext files.
""" XXX: This is _very_ preliminary and still being experimented with.

if exists('g:loaded_annotation') && g:loaded_annotation
    finish
endif
let g:loaded_annotation = v:true

""" FIXME: the things in this script need to be renamed and refactored into
"""        their own autoload library as the `annotation#frontend` namespace.
let g:annotation_property = 'annotation'

" FIXME: need some event for dealing with (empty) buffers created at startup
augroup annotations
    autocmd!
    autocmd BufRead * call annotation#frontend#add_buffer(expand('<abuf>'))
    autocmd BufAdd * call annotation#frontend#add_buffer(expand('<abuf>'))
    autocmd BufDelete * call annotation#frontend#del_buffer(expand('<abuf>'))
augroup END

call prop_type_add(g:annotation_property, {'highlight': 'DiffText', 'override': v:true})

function! ModifyProperty(bufnum, lnum, col)
    let property = annotation#property#get(a:bufnum, a:col, a:lnum, g:annotation_property)
    if empty(property)
        throw printf('annotation.MissingPropertyError: no property was found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
    endif
    call ModifyPropertyItem(a:bufnum, property)
endfunction

function! ModifyPropertyItem(bufnum, property)
    let [property, _] = annotation#state#getprop(a:bufnum, a:property.id)
    call annotation#menu#modify(property)
endfunction

function! AddProperty(bufnum, lnum, col, end_lnum, end_col)
    let property = annotation#frontend#add_property(a:bufnum, a:lnum, a:col, a:end_lnum, a:end_col)
    call annotation#menu#add(property)
endfunction

function! RemoveProperty(bufnum, lnum, col)
    call annotation#frontend#del_property(a:bufnum, a:lnum, a:col, g:annotation_property)
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
function! AddOrModifyProperty(bufnum, lnum, col, end_lnum, end_col)
    let properties = annotation#property#at(a:bufnum, a:col, a:lnum)

    if empty(properties)
        call AddProperty(a:bufnum, a:lnum, a:col, a:end_lnum, a:end_col)
    else
        let ids = keys(properties)
        let first = ids[0]
        call ModifyPropertyItem(a:bufnum, properties[first])
    endif
endfunction

xmap <C-m>n <Esc><Cmd>call AddOrModifyProperty(bufnr(), getpos("'<")[1], getpos("'<")[2], getpos("'>")[1], 1 + getpos("'>")[2])<CR>
nmap <C-m>n <Esc><Cmd>call AddOrModifyProperty(bufnr(), line('.'), 1 + match(getline('.'), '\S'), line('.'), col('$'))<CR>
nmap <C-m>d <Cmd>call RemoveProperty(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
nmap <C-m>? <Cmd>call ShowProperty(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
