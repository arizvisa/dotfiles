"" user-interface

" FIXME: The `popup_atcursor` function can display a dialog relative to the
"        cursor. This could be used with a mouse to select and annotate.

" This dictionary contains the window ids for all the popups that are visible.
let s:POPUP_WINDOWS = {}

function s:add_popup(id)
  if exists('s:POPUP_WINDOWS[a:id]')
    throw printf('annotation.DuplicateWindowError: the specified window id (%d) is already being tracked.', a:id)
  endif

  " Get all the information we can about the popup window.
  let pos = popup_getpos(a:id)
  let info = popup_getoptions(a:id)
  if empty(pos)
    throw printf('annotation.WindowNotFoundError: the specified window id (%d) could not be found while getting its position.', a:id)
  elseif empty(info)
    throw printf('annotation.WindowNotFoundError: the specified window id (%d) could not be found while getting its options.', a:id)
  endif

  " Stash the information that was retrieved.
  let s:POPUP_WINDOWS[a:id] = [pos, info]
  return [pos, info]
endfunction

function s:remove_popup(id)
  if !exists('s:POPUP_WINDOWS[a:id]')
    throw printf('annotation.MissingWindowError: the specified window id (%d) does not exist and cannot be removed.', a:id)
  endif

  " Just need to remove it.
  return remove(s:POPUP_WINDOWS, a:id)
endfunction

function s:has_popup(id)
  return exists('s:POPUP_WINDOWS[a:id]')
endfunction

" Create a popup dialog with the specified text and title for the given property
" (dictionary), and return its window id. If the `persist` parameter is false,
" then the dialog will be hidden when moving off of the text property.
function! annotation#ui#propertytooltip(text, title, property, persist)
  let popup = #{
  \ close: 'button',
  \ wrap: v:false,
  \ drag: v:true,
  \ resize: v:true,
  \ border: [1,1,1,1],
  \ scrollbar: v:false,
  \ zindex: a:persist? 100 : 1000,
  \ posinvert: v:true,
  \ padding: [0,1,0,1],
  \}

  " Verify that all the correct keys exist in the property dictionary.
  if !exists('a:property.lnum')
    throw printf('annotation.MissingKeyError: a required key (%s) was missing from the specified property dictionary: %s', 'lnum', a:property) 
  elseif !exists('a:property.col')
    throw printf('annotation.MissingKeyError: a required key (%s) was missing from the specified property dictionary: %s', 'col', a:property) 
  elseif !exists('a:property.end_lnum')
    throw printf('annotation.MissingKeyError: a required key (%s) was missing from the specified property dictionary: %s', 'end_lnum', a:property) 
  elseif !exists('a:property.end_col')
    throw printf('annotation.MissingKeyError: a required key (%s) was missing from the specified property dictionary: %s', 'end_col', a:property) 
  endif

  " Attach the popup to the selected property and give it a title.
  let popup.textprop = a:property['type']
  let popup.textpropid = a:property['id']
  let popup.title = a:title

  " Position it in a sane location, and then figure out whether the popup should
  " autohide when moving off the property or persist it until explicitly closed.
  let popup.pos = 'botleft'
  let popup.moved = a:persist? [0, 0, 0] : [a:property['lnum'], a:property['col'], a:property['end_col']]

  " The last thing we need to do is to create a closure/callback that can be
  " used to determine when the popup dialog has been closed by the user.
  function! Closed(id, result) closure
    call s:remove_popup(a:id)
  endfunction

  let popup.callback = funcref('Closed')

  " If the specified text is a string, then split it up by newlines. Otherwise
  " pass through whatever type it was that we were given.
  let lines = (type(a:text) == v:t_string)? split(a:text, "\n") : a:text
  let id = popup_create(lines, popup)
  return s:add_popup(id)
endfunction

" Create a popup dialog as a menu for the dictionary of selected items.
" XXX: Because the Vim popup api is fucking retarded and there's no way to
"      block execution, the caller has to specify the callback that the result
"      is sent to using the `send` parameter. Nice one, Bram... You fuck.
function! annotation#ui#menu(items, title, options, send)
  if type(a:items) != v:t_dict
    throw printf('annotation.InvalidTypeError: the specified parameter is of an invalid type (%d): %s', type(a:items), a:items)
  endif

  " We need this so that every closure we generate is a unique function.
  let s:MENU_RECURSE = {}

  " Start out by converting the dictionary of items into a list containing each
  " description and whatever hotkey was chosen.
  let descriptions = []
  let l:labels = {}
  for key in sort(keys(a:items), 'n')
    let index = 1 + len(descriptions)
    let l:labels[index] = key
    let value = a:items[key]
    call add(descriptions, printf('%d. %s', index, value))
  endfor

  " Define a closure for selecting things from the menu.
  function! s:MENU_RECURSE.Selected(id, index) closure

    " If the user canceled, then send the cancel index to the caller.
    if a:index < 0
      call a:send(a:id, a:index)
      return v:false

    elseif !exists('l:labels[a:index]')
      throw printf('annotation.MissingKeyError: a required key (%s) was missing from the specified labels dictionary: %s', a:index, l:labels) 
    endif

    " Convert the index into the label defined by the caller.
    let label = l:labels[a:index]
    call a:send(a:id, label)

    " Now we can remove the popup from our tracking dictionary.
    call s:remove_popup(a:id)
    return v:true
  endfunction

  " Define a closure for allowing the user to use numbers for selecting things.
  function! s:MENU_RECURSE.Shortcuts(id, key) closure
    let index = stridx('1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ', a:key)
    if index >= 0
      call popup_close(a:id, 1 + index)
      return v:true
    endif

    return popup_filter_menu(a:id, a:key)
  endfunction

  " Now we can assign the options to be used by the menu.
  let menuoptions = copy(a:options)
  let menuoptions.title = a:title

  " Then we can assign our closures before creating the popup menu.
  let menuoptions.callback = s:MENU_RECURSE.Selected
  let menuoptions.filter = s:MENU_RECURSE.Shortcuts

  let l:wid = popup_menu(descriptions, menuoptions)
  call s:add_popup(l:wid)

  " Because VIM is fucking retarded, we can't block until the popup has been
  " clicked. So, we just return nothing here since the real result is sent to
  " the callback. Emacs is just soooo much fucking better than Vim.
endfunction

" Place a sign at the specified line of the given buffer.
function! annotation#ui#placesign(bufnum, line, name, group=v:none)
  if type(a:bufnum) != v:t_number
    throw printf('annotation.InvalidParameterError: unable to place a sign in the specified buffer due to it being an unsupported type (%d).', type(a:bufnum))
  elseif type(a:line) != v:t_number
    throw printf('annotation.InvalidParameterError: unable to place a sign at the specified line of buffer %d due to it being an unsupported type (%d).', a:bufnum, type(a:line))
  elseif type(a:name) != v:t_string
    throw printf('annotation.InvalidParameterError: unable to place a sign at line %d of buffer %d due to its name being an unsupported type (%d).', a:line, a:bufnum, type(a:name))
  elseif a:group != v:none && type(a:group) != v:t_string
    throw printf('annotation.InvalidParameterError: unable to place a sign "%s" at line %d of buffer %d due to its group being an unsupported type (%d).', a:name, a:line, a:bufnum, type(a:group))
  endif

  " calculate the group name for the sign, and its location dictionary.
  let groupname = (a:group == v:none)? '' : a:group
  let location = {'lnum': a:line}

  " then we can create it to get its id, and then place it.
  let id = annotation#state#newsign(a:bufnum, a:line, a:name, a:group)
  let res = sign_place(id, groupname, a:name, a:bufnum, location)
  if id == res
    return id
  endif

  " if our id and resulting id are different, then abort completely.
  throw printf('annotation.InternalError: the sign "%s" placed at line %d of buffer %d has an id (%d) that is different from the one calculated (%d).', a:name, a:line, a:bufnum, res, id)
endfunction

" Remove a sign at the given line number from the specified buffer.
function! annotation#ui#unplacesign(bufnum, id)
  if type(a:bufnum) != v:t_number
    throw printf('annotation.InvalidParameterError: unable to unplace the sign from the specified buffer due to it being an unsupported type (%d).', type(a:bufnum))
  elseif type(a:id) != v:t_number
    throw printf('annotation.InvalidParameterError: unable to unplace a sign from buffer %d due to its id being an unsupported type (%d).', a:bufnum, type(a:id))
  endif

  " remove the specified sign and grab the line number from its data.
  let signdata = annotation#state#removesign(a:bufnum, a:id)

  " now we need to collect the parameters to unplace the sign...
  let groupname = exists('signdata.group')? signdata.group : ''
  let location = {'buffer': signdata.bufnr, 'id': signdata.id}

  " ...and then we can remove it.
  let res = sign_unplace(groupname, location)
  if res < 0
    throw printf('annotation.InternalError: unable to unplace the sign (%d) at line %d of buffer %d.', signdata.id, signdata.line, signdata.bufnr)
  endif

  return signdata
endfunction

" Return all of the sign ids for a given buffer and line number.
function! annotation#ui#signat(bufnum, line)
  let res = {}
  for id in annotation#state#getsigns(a:bufnum, a:line)
    let res[id] = annotation#state#getsign(a:bufnum, id)
  endfor
  return res
endfunction

" Read input specified by the user and then return it to the caller.
" FIXME: would be cool to allow editing things in a popup, or allow editing
"        user-applied text with vim keybindings.
function! annotation#ui#readinput(prompt='?', default='')
  return input(a:prompt, a:default)
endfunction

" Pretty much for examining the available windows while debugging...
function! annotation#ui#WINDOWS()
  return s:POPUP_WINDOWS
endfunction
