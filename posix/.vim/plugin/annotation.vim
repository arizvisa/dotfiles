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
    let notes = exists('data.notes')? data.notes : {}

    let res = []
    for id in sort(keys(notes))
        call add(res, printf('%s: %s', 1 + len(res), notes[id]))
    endfor
    return res
endfunction

"function! TestSetPropertyData(property)
"    let data = annotation#state#getdata(a:property.bufnr, a:property.id)
"    if !exists('data.notes')
"        let data.notes = []
"    endif
"    let data.notes += [printf('Line %d', len(data.notes))]
"    return data
"endfunction
"
"function! ShowMenu(property)
"    let items = {1: 'First item', 2: 'Second item', 3: 'Third item'}
"    let title = 'Choose one'
"    function! DoIt(id, label) closure
"        function! SetData(property) closure
"            let data = annotation#state#getdata(a:property.bufnr, a:property.id)
"            if !exists('data.notes')
"                let data.notes = []
"            endif
"            let data.notes += [printf('Line %d: (%s) %s', len(data.notes), a:label, items[a:label])]
"            return data
"        endfunction
"        call annotation#frontend#set_property_data(a:property.bufnr, a:property.lnum, a:property.col, funcref('SetData'))
"    endfunction
"    call annotation#ui#menu(items, title, {}, funcref('DoIt'))
"endfunction

" FIXME: add menu item to abort modification
function! BuildMenuFromAnnotations(property)
    let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)
    let notes = exists('data.notes')? data.notes : {}

    let items = {}
    for index in sort(copy(keys(notes)))
        " XXX: not sure why the following line doesn't work.
        "let description = (notes[index] == v:t_string)? notes[index] : join(notes[index])
        let description = notes[index]
        let items[index] = description
    endfor
    echoconsole 4
    return items
endfunction

function! ModifyAnnotationItem(property, index)
    let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)

    " get user input, using the original data as the default.
    let old = data.notes[a:index]
    let new = annotation#ui#readinput('Modify: ', old)
    let data.notes[a:index] = new

    " write it back into the property data.
    call annotation#frontend#set_property_data(a:property.bufnr, a:property.lnum, a:property.col, copy(data), a:property.id)
endfunction

function! ModifyAnnotation(property, title='Modifying')
    let items = BuildMenuFromAnnotations(a:property)
    echoconsole items

    function! ModifySelected(id, label) closure
        echomsg printf('Selected %s: %s', a:label, items[a:label])
        call ModifyAnnotationItem(a:property, a:label)
    endfunction

    let options = {}
    call annotation#ui#menu(items, a:title, options, funcref('ModifySelected'))
endfunction

function! AddAnnotation(property, title='Adding')
    let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)

    " get user input.
    let annotation = annotation#ui#readinput('Add: ')

    " initialize the data if it hasn't been done yet.
    if !exists('data.notes')
        let data.notes = {}
    endif

    " assign the data, and then update the property
    let key = len(data.notes)
    let data.notes[key] = annotation

    call annotation#frontend#set_property_data(a:property.bufnr, a:property.lnum, a:property.col, copy(data), a:property.id)
endfunction

" FIXME: add menu item to abort removal
function! RemoveAnnotation(property, title='Removing')
    let items = BuildMenuFromAnnotations(a:property)

    function! RemoveSelected(id, label) closure
        echomsg printf('Selected %s: %s', a:label, items[a:label])
        let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)
        let removed = remove(data.notes, a:label)
        echomsg printf('Removed %s: %s', a:label, removed)
        call annotation#frontend#set_property_data(a:property.bufnr, a:property.lnum, a:property.col, data, a:property.id)
    endfunction

    let options = {}
    call annotation#ui#menu(items, a:title, options, funcref('RemoveSelected'))
endfunction

function! ShowAnnotationEditMenu(property, title='Edit')
    let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)

    let items = {}
    let items[1] = '1. Add a new annotation to the current line.'

    if exists('data.notes') && !empty(data.notes)
        let items[2] = '2. Modify an existing annotation of the current line.'
        let items[3] = '3. Remove a specific annotation from the current line.'
    endif
    let items[4] = '4. Abort'

    function! ShowSelected(id, label) closure
        if exists('data[a:label]')
            echomsg printf('Selected %s: %s', a:label, data[a:label])
        else
            echomsg printf('Selected %s', a:label)
        endif

        if a:label == 1
            call AddAnnotation(a:property, a:title)
        elseif a:label == 2
            call ModifyAnnotation(a:property, a:title)
        elseif a:label == 3
            call RemoveAnnotation(a:property, a:title)
        else
            echomsg printf('Abort!')
        endif
    endfunction

    let options = {}
    call annotation#ui#menu(items, a:title, options, funcref('ShowSelected'))
endfunction

function! DoMenu()
    let prop = annotation#property#get(bufnr(), col('.'), line('.'), 'annotation')
    let [property, _] = annotation#state#getprop(bufnr(), prop.id)
    "call ShowMenu(property)
    call ShowAnnotationEditMenu(property)
endfunction

xmap <C-m>n <Esc><Cmd>call annotation#frontend#add_property(bufnr(), getpos("'<")[1], getpos("'<")[2], getpos("'>")[1], 1 + getpos("'>")[2])<CR>
nmap <C-m>n <Esc><Cmd>call annotation#frontend#add_property(bufnr(), line('.'), match(getline('.'), '\S'), line('.'), col('$'))<CR>
nmap <C-m>x <Cmd>call annotation#frontend#del_property(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
nmap <C-m>N <Cmd>call annotation#frontend#set_property_data(bufnr(), getpos('.')[1], getpos('.')[2], funcref('TestSetPropertyData'))<CR>
nmap <C-m>? <Cmd>call annotation#frontend#show_property_data(bufnr(), getpos('.')[1], getpos('.')[2], funcref('TestGetPropertyData'))<CR>
