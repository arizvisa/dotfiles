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
    let prop = annotation#property#get(a:bufnum, a:col, a:lnum, g:annotation_property)
    if empty(prop)
        throw printf('annotation.MissingPropertyError: no property was found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
    endif
    let [property, _] = annotation#state#getprop(bufnr(), prop.id)
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
    echoconsole printf('Fetched data from property %d: %s', property.id, data)
    let notes = exists('data.notes')? data.notes : {}

    let res = []
    for id in sort(keys(notes))
        call add(res, printf('%s: %s', 1 + len(res), notes[id]))
    endfor
    return res
endfunction

xmap <C-m>n <Esc><Cmd>call AddProperty(bufnr(), getpos("'<")[1], getpos("'<")[2], getpos("'>")[1], 1 + getpos("'>")[2])<CR>
nmap <C-m>n <Esc><Cmd>call AddProperty(bufnr(), line('.'), 1 + match(getline('.'), '\S'), line('.'), col('$'))<CR>
nmap <C-m>x <Cmd>call RemoveProperty(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
nmap <C-m>N <Cmd>call ModifyProperty(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
nmap <C-m>? <Cmd>call ShowProperty(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
