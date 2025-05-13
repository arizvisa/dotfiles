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

function! TestGetPropertyData(property)
    let [property, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)
    echoconsole printf('Fetched data from property %d: %s', property.id, data)
    return exists('data.notes')? data.notes : []
endfunction

function! TestSetPropertyData(property)
    let data = annotation#state#getdata(a:property.bufnr, a:property.id)
    if !exists('data.notes')
        let data.notes = []
    endif
    let data.notes += [printf('Line %d', len(data.notes))]
    return data
endfunction

function! ShowMenu(property)
    let items = {1: 'First item', 2: 'Second item', 3: 'Third item'}
    let title = 'Choose one'
    function! DoIt(id, label) closure
        function! SetData(property) closure
            let data = annotation#state#getdata(a:property.bufnr, a:property.id)
            if !exists('data.notes')
                let data.notes = []
            endif
            let data.notes += [printf('Line %d: (%s) %s', len(data.notes), a:label, items[a:label])]
            return data
        endfunction
        call annotation#frontend#set_property_data(a:property.bufnr, a:property.lnum, a:property.col, funcref('SetData'))
    endfunction
    call annotation#ui#menu(items, title, {}, funcref('DoIt'))
endfunction

function! DoMenu()
    let prop = annotation#property#get(bufnr(), col('.'), line('.'), 'annotation')
    let [property, _] = annotation#state#getprop(bufnr(), prop.id)
    call ShowMenu(property)
endfunction

xmap <C-m>n <Esc><Cmd>call annotation#frontend#add_property(bufnr(), getpos("'<")[1], getpos("'<")[2], getpos("'>")[1], 1 + getpos("'>")[2])<CR>
nmap <C-m>n <Esc><Cmd>call annotation#frontend#add_property(bufnr(), line('.'), match(getline('.'), '\S'), line('.'), col('$'))<CR>
nmap <C-m>x <Cmd>call annotation#frontend#del_property(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
nmap <C-m>N <Cmd>call annotation#frontend#set_property_data(bufnr(), getpos('.')[1], getpos('.')[2], funcref('TestSetPropertyData'))<CR>
nmap <C-m>? <Cmd>call annotation#frontend#show_property_data(bufnr(), getpos('.')[1], getpos('.')[2], funcref('TestGetPropertyData'))<CR>
