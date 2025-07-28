function! s:empty_bounds(bounds)
  if type(a:bounds) != v:t_list
    throw printf('annotation.InvalidParameterError: unable to check the specified boundaries due to an invalid type (%d): %s', type(a:bounds), a:bounds)
  elseif len(a:bounds) != 4
    throw printf('annotation.InvalidParameterError: the specified boundaries have an invalid length (%d): %s', len(a:bounds), a:bounds)
  endif

  let [x1, y1, x2, y2] = a:bounds
  return x1 == y1 && x2 == y2
endfunction

" Return a list containing the specified properties spanning multiple lines of
" the given buffer number and including the specified coordinate.
function! s:find_property_lines(bufnum, x, y, type_or_id)
  let l:key = {'bufnr': a:bufnum}

  let [l:findkey, l:listkey] = [copy(l:key), copy(l:key)]
  if type(a:type_or_id) == v:t_number
    let l:findkey['id'] = a:type_or_id
    let l:listkey['ids'] = [a:type_or_id]
  elseif type(a:type_or_id) == v:t_string
    let l:findkey['type'] = a:type_or_id
    let l:listkey['types'] = [a:type_or_id]
  else
    throw printf('annotation.InvalidParameterError: unable to determine the key using an unsupported type (%d)', type(a:type_or_id))
  endif

  let [l:findkey['col'], l:findkey['lnum']] = [a:x, a:y]
  let l:property = prop_find(l:findkey)

  if empty(l:property) | return [] | endif

  let [l:px, l:py] = [get(l:property, 'col', a:x), get(l:property, 'lnum', a:y)]
  let l:listkey['end_lnum'] = -1
  let l:stupid = prop_list(l:py, l:listkey)

  let [l:index, l:properties] = [0, []]
  while l:index < len(l:stupid) && get(l:stupid[l:index], 'end', 0) == 0
    let l:property = l:stupid[l:index]
    call add(l:properties, l:property)
    let l:index = l:index + 1
  endwhile
  while l:index < len(l:stupid) && get(l:stupid[l:index], 'end', 0) == 1 && get(l:stupid[l:index], 'lnum', -1) == a:y
    let l:property = l:stupid[l:index]
    call add(l:properties, l:property)
    let l:index = l:index + 1
  endwhile

  if l:index < len(l:stupid)
    call add(l:properties, l:stupid[l:index])
  endif

  return l:properties
endfunction

" Return a list containing the specified properties that are split up across
" multiple lines of the given buffer number and coordinate.
function! s:find_property_block(bufnum, x, y, type_or_id)
  let l:key = {'bufnr': a:bufnum}

  let [l:findkey, l:listkey] = [copy(l:key), copy(l:key)]
  if type(a:type_or_id) == v:t_number
    let l:findkey['id'] = a:type_or_id
    let l:listkey['ids'] = [a:type_or_id]
  elseif type(a:type_or_id) == v:t_string
    let l:findkey['type'] = a:type_or_id
    let l:listkey['types'] = [a:type_or_id]
  else
    throw printf('annotation.InvalidParameterError: unable to determine the key using an unsupported type (%d)', type(a:type_or_id))
  endif

  " First make sure we can find the property, and then use it to get the
  " starting position that we will seek backwards from.
  let [l:findkey['col'], l:findkey['lnum']] = [a:x, a:y]
  let l:current = prop_find(l:findkey)

  if empty(l:current) | return [] | endif
  let [l:cx, l:cy] = [get(l:current, 'col', a:x), get(l:current, 'lnum', a:y)]

  " Start scanning upward for any text properties that are contiguous.
  let [l:nx, l:ny, l:property] = [l:cx, l:cy, l:current]
  while abs(l:ny - l:cy) <= 1
    let [l:cx, l:cy] = [l:nx, l:ny]

    let [l:findkey['col'], l:findkey['lnum']] = [l:cx, l:cy - 1]
    let l:property = prop_find(l:findkey, 'b')
    if empty(l:property)
      break
    endif
    let [l:nx, l:ny] = [get(l:property, 'col'), get(l:property, 'lnum')]
  endwhile

  let l:start = l:cy

  " Next we reset the position and then do the exact same, but scan forward for
  " any properties that are contiguous.
  let [l:cx, l:cy] = [get(l:current, 'col', a:x), get(l:current, 'lnum', a:y)]
  let [l:nx, l:ny, l:property] = [l:cx, l:cy, l:current]

  while abs(l:ny - l:cy) <= 1
    let [l:cx, l:cy] = [l:nx, l:ny]

    let [l:findkey['col'], l:findkey['lnum']] = [l:cx, l:cy + 1]
    let l:property = prop_find(l:findkey, 'f')
    if empty(l:property)
      break
    endif
    let [l:nx, l:ny] = [get(l:property, 'col'), get(l:property, 'lnum')]
  endwhile

  let l:stop = l:cy

  " Finally, we have the line number boundaries to gather all of the specified
  " text properties.
  let l:listkey['end_lnum'] = l:stop
  return prop_list(l:start, l:listkey)
endfunction

" Return the start and end column of the specified property. The end column
" references the text immediately following the property.
function! s:find_property_span(property)
  if !exists('a:property.col')
    throw printf('annotation.InvalidPropertyError: unable to determine the start of the specified property: %s', a:property)
  else
    let start = a:property['col']
  endif

  " Figure out whether we were given the stop column or if we have to
  " calculate the column index by ourselves using the property length.
  if exists('a:property.end_col')
    let stop = a:property['end_col']
  elseif exists('a:property.length')
    let stop = start + a:property['length']
  else
    throw printf('annotation.InvalidPropertyError: unable to determine the end of the specified property at line %d column %d: %s', a:y, start, a:property)
  endif

  " Now we can return the span that was calculated.
  return [start, stop]
endfunction

" Filter a list of properties by the specified coordinate.
function! annotation#property#filter_by_point(properties, x, y)
  let spans = mapnew(a:properties, 's:find_property_span(v:val)')

  " Iterate through the list of properties extracting the span from each one.
  let result = []
  for index in range(len(a:properties))
    let property = a:properties[index]
    let [left, right] = spans[index]
    let top = property['lnum']
    let bottom = exists('property.end_lnum')? property['end_lnum'] : top
    let fromproplist = exists('property.start') && exists('property.stop')

    " Verify whether the span of the property contains the specified point.
    if a:y > top && a:y < bottom
      call add(result, property)
    elseif a:y != top && a:y != bottom
      continue
    elseif !fromproplist && a:x >= left && a:x < right
      call add(result, property)
    elseif property['start'] == 0 && property['end'] == 0
      call add(result, property)
    elseif property['start'] == 1 && property['end'] == 1 && a:x >= left && a:x < right
      call add(result, property)
    elseif property['start'] == 1 && property['end'] == 0 && a:x >= left
      call add(result, property)
    elseif property['start'] == 0 && property['end'] == 1 && a:x < right
      call add(result, property)
    endif
  endfor

  " Then we can return our results.
  return result
endfunction

" Filter a list of properties that overlap the specified span.
function! annotation#property#filter_by_span(properties, start, stop, y)
  let spans = mapnew(a:properties, 's:find_property_span(v:val)')

  " Go through the list of properties extracting the span for each one.
  let result = []
  for index in range(len(a:properties))
    let property = a:properties[index]
    let [left, right] = spans[index]
    let top = property['lnum']
    let bottom = exists('property.end_lnum')? property['end_lnum'] : top
    let fromproplist = exists('property.start') && exists('property.stop')

    " Check if the property overlaps with the specified span.
    if a:y > top && a:y < bottom
      call add(result, property)
    elseif a:y != top && a:y != bottom
      continue
    elseif !fromproplist && a:start < right && a:stop >= left
      call add(result, property)
    elseif property['start'] == 0 && property['end'] == 0
      call add(result, property)
    elseif property['start'] == 1 && property['end'] == 1 && a:start < right && a:stop >= left
      call add(result, property)
    elseif property['start'] == 1 && property['end'] == 0 && a:stop >= left
      call add(result, property)
    elseif property['start'] == 0 && property['end'] == 1 && a:start < right
      call add(result, property)
    endif
  endfor

  " That was it, we can now return our results.
  return result
endfunction

" Return the start and stop interval for the property of the specified type or
" id at the given coordinate.
function! annotation#property#getbounds(bufnum, x, y, type_or_id)

  let l:properties = s:find_property_lines(a:bufnum, a:x, a:y, a:type_or_id)
  let l:filtered = annotation#property#filter_by_point(l:properties, a:x, a:y)

  if empty(l:filtered)
    return [a:x, a:y, a:x, a:y]
  endif

  let ids = uniq(sort(mapnew(l:filtered, {index, property -> property['id']})))
  if len(l:filtered) == 1
    let [l:property] = l:filtered
    let l:lnum = l:property['lnum']
    let [l:left, l:right] = s:find_property_span(l:property)
    return [l:left, l:lnum, l:right - 1, l:lnum]

  elseif len(ids) != 1
    let l:filtered = annotation#property#filter_by_point(l:filtered, a:x, a:y)
    let l:property = l:filtered[0]
    let l:lnum = l:property['lnum']
    let [l:left, l:right] = s:find_property_span(l:property)
    return [l:left, l:lnum, l:right - 1, l:lnum]
  endif

  let l:filteredlines = mapnew(l:filtered, {index, property -> property['lnum']})

  let [l:top, l:bottom] = [min(l:filteredlines), max(l:filteredlines)]
  let [l:topindex, l:bottomindex] = [index(l:filteredlines, l:top), index(l:filteredlines, l:bottom)]

  let l:x1 = l:filtered[l:topindex]['col']
  let l:x2 = l:filtered[l:bottomindex]['col'] + l:filtered[l:bottomindex]['length'] - 1
  let l:y1 = l:filtered[l:topindex]['lnum']
  let l:y2 = l:filtered[l:bottomindex]['lnum']

  let l:failure = [a:x, a:y, a:x, a:y]
  if a:y == l:y1 && a:x < l:x1
    return l:failure
  elseif a:y == l:y2 && a:x >= l:x2
    return l:failure
  elseif l:y1 <= a:y && a:y < l:y2
    return [l:x1, l:y1, l:x2, l:y2]
  endif

  return l:failure
endfunction

" Return the boundaries for the block containing the specified text property at
" the given coordinate of the buffer number.
function! annotation#property#getblock(bufnum, x, y, type_or_id)

  let l:properties = s:find_property_block(a:bufnum, a:x, a:y, a:type_or_id)
  if empty(l:properties) | return [a:x, a:y, a:x, a:y] | endif

  if len(l:properties) == 1
    let [l:property] = l:properties
    let [l:lnum, l:left, l:right] = [l:property['lnum'], l:property['col'], l:property['col'] + l:property['length'] - 1]
    return [l:left, l:lnum, l:right, l:lnum]
  endif

  let l:lines = mapnew(l:properties, {index, property -> property['lnum']})
  let [l:top, l:bottom] = [min(l:lines), max(l:lines)]
  let [l:topindex, l:bottomindex] = [index(l:lines, l:top), index(l:lines, l:bottom)]

  let l:lefts = mapnew(l:properties, {index, property -> property['col']})
  let l:rights = mapnew(l:properties, {index, property -> property['col'] + property['length'] - 1})
  let [l:left, l:right] = [min(l:lefts), max(l:rights)]

  let l:x1 = l:left
  let l:x2 = l:right
  let l:y1 = l:top
  let l:y2 = l:bottom

  let l:failure = [a:x, a:y, a:x, a:y]
  if l:x1 <= a:x && a:x <= l:x2 && l:y1 <= a:y && a:y <= l:y2
    return [l:x1, l:y1, l:x2, l:y2]
  endif

  return l:failure
endfunction

" return the X-Y pair for the specified property in the buffer "bufnum" by
" scanning backwards from the given coordinate.
function! annotation#property#scanbackward(bufnum, x, y, type_or_id)
  let [left, top, right, bottom] = annotation#property#getbounds(a:bufnum, a:x, a:y, a:type_or_id)

  let l:key = {'bufnr': a:bufnum}
  if type(a:type_or_id) == v:t_number
    let l:key['id'] = a:type_or_id
  elseif type(a:type_or_id) == v:t_string
    let l:key['type'] = a:type_or_id
  else
    throw printf('annotation.InvalidParameterError: unable to determine the key using an unsupported type (%d)', type(a:type_or_id))
  endif

  if a:y > bottom
    let [l:key['col'], l:key['lnum']] = [a:x, a:y]
  elseif a:y > top && a:y < bottom
    let [l:key['col'], l:key['lnum']] = [left - 1, top]
  elseif a:y == bottom && a:x <= right
    let [l:key['col'], l:key['lnum']] = [left - 1, top]
  elseif a:y == top && a:x >= left
    let [l:key['col'], l:key['lnum']] = [left - 1, top]
  else
    let [l:key['col'], l:key['lnum']] = [a:x, a:y]
  endif

  let result = prop_find(l:key, 'b')
  return empty(result)? [a:x, a:y] : [result['col'], result['lnum']]
endfunction

" return the X-Y pair for the specified property in the buffer "bufnum" by
" scanning forwards from the given coordinate.
function! annotation#property#scanforward(bufnum, x, y, type_or_id)
  let [left, top, right, bottom] = annotation#property#getbounds(a:bufnum, a:x, a:y, a:type_or_id)

  let l:key = {'bufnr': a:bufnum}
  if type(a:type_or_id) == v:t_number
    let l:key['id'] = a:type_or_id
  elseif type(a:type_or_id) == v:t_string
    let l:key['type'] = a:type_or_id
  else
    throw printf('annotation.InvalidParameterError: unable to determine the key using an unsupported type (%d)', type(a:type_or_id))
  endif

  if a:y < top
    let [l:key['col'], l:key['lnum']] = [a:x, a:y]
  elseif a:y > top && a:y < bottom
    let [l:key['col'], l:key['lnum']] = [right + 1, bottom]
  elseif a:y == top && a:x >= left
    let [l:key['col'], l:key['lnum']] = [right + 1, bottom]
  elseif a:y == bottom && a:x <= right
    let [l:key['col'], l:key['lnum']] = [right + 1, bottom]
  else
    let [l:key['col'], l:key['lnum']] = [a:x, a:y]
  endif

  let result = prop_find(l:key, 'f')
  return empty(result)? [a:x, a:y] : [result['col'], result['lnum']]
endfunction

" return all the properties in the specified buffer at the specified coordinate.
function! annotation#property#at(bufnum, x, y)
  let l:key = {'bufnr': a:bufnum}
  let l:found = prop_list(a:y, l:key)

  let l:result = {}
  for l:property in l:found
    if !exists('l:property.id')
      continue
    endif
    let l:id = l:property['id']

    let [l:left, l:right] = [l:property['col'], l:property['col'] + l:property['length']]
    let l:property['lnum'] = a:y

    if l:left <= a:x && a:x < l:right
      let l:result[l:id] = l:property
    endif
  endfor

  return l:result
endfunction

" Return a dictionary of all the properties applied to the specified line
" numbers of the given buffer number.
function! annotation#property#from(bufnum, ystart, ystop)
  let l:key = {'bufnr': a:bufnum, 'end_lnum': a:ystop}
  let l:found = prop_list(a:ystart, l:key)

  let l:result = {}
  for l:property in l:found
    if !exists('l:property.id')
      continue
    endif
    let l:id = l:property['id']
    let l:result[l:id] = l:property
  endfor

  return l:result
endfunction

" Return a dictionary containing the first property at the specified coordinate
" of the given buffer number.
function! annotation#property#get(bufnum, x, y, type_or_id)
  let l:key = {'bufnr': a:bufnum}

  if type(a:type_or_id) == v:t_number
    let l:key['ids'] = [a:type_or_id]
  elseif type(a:type_or_id) == v:t_string
    let l:key['types'] = [a:type_or_id]
  elseif type(a:type_or_id) == v:t_list
    let l:key['types'] = a:type_or_id
  else
    throw printf('annotation.InvalidParameterError: unable to determine the key using an unsupported type (%d)', type(type_or_id))
  endif

  " Grab all of the properties at the specified line number.
  let l:found = prop_list(a:y, l:key)

  " Now we iterate through them finding the start and stop columns in order to
  " figure out which property the caller is trying to select.
  for l:property in l:found
    let [start, stop] = s:find_property_span(l:property)

    " If the column (x) is within the property span, then return it.
    if a:x >= start && a:x < stop
      return l:property
    endif
  endfor

  " Otherwise the property wasn't found, and we need to return empty.
  return {}
endfunction

" Return all the properties and their boundaries at the specified coordinate of
" the given buffer.
function! annotation#property#bounds(bufnum, x, y)
  let l:properties = annotation#property#at(a:bufnum, a:x, a:y)

  let l:result = {}
  for l:idstring in keys(l:properties)  " XXX: srsly, vim?
    let l:id = str2nr(l:idstring)
    let l:bounds = annotation#property#getbounds(a:bufnum, a:x, a:y, l:id)
    if !s:empty_bounds(l:bounds)
      let l:result[l:id] = l:bounds
    endif
  endfor

  return l:result
endfunction

" Remove the given text property from the lines "ystart" to "ystop" for the
" specified buffer number.
function! annotation#property#remove_lines(bufnum, ystart, ystop, type_or_id)
  let l:key = {'bufnr': a:bufnum}

  let l:listkey = copy(l:key)
  let l:listkey['end_lnum'] = a:ystop

  let l:removekey = copy(l:key)

  " figure out which keys to use for fetching the applied properties and
  " removing them.
  if type(a:type_or_id) == v:t_number
    let l:listkey['ids'] = [a:type_or_id]
    let l:removekey['id'] = a:type_or_id
  elseif type(a:type_or_id) == v:t_string
    let l:listkey['types'] = [a:type_or_id]
    let l:removekey['type'] = a:type_or_id
  elseif type(a:type_or_id) == v:t_list
    let l:listkey['types'] = a:type_or_id
    let l:removekey['types'] = a:type_or_id
  else
    throw printf('annotation.InvalidParameterError: unable to determine the key using an unsupported type (%d)', type(a:type_or_id))
  endif

  " grab the properties being removed, and then remove them.
  let l:found = prop_list(a:ystart, l:listkey)
  let l:removed = prop_remove(l:removekey, a:ystart, a:ystop)

  " if the number of removed properties doesn't match what we fetched, then log
  " an error about it to the user.
  if l:removed != len(l:found)
    echoerr printf('annotation.InternalError: expected %d properties to be removed, but %d were removed: %s', len(l:found), l:removed, l:found)
  endif

  return l:found
endfunction

" Return the text selected by the property at the specified coordinates of the
" given buffer number.
function! annotation#property#select(bufnum, x, y, type_or_id)
  let l:bounds = annotation#property#getbounds(a:bufnum, a:x, a:y, a:type_or_id)
  if s:empty_bounds(l:bounds)
    return ''
  endif

  " unpack the boundaries so that we can find the matching text.
  let [x1, y1, x2, y2] = l:bounds

  " start by gathering the specified lines from the buffer into a list
  let [l:lines] = [getline(y1, y2)]

  " If it's only one line, then apply our slice to it.
  if len(l:lines) == 1
    let [l:line] = l:lines
    return [slice(l:line, x1 - 1, x2)]
  endif

  " otherwise we can just slice the first and last lines out of the list.
  let [l:lstring] = slice(l:lines, 0, 1)
  let [l:rstring] = slice(l:lines, -1)

  " use the text property boundaries to slice up the first and last line, then
  " combine everything back into a list containing the selected text.
  let l:result = []
  call extend(l:result, [slice(l:lstring, x1 - 1)])
  if len(l:lines) > 2
    call extend(l:result, slice(l:lines, +1, -1))
  endif
  call extend(l:result, [slice(l:rstring, 0, x2)])
  return l:result
endfunction

" Return the text selected by the property at the specified coordinates of the
" given buffer number.
function! annotation#property#selectblock(bufnum, x, y, type_or_id)
  let l:bounds = annotation#property#getblock(a:bufnum, a:x, a:y, a:type_or_id)
  if s:empty_bounds(l:bounds)
    return ''
  endif

  " unpack the boundaries so that we can find the matching text.
  let [x1, y1, x2, y2] = l:bounds

  " start by gathering the specified lines from the buffer into a list
  let [l:lines] = [getline(y1, y2)]

  " If it's only one line, then apply our slice to it.
  if len(l:lines) == 1
    let [l:line] = l:lines
    return [slice(l:line, x1 - 1, x2)]
  endif

  " otherwise we just need to map each selected line using the x1 and x2
  " positions and return the result.
  return mapnew(l:lines, {index, line -> slice(line, x1 - 1, x2)})
endfunction

" FIXME: add some functions that can be used to load and save the properties
"        associated within a buffer. we need to be able to build a property map
"        to handle the difference between the seraialized and runtime states.

function! annotation#property#save(bufnum)
  let state = annotation#state#exists(a:bufnum)? annotation#state#save(a:bufnum) : {}

  " FIXME: is it better for us to iterate through all the properties in the
  "        document instead of trusting what we got from `annotation#state`?
  let properties = get(state, 'properties', {})
  let annotations = get(state, 'annotations', {})
  let propertymap = get(state, 'propertymap', {})

  " FIXME: Scan the current list of properties and figure out how to translate
  "        them to a property id number that is based at 0. This way the loader
  "        can translate the id number to whatever free properties that are
  "        currently loaded for the target buffer.
  if empty(properties) && empty(annotations) && empty(propertymap)
    return {}
  endif

  return state
endfunction

function! annotation#property#load(bufnum, content)
  if !exists('a:content.properties')
    throw printf('annotation.InvalidParameterError: unable to load properties from the specified dictionary due to a missing key (%s).', 'properties')
  elseif !exists('a:content.annotations')
    throw printf('annotation.InvalidParameterError: unable to load properties from the specified dictionary due to a missing key (%s).', 'annotations')
  elseif !exists('a:content.propertymap')
    throw printf('annotation.InvalidParameterError: unable to load properties from the specified dictionary due to a missing key (%s).', 'propertymap')
  endif

  " FIXME: we need to read from content all the property boundaries so that we
  "        can recreate them one-by-one.
  let properties = get(a:content, 'properties', {})
  let annotations = get(a:content, 'annotations', {})
  let propertymap = get(a:content, 'propertymap', {})

  " First grab all of the ids that are available
  let ids = sort(keys(properties))

  " Then iterate through each of them and use the property data to recreate the
  " property in the current buffer.
  let used = []
  for id in ids
    if !exists('annotations[id]')
      throw printf('annotation.MissingAnnotationError: unable to find the annotations for property %d.', id)
    endif

    " Get the property data and adjust its fields to add it to the specified
    " buffer number.
    let propertydata = properties[id]
    let propertydata['bufnr'] = a:bufnum
    let propertydata['id'] = id

    let newid = prop_add(propertydata.lnum, propertydata.col, propertydata)
    call add(used, newid)
  endfor

  " Finally we can repopulate our property results.
  let propertyresults = {}
  let annotationresults = {}
  for id in used
    let propertyresults[id] = copy(properties[id])
    let annotationresults[id] = deepcopy(annotations[id])
  endfor

  " Now we can just load the annotation data from the content and mark the
  " buffer as readonly to avoid accidentally changing it.
  if !empty(a:content)
    call annotation#state#load(a:bufnum, a:content)

    " FIXME: check if the 'setlocal readonly' will output an error message about
    "        there being no write since the last change.
    execute printf('%dbufdo setlocal buftype=nowrite readonly', a:bufnum)
    return {'properties': propertyresults, 'annotations': annotationresults, 'propertymap': {}}
  endif

  return {}
endfunction

" Utility function used to determine if a file has no annotations applied to it.
function! annotation#property#empty(bufnum)
  let state = annotation#state#exists(a:bufnum)? annotation#state#save(a:bufnum) : {}

  " Check if the saved state is empty, and then check if any fields are empty.
  if empty(state)
    return v:true
  elseif empty(get(state, 'annotations', {}))
    return v:true
  elseif empty(get(state, 'properties', {}))
    return v:true
  else
    return v:false
  endif
endfunction
