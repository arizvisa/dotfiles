
" This dictionary contains the annotation state for each loaded buffer.
let s:STATE = {}

" Return a list of all the buffer numbers that currently have properties applied
" to them.

function! annotation#state#buffers()
  return sort(keys(s:STATE), 'n')
endfunction

" Create a new state for a buffer by its number.
function! annotation#state#new(bufnum)
  if exists('s:STATE[a:bufnum]')
    throw printf('annotation.DuplicateStateError: state for buffer %d already exists.', a:bufnum)
  endif

  " create a new state for the specified buffer number
  let s:STATE[a:bufnum] = {}

  " contains mappings for a line number to a list of property ids
  let s:STATE[a:bufnum].lines = {}

  " maps property id to its {props} dictionary
  let s:STATE[a:bufnum].props = {}

  " tracks property ids that have been deleted or are not in use anymore. if
  " this list is empty, then the next id can be determined by the number of
  " properties inside the buffer.
  let s:STATE[a:bufnum].availableprops = []

  " maps property id to completely arbitrary metadata.
  let s:STATE[a:bufnum].annotations = {}

  return s:STATE[a:bufnum]
endfunction

" Return whether the state for the specified buffer has been initialized.
function! annotation#state#exists(bufnum)
  return exists('s:STATE[a:bufnum]')? v:true : v:false
endfunction

" Load the state in "contents" for the buffer specified by its number.
function! annotation#state#load(bufnum, contents)
  if exists('s:STATE[a:bufnum]')
    throw printf('annotation.DuplicateStateError: state for buffer %d already exists.', a:bufnum)
  endif

  " FIXME: deserialize a:contents into the state for the buffer number
endfunction

" Return the state for the buffer specified by its number.
function! annotation#state#save(bufnum)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  endif

  " FIXME: serialize state for the buffer number and return it.
  let l:bufferstate = s:STATE[a:bufnum]
endfunction

" Remove and return the state for the buffer specified by buffer number.
function! annotation#state#remove(bufnum)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  endif

  return remove(s:STATE, a:bufnum)
endfunction

" Return a new unique property id by its buffer number.
function! s:get_next_property_id(bufnum)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  endif

  let l:bufferstate = s:STATE[a:bufnum]
  if empty(l:bufferstate.availableprops)
    return len(l:bufferstate.props)
  else
    return remove(l:bufferstate.availableprops, 0)
  endif
endfunction

" Return a list of the lines that should be covered by the specified property.
function! s:get_property_lines(property)
  if !exists('a:property.lnum')
    throw printf('annotation.InvalidPropertyError: could not determine line number from property: %s', a:property)
  endif

  let l:lstart = a:property['lnum']
  let l:lstop = has_key(a:property, 'end_lnum')? a:property['end_lnum'] : l:lstart

  return range(l:lstart, l:lstop)
endfunction

" Remove the property specified by its id from the specified buffer number.
function! annotation#state#removeprop(bufnum, id)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif !exists('s:STATE[a:bufnum].props[a:id]')
    throw printf('annotation.MissingPropertyError: property %d from buffer %d does not exist.', a:id, a:bufnum)
  elseif index(s:STATE[a:bufnum].availableprops, a:id) >= 0
    throw printf('annotation.DuplicatePropertyError: property %d from buffer %d has already been deleted.', a:id, a:bufnum)
  endif

  let [l:id, l:bufferstate] = [a:id, s:STATE[a:bufnum]]

  " first remove the property, adding it to our list of available props.
  let l:property = remove(l:bufferstate.props, l:id)
  call add(l:bufferstate.availableprops, l:id)

  " now we need to figure out which line numbers our property resides in.
  let l:bufferlines = l:bufferstate.lines

  let l:lines = []
  for l:lnum in s:get_property_lines(l:property)
    if !exists('l:bufferlines[l:lnum]')
      continue
    endif

    let l:bufferline = l:bufferlines[l:lnum]

    " verify that the id doesn't already exist in the current line.
    let l:index = index(l:bufferline, l:id)
    if l:index < 0
      continue
    endif

    " now we can remove the id from the current buffer line. if the id that we
    " removed doesn't match, then something unexpected happened and we add the
    " id back into the list.
    let l:removed = remove(l:bufferline, l:index)

    if l:removed == l:id
      call add(l:lines, l:lnum)
    else
      echoerr printf('annotation.AssertionError: expected removal of property %d from line %d, but the index (%d) points to property %d.', l:id, l:lnum, l:index, l:removed)
      call add(l:bufferline, l:removed)
    endif

    " if the buffer line is empty, then remove its entry completely.
    if empty(l:bufferline)
      call remove(l:bufferlines, l:lnum)
    endif
  endfor

  " very last thing we need to do is to remove the annotations for the property.
  if exists('l:bufferstate.annotations[l:id]')
    call remove(l:bufferstate.annotations, l:id)
  endif

  return [l:property, l:lines]
endfunction

" Add a new property to the state for the specified buffer number.
function! annotation#state#newprop(bufnum, property)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif exists('a:property.id')
    throw printf('annotation.InvalidPropertyError: new property for buffer %d already has an id (%d).', a:bufnum, a:property.id)
  endif

  let l:bufferstate = s:STATE[a:bufnum]

  " make a copy of the property, get a new id, and then attach it.
  let l:newproperty = copy(a:property)
  let l:newid = s:get_next_property_id(a:bufnum)
  let l:newproperty.id = l:newid

  " now we can add it to the buffer state.
  let l:bufferstate.props[l:newid] = l:newproperty

  " update the lines in the bufferstate with the new property id.
  let l:bufferlines = l:bufferstate.lines

  let l:lines = []
  for l:lnum in s:get_property_lines(l:newproperty)
    if exists('l:bufferlines[l:lnum]')
      let l:bufferline = l:bufferlines[l:lnum]
    else
      let l:bufferline = []
      let l:bufferlines[l:lnum] = l:bufferline
    endif

    if index(l:bufferlines[l:lnum], l:newid) < 0
      call add(l:bufferline, l:newid)
    endif

    call add(l:lines, l:lnum)
  endfor

  " now we can return the new property to the caller.
  return [l:newproperty, l:lines]
endfunction

" Return whether the specified buffer has a property with the given id.
function! annotation#state#hasprop(bufnum, id)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif !exists('s:STATE[a:bufnum].props')
    throw printf('annotation.MissingPropertyError: properties for buffer %d do not exist.', a:id, a:bufnum)
  endif
  return exists('s:STATE[a:bufnum].props[a:id]')? v:true : v:false
endfunction

" Modify the property specified by id for the given buffer number.
function! annotation#state#updateprop(bufnum, id, property)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif !exists('s:STATE[a:bufnum].props[a:id]')
    throw printf('annotation.MissingPropertyError: property %d from buffer %d does not exist.', a:id, a:bufnum)
  elseif exists('a:property.id')
    throw printf('annotation.InvalidPropertyError: target property for buffer %d already has an id (%d).', a:bufnum, a:property.id)
  endif

  let [l:id, l:bufferstate] = [a:id, s:STATE[a:bufnum]]

  " start by grabbing the original property and the lines from the buffer state
  " so that we can go and remove all the lines associated with the property.
  let l:old = l:bufferstate.props[a:id]
  let l:bufferlines = l:bufferstate.lines

  let l:oldlines = []
  for l:lnum in s:get_property_lines(l:old)
    if !exists('l:bufferlines[l:lnum]')
      continue
    endif

    let l:bufferline = l:bufferlines[l:lnum]

    " grab the index of the property from the current line.
    let l:index = index(l:bufferline, l:id)
    if l:index < 0
      continue
    endif

    " next we remove the property from the current buffer line. if, for some
    " reason, the id removed doesn't match then complain about it and add the
    " property id that we removed back into the current buffer line.
    let l:removed = remove(l:bufferline, l:index)
    if l:removed == l:id
      call add(l:oldlines, l:lnum)
    else
      echoerr printf('annotation.AssertionError: expected removal of property %d from line %d, but the index (%d) points to property %d.', a:id, l:lnum, l:index, l:removed)
      call add(l:bufferline, l:removed)
    endif

    " if bufferline for the line number is empty, then we can go ahead and
    " remove its entry from our list of buffer lines.
    if empty(l:bufferline)
      call remove(l:bufferlines, l:lnum)
    endif
  endfor

  " FIXME: for the sake of debugging, we can probably log the old property and
  "        the lines that it was applied to.

  " now we can create a new property and copy the old property id into it.
  let l:new = copy(a:property)
  let l:new.id = l:id
  let l:bufferstate.props[l:id] = l:new

  " then we can update our lines in the buffer state with the property id.
  let l:bufferlines = l:bufferstate.lines

  let l:lines = []
  for l:lnum in s:get_property_lines(l:newproperty)
    if exists('l:bufferlines[l:lnum]')
      let l:bufferline = l:bufferlines[l:lnum]
    else
      let l:bufferline = []
      let l:bufferlines[l:lnum] = l:bufferline
    endif

    if index(l:bufferlines[l:lnum], l:id) < 0
      call add(l:bufferline, l:id)
    endif

    call add(l:lines, l:lnum)
  endfor

  " that was it. we can now return the new property (with id), and the lines
  " numbers that it actually references.
  return [l:new, l:lines]
endfunction

" Return the property and line numbers from the specified buffer number and id.
function! annotation#state#getprop(bufnum, id)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif !exists('s:STATE[a:bufnum].props[a:id]')
    throw printf('annotation.MissingPropertyError: property %d from buffer %d does not exist.', a:id, a:bufnum)
  endif

  let [l:id, l:bufferstate] = [a:id, s:STATE[a:bufnum]]

  " grab the property, and use it to get the lines that it has been applied to.
  let l:property = l:bufferstate.props[l:id]
  let l:bufferlines = l:bufferstate.lines

  let l:lines = []
  for l:lnum in s:get_property_lines(l:property)
    if !exists('l:bufferlines[l:lnum]')
      continue
    endif

    let l:bufferline = l:bufferlines[l:lnum]
    if index(l:bufferline, l:id) < 0
      continue
    endif

    call add(l:lines, l:lnum)
  endfor

  " that was it.
  return [l:property, l:lines]
endfunction

" Return a list of all the property ids associated with the specified buffer.
function! annotation#state#get(bufnum)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif exists('s:STATE[a:bufnum].props')
    let l:properties = s:STATE[a:bufnum].props
    return sort(copy(keys(l:properties)), 'n')
  else
    return []
  endif
endfunction

" Return the annotation for the specified property id in the given buffer.
function! annotation#state#getdata(bufnum, id)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif !exists('s:STATE[a:bufnum].props[a:id]')
    throw printf('annotation.MissingPropertyError: property %d from buffer %d does not exist.', a:id, a:bufnum)
  endif

  let l:bufferstate = s:STATE[a:bufnum]
  return get(l:bufferstate.annotations, a:id, {})
endfunction

" Set the annotation for the specified property id in the given buffer.
function! annotation#state#setdata(bufnum, id, data)

  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif !exists('s:STATE[a:bufnum].props[a:id]')
    throw printf('annotation.MissingPropertyError: property %d from buffer %d does not exist.', a:id, a:bufnum)
  endif

  let l:bufferstate = s:STATE[a:bufnum]
  let l:result = get(l:bufferstate.annotations, a:id, {})
  let l:bufferstate.annotations[a:id] = copy(a:data)
  return l:result
endfunction

" Pretty much for examining the state while debugging...
function annotation#state#STATE()
  return s:STATE
endfunction
