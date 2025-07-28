
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

  " maps property id to its {props} dictionary
  let s:STATE[a:bufnum].props = {}

  " contains mappings for a line number to a list of property ids
  let s:STATE[a:bufnum].lines = {}

  " tracks a reference count for each property
  let s:STATE[a:bufnum].propcounts = {}

  " tracks property ids that have been deleted or are not in use anymore. if
  " this list is empty, then the next id can be determined by the number of
  " properties inside the buffer.
  let s:STATE[a:bufnum].availableprops = []

  " maps property id to completely arbitrary metadata.
  let s:STATE[a:bufnum].annotations = {}

  " maps sign id to its name and line number.
  let s:STATE[a:bufnum].signs = {}

  " maps line number to its sign ids.
  let s:STATE[a:bufnum].signpositions = {}

  " tracks a reference count for signs
  let s:STATE[a:bufnum].signcounts = {}

  " tracks sign ids that have been deleted and are not in use. this is used in a
  " similar fashion to the "availableprops" field.
  let s:STATE[a:bufnum].availablesigns = []

  return s:STATE[a:bufnum]
endfunction

" Return whether the state for the specified buffer has been initialized.
function! annotation#state#exists(bufnum)
  return exists('s:STATE[a:bufnum]')? v:true : v:false
endfunction

" Return the state for the specified buffer number.
function! annotation#state#get(bufnum)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.DuplicateStateError: state for buffer %d does not exist.', a:bufnum)
  endif
  return s:STATE[a:bufnum]
endfunction

" Load the state in "contents" for the buffer specified by its number.
function! annotation#state#load(bufnum, contents)
  if !exists('a:contents.properties')
    throw printf('annotation.InvalidParameterError: unable to load the specified contents for buffer %d due to missing the "%s" key.', a:bufnum, 'properties')
  elseif !exists('a:contents.annotations')
    throw printf('annotation.InvalidParameterError: unable to load the specified contents for buffer %d due to missing the "%s" key.', a:bufnum, 'annotations')
  elseif !exists('a:contents.propertymap')
    throw printf('annotation.InvalidParameterError: unable to load the specified contents for buffer %d due to missing the "%s" key.', a:bufnum, 'map')
  elseif type(a:contents.propertymap) != v:t_dict
    throw printf('annotation.InvalidParameterError: unable to load the specified contents for buffer %d due to an unsupported type (%d).', a:bufnum, type(a:propertymap))
  endif

  " Grab the state of the buffer that we're loading annotations into.
  let l:bufferstate = annotation#state#exists(a:bufnum)? annotation#state#get(a:bufnum) : annotation#state#new(a:bufnum)

  if !exists('l:bufferstate.props')
    let l:bufferstate.props = {}
  elseif !exists('l:bufferstate.annotations')
    let l:bufferstate.annotations = {}
  endif

  let l:propertystate = l:bufferstate.props
  let l:annotationstate = l:bufferstate.annotations
  let l:bufferlines = l:bufferstate.lines
  let l:buffercounts = l:bufferstate.propcounts
  let l:annotationstate = l:bufferstate.annotations

  " Unpack our serialized data so that we can get at the annotations.
  let propertyresults = a:contents.properties
  let annotationresults = a:contents.annotations
  let propertymap = a:contents.propertymap

  " Now we can load them into the current buffer.
  for id in keys(annotationresults)
    let newid = exists('propertymap[id]')? propertymap[id] : id
    let l:annotationstate[newid] = annotationresults[id]
  endfor

  " Figure out what property ids are not being used and add them to the
  " buffer state under the "availableprops" key.
  let ids = sort(keys(propertyresults))

  let unused = []
  for id in range(min(ids), max(ids))
    let newid = exists('propertymap[id]')? propertymap[id] : id
    if !exists('propertyresults[newid]')
      call add(unused, newid)
    else
      let propertydata = copy(propertyresults[id])
      let propertydata.id = newid
      let l:propertystate[newid] = propertydata

      for l:lnum in s:get_property_lines(l:propertydata)
        let l:bufferline = exists('l:bufferlines[l:lnum]')?  l:bufferlines[l:lnum] : []
        let l:bufferlines[l:lnum] = l:bufferline

        if index(l:bufferline, l:id) < 0
          call add(l:bufferline, l:id)
          let l:buffercounts[l:id] = get(l:buffercounts, l:id, 0) + 1
        endif
      endfor
    endif
  endfor

  " Combine the unused id list with the available property id lists.
  let total = uniq(sort(l:bufferstate.availableprops + unused))
  let l:bufferstate.availableprops = total
endfunction

" Return the state for the buffer specified by its number.
function! annotation#state#save(bufnum)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  endif

  " Start by grabbing the state of the current buffer.
  let l:bufferstate = s:STATE[a:bufnum]

  " Then we can go through all of the available properties and transform them
  " into a dictionary that can look up the different serialize items.
  let properties = l:bufferstate.props
  let propertyfields = ['lnum','col','end_lnum','end_col','type']

  let propertyresults = {}
  for key in keys(properties)
    let property = properties[key]
    let propertyresults[key] = exists('propertyresults[key]')? propertyresults[key] : {}
    for field in propertyfields
      if exists('property[field]')
        let propertyresults[key][field] = copy(property[field])
      else
        let propertyresults[key][field] = v:none
      endif
    endfor
  endfor

  " FIXME: the purpose of the "propertymap" field is to allow loading multiple
  "        annotations on the same file. it is intended to be populated by the
  "        `annotation#property` namespace to translate a serialized property to
  "        the current property id space for the specified buffer.

  " Now we can grab the annotations (which are already fine as-is), and then
  " return all the things to the caller in order to continue processing.
  let annotationresults = deepcopy(l:bufferstate.annotations)
  return {'properties': propertyresults, 'annotations': annotationresults, 'propertymap': {}}
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

" Return a new unique sign id by its buffer number.
function! s:get_next_sign_id(bufnum)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  endif

  let l:bufferstate = s:STATE[a:bufnum]
  if empty(l:bufferstate.availablesigns)
    return len(l:bufferstate.signs)
  else
    return remove(l:bufferstate.availablesigns, 0)
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

  " get some locals so that we can access the metadata for the property.
  let [l:id, l:bufferstate] = [a:id, s:STATE[a:bufnum]]
  let l:bufferlines = l:bufferstate.lines
  let l:buffercounts = l:bufferstate.propcounts
  let l:bufferprops = l:bufferstate.props

  let l:property = get(l:bufferprops, l:id)

  " first we need need to figure out which line numbers our property resides in.
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

    " now we need to update the reference count fror the removed property.
    if exists('l:buffercounts[l:id]') && l:buffercounts[l:id] > 0
      let l:buffercounts[l:id] = l:buffercounts[l:id] - 1
    else
      let l:count = get(l:buffercounts, l:id, 0)
      echoerr printf('annotation.AssertionError: expected a positive reference count for removed property %d at line %d, but the count (%d) is less than or equal to %d.', a:id, l:lnum, l:count, 0)
    endif

    " If the reference count for the property is less than or equal to zero,
    " then we can just remove the property id from the reference counts.
    if l:buffercounts[l:id] <= 0
      call remove(l:buffercounts, l:id)
    endif

    " if the buffer line is empty, then remove its entry completely.
    if empty(l:bufferline)
      call remove(l:bufferlines, l:lnum)
    endif
  endfor

  " now the very last thing to do is to check the reference counts and remove
  " the property if it's the last one.
  if get(l:buffercounts, l:id, 0) <= 0
    let l:removed = remove(l:bufferprops, l:id)
    call add(l:bufferstate.availableprops, l:id)

    if exists('l:bufferstate.annotations[l:id]')
      call remove(l:bufferstate.annotations, l:id)
    endif
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
  let l:bufferlines = l:bufferstate.lines
  let l:buffercounts = l:bufferstate.propcounts
  let l:bufferprops = l:bufferstate.props

  " make a copy of the property, get a new id, and then attach it.
  let l:newproperty = copy(a:property)
  let l:newid = s:get_next_property_id(a:bufnum)
  let l:newproperty.id = l:newid
  let l:newproperty.bufnr = a:bufnum

  " now we can add it to the buffer state.
  let l:bufferprops[l:newid] = l:newproperty

  " update the lines in the bufferstate with the new property id,
  " and track its reference count.
  let l:newlines = []
  for l:lnum in s:get_property_lines(l:newproperty)
    if exists('l:bufferlines[l:lnum]')
      let l:bufferline = l:bufferlines[l:lnum]
    else
      let l:bufferline = []
      let l:bufferlines[l:lnum] = l:bufferline
    endif

    " add the new property id to the line, and update its reference count.
    if index(l:bufferlines[l:lnum], l:newid) < 0
      call add(l:bufferline, l:newid)
      let l:buffercounts[l:newid] = get(l:buffercounts, l:newid, 0) + 1
    endif

    call add(l:newlines, l:lnum)
  endfor

  " now we can return the new property to the caller.
  return [l:newproperty, l:newlines]
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

  " assign some locals to access the different components of our state.
  let [l:id, l:bufferstate] = [a:id, s:STATE[a:bufnum]]
  let l:bufferlines = l:bufferstate.lines
  let l:buffercounts = l:bufferstate.propcounts
  let l:bufferprops = l:bufferstate.props

  let l:old = l:bufferprops[a:id]

  " start by grabbing the original property and the lines from the buffer state
  " so that we can go and remove all the lines associated with the property.

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
      echoerr printf('annotation.AssertionError: expected removal of property %d from line %d, but the index (%d) points to property %s.', a:id, l:lnum, l:index, l:removed)
      call add(l:bufferline, l:removed)
    endif

    " now we update the reference count for the property that we removed.
    if exists('l:buffercounts[l:id]') && l:buffercounts[l:id] > 0
      let l:buffercounts[l:id] = l:buffercounts[l:id] - 1
    else
      let l:count = get(l:buffercounts, l:id, 0)
      echoerr printf('annotation.AssertionError: expected a positive reference count for removed property %d at line %d, but the count (%d) is less than or equal to %d.', a:id, l:lnum, l:count, 0)
    endif

    " if the reference count for the property is <= 0, then we can just remove
    " the property id from the reference counts.
    if l:buffercounts[l:id] <= 0
      call remove(l:buffercounts, l:id)
    endif

    " if bufferline for the line number is empty, then we can go ahead and
    " remove its entry from our list of buffer lines.
    if empty(l:bufferline)
      call remove(l:bufferlines, l:lnum)
    endif
  endfor

  " if the reference count says the property still exists, then we complain
  " about it and just assume that it was deleted anyways.
  if get(l:buffercounts, l:id, 0) > 0
      echoerr printf('annotation.AssertionError: expected the reference count for removed property %d at line %d to be less than or equal to %d, but the count (%d) is greater than %d.', a:id, l:lnum, 0, l:count, 0)
  endif

  " FIXME: for the sake of debugging, we can probably log the old property and
  "        the lines that it was applied to.

  " now we can create a new property and copy the old property id into it.
  let l:new = copy(a:property)
  let l:new.id = l:id
  let l:bufferstate.props[l:id] = l:new

  " then we can update our lines in the buffer state with the property id.
  let l:bufferlines = l:bufferstate.lines
  let l:buffercounts = l:bufferstate.counts
  let l:bufferprops = l:bufferstate.props

  let l:lines = []
  for l:lnum in s:get_property_lines(l:newproperty)
    if exists('l:bufferlines[l:lnum]')
      let l:bufferline = l:bufferlines[l:lnum]
    else
      let l:bufferline = []
      let l:bufferlines[l:lnum] = l:bufferline
    endif

    " if the id doesn't exist in the specified line, then add it and update the
    " reference count that we're tracking for each property.
    if index(l:bufferlines[l:lnum], l:id) < 0
      call add(l:bufferline, l:id)
      call add(l:buffercounts, 1 + get(l:buffercounts, l:id, 0))
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

  " grab the property and the lines for the current buffer.
  let l:property = l:bufferstate.props[l:id]
  let l:bufferlines = l:bufferstate.lines

  " iterate through all the lines for the property, and update the lines for the
  " current buffer if we couldn't find the property id inside the current line.
  for l:lnum in s:get_property_lines(l:property)
    let l:bufferline = exists('l:bufferlines[l:lnum]')? l:bufferlines[l:lnum] : []
    let l:bufferlines[l:lnum] = l:bufferline

    " FIXME: we should do a sorted insert here so we get better than O(n)
    if index(l:bufferline, l:id) < 0
      call add(l:bufferline, l:id)
    endif
  endfor

  " that was it.
  return l:property
endfunction

" Return a list of all the property ids associated with the specified buffer.
function! annotation#state#properties(bufnum)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif exists('s:STATE[a:bufnum].props')
    let l:properties = s:STATE[a:bufnum].props
    return sort(copy(keys(l:properties)), 'n')
  else
    return []
  endif
endfunction

" Return a list of property ids for the specified buffer overlapping the given
" range of the specified line number.
function! annotation#state#find_line(bufnum, start, stop, lnum)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif a:start == a:stop
    return s:properties_at_point(a:bufnum, a:start, a:lnum)
  endif

  " Grab the buffer state.
  let l:bufferstate = s:STATE[a:bufnum]
  let l:bufferlines = l:bufferstate.lines
  let l:bufferprops = l:bufferstate.props

  " Greab the ids that are applied to the specified line number.
  let ids = exists('l:bufferlines[a:lnum]')? l:bufferlines[a:lnum] : []

  " Check the properties at the specified line number and add them if we
  " overlap.
  let result = []
  for id in ids
    let propertydata = l:bufferprops[id]
    if a:start <= propertydata['end_col'] && a:stop >= propertydata['col']
      call add(result, id)
    endif
  endfor
  return result
endfunction

" Return a list of property ids for the specified buffer at the specified point.
function! s:properties_at_point(bufnum, col, lnum)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  endif

  " Grab the buffer state.
  let l:bufferstate = s:STATE[a:bufnum]
  let l:bufferlines = l:bufferstate.lines
  let l:bufferprops = l:bufferstate.props

  " Grab the ids for the specified line number.
  let ids = exists('l:bufferlines[a:lnum]')? l:bufferlines[a:lnum] : []

  " Check the properties at the specified line number and add them if we
  " overlap.
  let result = []
  for id in ids
    let propertydata = l:bufferprops[id]
    if a:col == propertydata['col']
      call add(result, id)
    endif
  endfor
  return result
endfunction

" Return a list of property ids for the specified buffer at the specified point.
function! annotation#state#find_bounds(bufnum, col, lnum, end_col, end_lnum)
  if a:lnum == a:end_lnum && a:col == a:end_col
    return s:properties_at_point(a:bufnum, a:col, a:lnum)
  elseif a:lnum == a:end_lnum
    return annotation#state#find_line(a:bufnum, a:col, a:end_col, a:lnum)
  endif

  let results = []
  for line in range(a:lnum, a:end_lnum)
    let lineresults = annotation#state#find_line(a:bufnum, a:col, a:end_col, line)
    call extend(results, lineresults)
  endfor
  return uniq(sort(results))
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

" Add a new sign to the state for the specified buffer number.
function! annotation#state#newsign(bufnum, line, name, group=v:none)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif type(a:id) != v:t_number
    throw printf('annotation.InvalidParameterError: unable to add a sign with an id using an unsupported type (%d).', type(a:id))
  elseif type(a:line) != v:t_number
    throw printf('annotation.InvalidParameterError: unable to add a sign at a line number using an unsupported type (%d).', type(a:line))
  elseif type(a:name) != v:t_string || empty(a:name)
    let message = printf('a name with an unsupported type (%d).', type(a:name))
    throw printf('annotation.InvalidParameterError: unable to add a sign at line number %d using %s.', type(a:line), empty(a:name)? 'an empty name' : message)
  elseif a:group != v:none && type(a:group) != v:t_string
    throw printf('annotation.InvalidParameterError: unable to add sign "%s" at line number %d using a group with an unsupported type (%d).', a:name, a:line, type(a:group))
  endif

  " assign some local variables that we can use to access the sign state.
  let l:bufferstate = s:STATE[a:bufnum]
  let l:buffersigns = l:bufferstate.signs
  let l:bufferpositions = l:bufferstate.signpositions
  let l:buffercounts = l:bufferstate.signcounts

  let l:id = s:get_next_sign_id(a:bufnum)

  " if the id already exists, then we raise an exception without removing it.
  " this way the next time we get called, the id will be a different one.
  if exists('l:bufferstate.signs[l:id]')
    throw printf('annotation.DuplicateSignError: buffer %d already has a sign with id %d.', a:bufnum, l:id)
  elseif !exists('l:bufferstate.signpositions[a:line]')
    let l:bufferpositions[a:line] = {}
  endif

  " now we can assign our signdata that we'll state into the sign states.
  let signdata = {'id': l:id, 'lnum': a:line, 'name': a:name, 'bufnr': a:bufnum}
  if a:group != v:none
    let signdata['group'] = a:group
  endif

  " now we can assign our sign data, update the sign positions so that we can
  " store a dictionary at the line number, and then return the calculated id.
  let l:buffersigns[l:id] = signdata

  if !exists('l:bufferstate.signpositions[a:line]')
    let l:bufferpositions[a:line] = {}
  endif
  let l:bufferpositions[a:line][l:id] = {}
  let l:buffercounts[l:id] = get(l:buffercounts, l:id, 0) + 1
  return l:id
endfunction

" Remove a sign from the state for the specified buffer number.
function! annotation#state#removesign(bufnum, id)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif type(a:id) != v:t_number
    throw printf('annotation.InvalidParameterError: unable to remove a sign with an id using an unsupported type (%d).', type(a:id))
  endif

  " assign the buffer state so that we can access the sign state.
  let l:bufferstate = s:STATE[a:bufnum]
  let l:buffersigns = l:bufferstate.signs
  let l:bufferpositions = l:bufferstate.signpositions
  let l:buffercounts = l:bufferstate.signcounts

  " first check that the sign exists so that we can remove it. after removal, we
  " need to add the id back into the availablesigns so it can be reused.
  if !exists('l:buffersigns[a:id]')
    throw printf('annotation.MissingSignError: sign %d from buffer %d does not exist.', a:id, a:bufnum)
  endif

  " use the line number to remove the sign from our stored positions if the
  " reference count allows us to.
  let line = signdata.lnum
  "let positionstate = l:bufferpositions[l:line]
  "let positiondata = exists('positionstate[a:id]')? remove(positionstate, a:id) : {}

  " remove the specified sign, and update its reference count.
  if exists('l:buffercounts[a:id]') && l:buffercounts[a:id] > 0
    let l:buffercounts[a:id] = l:buffercounts[a:id] - 1
  else
    let l:count = get(l:buffercounts, a:id, 0)
    echoerr printf('annotation.AssertionError: expected a positive reference count for removed sign %d at line %d, but the count (%d) is less than or equal to %d.', a:id, l:lnum, l:count, 0)
  endif

  " if the reference count is 0 or less, then we can actually remove the sign
  " data that was created.
  if get(l:buffercounts, a:id, 0) <= 0
    call remove(l:buffercounts, a:id)
    let signdata = remove(l:buffersigns, a:id)
    call add(l:bufferstate.availablesigns, a:id)
  endif

  " do a final check of the signpositions to remove the line if it is empty.
  if empty(positionstate)
    call remove(l:bufferpositions, l:line)
  endif

  return positiondata
endfunction

" Return all the sign ids at the given line of the specified buffer.
function! annotation#state#getsigns(bufnum, line)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif type(a:line) != v:t_number
    throw printf('annotation.InvalidParameterError: unable to get the sign for buffer %d using a line number of an unsupported type (%d).', a:bufnum, type(a:line))
  endif

  let l:bufferstate = s:STATE[a:bufnum]

  " If there are no signs at the given line number, then return nothing.
  if !exists('l:bufferstate.signpositions[a:line]')
    return []
  endif

  " Otherwise, extract the position state and return all the ids.
  let positionstate = l:bufferstate.signpositions[a:line]
  return keys(positionstate)
endfunction

" Return the data stored for the specified sign.
function! annotation#state#hassign(bufnum, id)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif type(a:id) != v:t_number
    throw printf('annotation.InvalidParameterError: unable to get the sign for buffer %d using an id of an unsupported type (%d).', a:bufnum, type(a:id))
  endif

  " Grab the data for the specified sign number from the buffer state.
  let l:bufferstate = s:STATE[a:bufnum]
endfunction

" Return the data stored for the given sign belonging to the specifed buffer.
function! annotation#state#getsign(bufnum, id)
  if !exists('s:STATE[a:bufnum]')
    throw printf('annotation.MissingStateError: state for buffer %d does not exist.', a:bufnum)
  elseif type(a:id) != v:t_number
    throw printf('annotation.InvalidParameterError: unable to get the sign for buffer %d using an id of an unsupported type (%d).', a:bufnum, type(a:id))
  endif

  " Grab the data for the specified sign number from the buffer state.
  let l:bufferstate = s:STATE[a:bufnum]
  if !exists('l:bufferstate.signs[a:id]')
    throw printf('annotation.MissingSignError: sign %d from buffer %d does not exist.', a:id, a:bufnum)
  endif
  return l:bufferstate.signs[a:id]
endfunction

" Pretty much for examining the state while debugging...
function annotation#state#STATE()
  return s:STATE
endfunction
