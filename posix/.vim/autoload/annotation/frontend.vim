let g:annotation_property = 'annotation'

" Add a new buffer to the current annotation state.
function! annotation#frontend#add_buffer(bufnum)
  if !annotation#state#exists(a:bufnum)
    let state = annotation#state#new(a:bufnum)
  else
    let state = annotation#state#get(a:bufnum)
  endif
  return state
endfunction

" Remove a buffer from the current annotation state.
function! annotation#frontend#del_buffer(bufnum)
  if annotation#state#exists(a:bufnum)
    return annotation#state#remove(a:bufnum)
  endif
  return {}
endfunction

" Add a new property to the state for the specified buffer.
function! annotation#frontend#add_property(bufnum, lnum, col, end_lnum, end_col)
  let newprops = {'lnum': a:lnum, 'col': a:col, 'end_lnum': a:end_lnum, 'end_col': a:end_col}
  let [new, _] = annotation#state#newprop(a:bufnum, newprops)

  " Set up the dictionary that we will use to create the property.
  let new.type = g:annotation_property
  let new.bufnr = a:bufnum
  let new.end_lnum = a:end_lnum
  let new.end_col = a:end_col

  " If the id number wasn't created, then abort the addition of a property.
  if !exists('new.id')
    throw printf('annotation.MissingPropertyError: No identifier was found for new property in buffer %d.', a:bufnum)
  endif

  " Since we're adding a property, set the buffer to readonly to avoid shifting
  " the text properties around in case the user ends up editing the buffer.
  " FIXME: check if the 'setlocal readonly' will output an error message about
  "        there being no write since the last change.
  execute printf('%dbufdo setlocal readonly', a:bufnum)

  " Now we can go ahead and add the property, and then return its data.
  let id = prop_add(new.lnum, new.col, new)
  let key = annotation#property#get(a:bufnum, new.col, new.lnum, id)
  return annotation#state#getprop(a:bufnum, key.id)
endfunction

" Remove a property from the state for the specified buffer.
function! annotation#frontend#del_property(bufnum, lnum, col, id=g:annotation_property)
  let property = annotation#property#get(a:bufnum, a:col, a:lnum, a:id)
  let bounds = annotation#property#bounds(a:bufnum, a:col, a:lnum)

  " If there is no property or we couldn't get the boundaries, then abort.
  " Otherwise, we can remove the property from the state and use it for the id.
  if empty(property)
    throw printf('annotation.MissingPropertyError: no property was found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
  elseif !exists('bounds[property.id]')
    throw printf('annotation.MissingPropertyError: no property boundaries were found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
  endif

  let [selected, lines] = annotation#state#removeprop(a:bufnum, property.id)

  " Create the dictionary key for selecting the specific property.
  let removal = {'both': v:true}
  let removal['bufnr'] = a:bufnum
  let removal['type'] = selected.type
  let removal['id'] = selected.id

  " Actually remove the property from the buffer.
  let [left, _, right, _] = bounds[property.id]
  let [top, bottom] = [min(lines), max(lines)]

  let removed = (top == bottom)? prop_remove(removal, top) : prop_remove(removal, top, bottom)
  if removed < 1
    throw printf('annotation.VimFunctionError: the `%s` function could not delete the following property from lines %d..%d: %s', 'prop_remove', top, bottom, removal)
  endif

  " Return the property data that was removed.
  return selected
endfunction

" Return the property data for the specified property from the given buffer.
function! annotation#frontend#get_property_data(bufnum, lnum, col, id=g:annotation_property)
  let property = annotation#property#get(a:bufnum, a:col, a:lnum, a:id)
  if empty(property)
    throw printf('annotation.MissingPropertyError: no property was found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
  elseif !exists('property.id')
    throw printf('annotation.MissingKeyError: a required key (%s) was missing from the property in buffer %d at line %d column %d.', 'id', a:bufnum, a:lnum, a:col)
  endif

  let data = annotation#state#getdata(a:bufnum, property.id)
  return [property, data]
endfunction

" Set the property data for the specified property from the given buffer.
function! annotation#frontend#set_property_data(bufnum, lnum, col, data, id=g:annotation_property)
  let property = annotation#property#get(a:bufnum, a:col, a:lnum, a:id)
  if empty(property)
    throw printf('annotation.MissingPropertyError: no property was found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
  elseif !exists('property.id')
    throw printf('annotation.MissingKeyError: a required key (%s) was missing from the property in buffer %d at line %d column %d.', 'id', a:bufnum, a:lnum, a:col)
  endif

  if type(a:data) == v:t_func
    let property = annotation#state#getprop(a:bufnum, property.id)
    let newdata = a:data(property)
  else
    let newdata = a:data
  endif

  let updated = annotation#state#setdata(a:bufnum, property.id, newdata)
  return [property, updated]
endfunction

function! annotation#frontend#show_property_data(bufnum, lnum, col, data, id=g:annotation_property, persist=v:false)
  let property = annotation#property#get(a:bufnum, a:col, a:lnum, a:id)
  if empty(property)
    echohl ErrorMsg | echomsg printf('annotation.MissingPropertyError: unable to find a property to show at line %d column %d of buffer %d.', a:lnum, a:col, a:bufnum) | echohl None
    return []
  elseif !exists('property.id')
    throw printf('annotation.MissingKeyError: a required key (%s) was missing from the property in buffer %d at line %d column %d.', 'id', a:bufnum, a:lnum, a:col)
  endif

  let property = annotation#state#getprop(a:bufnum, property.id)
  if type(a:data) == v:t_func
    let lines = a:data(property)
  elseif type(a:data) == v:t_string
    let lines = split(a:data, "\n")
  elseif type(a:data) == v:t_list
    let lines = a:data
  else
    throw printf('annotation.InvalidPropertyError: the data that was specified to be shown for property %d is an unsupported type (%d).', property.id, type(a:data))
  endif

  let title = printf('Annotation #%d', property.id)
  let [winpos, wininfo] = annotation#ui#propertytooltip(lines, title, property, a:persist)
  return [winpos, wininfo]
endfunction

function! annotation#frontend#load_buffer(bufstr, filename)
  let infile = printf('%s.annotations', a:filename)
  if filereadable(infile)
    let inlines = readfile(infile)
    let input = join(inlines, "\n")
    let indata = json_decode(input)
    call annotation#property#load(str2nr(a:bufstr), indata)
  endif
endfunction

function! annotation#frontend#save_buffer(bufstr, filename)
  let outfile = printf('%s.annotations', a:filename)
  let bufnum = (type(a:bufstr) == v:t_number)? a:bufstr : str2nr(a:bufstr)

  " Figure out whether the specified buffer has some annotations or properties
  " needing to be saved. If so, then make sure we can write the file and do it.
  let is_empty = annotation#property#empty(bufnum)
  if !is_empty

    " If the file isn't readable, it doesn't exist. If it isn't writable, then
    " we don't have permissions to do anything and we can skip over saving.
    if !filereadable(outfile) || filewritable(outfile)
      let output = annotation#property#save(str2nr(a:bufstr))
      let outdata = json_encode(output)
      let outlines = split(outdata, "\n")
      let res = writefile(outlines, outfile, 's')
    endif

  " If the specified buffer doesn't have any annotations, then we need to check
  " if the file is readable and writable so that we can remove it.
  else
    if filereadable(outfile) || filewritable(outfile)
      if !delete(outfile)
        echomsg printf('Removing annotation file (%s) for buffer %d due to no remaining annotations.', outfile, bufnum)
      else
        echohl ErrorMsg | echomsg printf('annotation.InternalError: unable to remove the specified file: %s', outfile) | echohl None
      endif
    endif
  endif
endfunction
