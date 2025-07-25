" Responsible for return a menu for selecting the annotations associated with a
" specific property.
function! annotation#menu#build(property)
  let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)
  let notes = exists('data.notes')? data.notes : {}

  " FIXME: add menu item to allow aborting a modification
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

  if empty(annotation)
    return v:false
  endif

  " initialize the data if it hasn't been done yet.
  if !exists('data.notes')
    let data.notes = {}
  endif

  " assign the data, and then update the property
  let key = len(data.notes)
  let data.notes[key] = annotation

  call annotation#frontend#set_property_data(a:property.bufnr, a:property.lnum, a:property.col, copy(data), a:property.id)
  return v:true
endfunction

" Modify the data at the specified index associated with the selected property.
function! s:modify_property_data_item(property, index)
  let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)

  " get user input, using the original data as the default.
  let old = data.notes[a:index]

  let new = annotation#ui#readinput('Modify: ', old)
  if empty(new)
    return v:false
  endif

  let data.notes[a:index] = new

  " write it back into the property data.
  call annotation#frontend#set_property_data(a:property.bufnr, a:property.lnum, a:property.col, copy(data), a:property.id)
  return v:true
endfunction

" Display a menu for selecting an annotation item and editing it.
function! s:modify_property_data(property, title='Modifying')
  let items = annotation#menu#build(a:property)

  function! s:ModifySelected(id, label) closure
    call s:modify_property_data_item(a:property, a:label)
  endfunction

  let options = {}
  call annotation#ui#menu(items, a:title, options, funcref('s:ModifySelected'))
  return v:true
endfunction

" Display a menu for selecting an annotation item and removing it.
function! s:remove_property_data(property, title='Removing')
  let items = annotation#menu#build(a:property)
  " FIXME: add menu item to abort removal

  " Define a closure that will actually remove the selected annotation.
  function! RemoveSelected(id, label) closure
    let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)
    let removed = remove(data.notes, a:label)

    if empty(data.notes)
      echomsg printf('Removing entire property: %s', a:property)
      call annotation#frontend#del_property(a:property.bufnr, a:property.lnum, a:property.col)
    else
      call annotation#frontend#set_property_data(a:property.bufnr, a:property.lnum, a:property.col, data, a:property.id)
    endif
  endfunction

  " Build the menu and return success.
  let options = {}
  call annotation#ui#menu(items, a:title, options, funcref('RemoveSelected'))
  return v:true
endfunction

" Display the annotation menu for the specified property.
function! s:show_annotation_menu(property, title, callbacks)
  let [_, data] = annotation#frontend#get_property_data(a:property.bufnr, a:property.lnum, a:property.col, a:property.id)

  " Build the menu for adding an annotation.
  let items = {}
  let items[1] = 'Add a new annotation to the current line.'

  " If there's some data associated with the text property, then add the menu
  " items that allow modifying or removing an annotation from the property.
  if exists('data.notes') && !empty(data.notes)
    let items[2] = 'Modify an existing annotation of the current line.'
    let items[3] = 'Remove a specific annotation from the current line.'
  endif

  let items[4] = 'Abort'

  " Define a closure that dispatches to the correct function depending on
  " whatever menu item the user has selected.
  function! ShowSelected(id, label) closure
    let l:Callback = exists('a:callbacks[a:label]')? a:callbacks[a:label] : v:none

    " Use the label to dispatch to the correct function and capturing whether it
    " suceeded or failed. This way we can use the callback to customize things.
    if a:label == 1
      let ok = s:add_property_data_item(a:property)
    elseif a:label == 2
      let ok = s:modify_property_data(a:property)
    elseif a:label == 3
      let ok = s:remove_property_data(a:property)
    else
      let ok = v:false
    endif

    " If we have a callback, then execute it for whatever label was selected.
    if l:Callback != v:none
      call l:Callback(a:property, a:label, ok)
    endif
  endfunction

  " Now we can build the menu and return success.
  let options = {}
  call annotation#ui#menu(items, a:title, options, funcref('ShowSelected'))
  return v:true
endfunction

" Display a menu for adding a new annotation to a text property.
function! annotation#menu#add(property, title='Add')
  let l:callbacks = {}

  " Define a closure that handles canceling the addition of an annotation.
  function! s:CancelAddition(selected, label, ok) closure
    if a:ok
      return
    endif

    " If the addition was canceled, then go ahead and remove it as-if it was
    " never created.
    echomsg printf('User canceled the addition of an annotation: %s', a:selected)
    call annotation#frontend#del_property(a:selected.bufnr, a:selected.lnum, a:selected.col)
  endfunction

  " Define a closure that handles canceling the modification of an annotation.
  function! s:CancelModification(selected, label, ok) closure
    if a:ok
      return
    endif

    " If the modification was canceled, then go ahead and remove it.
    echomsg printf('User canceled the modification of an annotation: %s', a:selected)
    call annotation#frontend#del_property(a:selected.bufnr, a:selected.lnum, a:selected.col)
  endfunction

  " Define a closure that handles aborting the addition menu. We delete the
  " property that was added if the user aborted the addition.
  function! s:AbortFunction(selected, label, ok) closure
    echomsg printf('User aborted the addition of an annotation: %s', a:selected)
    call annotation#frontend#del_property(a:selected.bufnr, a:selected.lnum, a:selected.col)
  endfunction

  " Assign some callbacks that we will use for each label.
  let l:callbacks[1] = funcref('s:CancelAddition')
  let l:callbacks[2] = funcref('s:CancelModification')
  let l:callbacks[4] = funcref('s:AbortFunction')
  let l:callbacks[-1] = funcref('s:AbortFunction')

  " Now we can go ahead and show the menu.
  call s:show_annotation_menu(a:property, a:title, l:callbacks)
endfunction

" Display a menu for modifying the annotations associated with a text property.
function! annotation#menu#modify(property, title='Edit')
  let l:callbacks = {}

  " Define a closure that handles canceling the addition of an annotation. Since
  " this function is only called when modifying an annotation, we don't need to
  " remove the annotation.
  function! s:CancelAddition(selected, label, ok) closure
    if a:ok
      return
    endif

    echomsg printf('User canceled the addition of an annotation: %s', a:selected)
  endfunction

  " Define a closure for canceling the modification of an annotation. Similarly,
  " since we're modifying an annotation... cancelling doesn't do a thing.
  function! s:CancelModification(selected, label, ok) closure
    if a:ok
      return
    endif

    echomsg printf('User canceled the modification of an annotation: %s', a:selected)
  endfunction

  " If the abort menu item was selected, then we just log a message and leave.
  function! s:AbortFunction(selected, label, ok) closure
    echomsg printf('User aborted modification of the specified annotation: %s', a:selected)
  endfunction

  " Assign some callbacks that we will use for each label.
  let l:callbacks[1] = funcref('s:CancelAddition')
  let l:callbacks[2] = funcref('s:CancelModification')
  let l:callbacks[4] = funcref('s:AbortFunction')
  let l:callbacks[-1] = funcref('s:AbortFunction')

  " We can now use the callbacks to show the annotation menu.
  call s:show_annotation_menu(a:property, a:title, l:callbacks)
endfunction
