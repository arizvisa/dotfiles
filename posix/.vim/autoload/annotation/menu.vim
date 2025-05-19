" Responsible for return a menu for selecting the annotations associated with a
" specific property.
" FIXME: add menu item to abort modification
function! annotation#menu#build(property)
    let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)
    let notes = exists('data.notes')? data.notes : {}

    let items = {}
    for index in sort(copy(keys(notes)))
        " XXX: not sure why the following line doesn't work.
        "let description = (notes[index] == v:t_string)? notes[index] : join(notes[index])
        let description = notes[index]
        let items[index] = description
    endfor
    return items
endfunction

" Read input from the user and add it as an annotation to the property.
function! s:add_property_data_item(property)
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

" Modify the data at the specified index associated with the selected property.
function! s:modify_property_data_item(property, index)
    let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)

    " get user input, using the original data as the default.
    let old = data.notes[a:index]
    let new = annotation#ui#readinput('Modify: ', old)
    let data.notes[a:index] = new

    " write it back into the property data.
    call annotation#frontend#set_property_data(a:property.bufnr, a:property.lnum, a:property.col, copy(data), a:property.id)
endfunction

" Display a menu for selecting an annotation item and editing it.
function! s:modify_property_data(property, title='Modifying')
    let items = annotation#menu#build(a:property)
    echoconsole items

    function! ModifySelected(id, label) closure
        echomsg printf('Selected %s: %s', a:label, items[a:label])
        call s:modify_property_data_item(a:property, a:label)
    endfunction

    let options = {}
    call annotation#ui#menu(items, a:title, options, funcref('ModifySelected'))
endfunction

" Display a menu for selecting an annotation item and removing it.
" FIXME: add menu item to abort removal
function! s:remove_property_data(property, title='Removing')
    let items = annotation#menu#build(a:property)

    function! RemoveSelected(id, label) closure
        echomsg printf('Selected %s: %s', a:label, items[a:label])
        let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)
        let removed = remove(data.notes, a:label)

        echomsg printf('Removed %s: %s', a:label, removed)
        if empty(data.notes)
            echomsg printf('Removing entire property: %s', a:property)
            call annotation#frontend#del_property(a:property.bufnr, a:property.lnum, a:property.col)
        else
            call annotation#frontend#set_property_data(a:property.bufnr, a:property.lnum, a:property.col, data, a:property.id)
        endif
    endfunction

    let options = {}
    call annotation#ui#menu(items, a:title, options, funcref('RemoveSelected'))
endfunction

" Display a menu for adding a new annotation to a text property.
function! annotation#menu#add(property, title='Edit')
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
            call s:add_property_data_item(a:property)
        elseif a:label == 2
            call s:modify_property_data(a:property)
        elseif a:label == 3
            call s:remove_property_data(a:property)
        else
            echomsg printf('Abort!')
            call annotation#frontend#del_property(a:property.bufnr, a:property.lnum, a:property.col)
        endif
    endfunction

    let options = {}
    call annotation#ui#menu(items, a:title, options, funcref('ShowSelected'))
endfunction

" Display a menu for modifying the annotations associated with a text property.
function! annotation#menu#modify(property, title='Edit')
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
            call s:add_property_data_item(a:property)
        elseif a:label == 2
            call s:modify_property_data(a:property)
        elseif a:label == 3
            call s:remove_property_data(a:property)
        else
            echomsg printf('Abort!')
        endif
    endfunction

    let options = {}
    call annotation#ui#menu(items, a:title, options, funcref('ShowSelected'))
endfunction
