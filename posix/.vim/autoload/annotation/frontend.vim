let g:annotation_property = 'annotation'

function! annotation#frontend#add_buffer(bufnum)
  if !annotation#state#exists(a:bufnum)
    let state = annotation#state#new(a:bufnum)
  else
    let state = annotation#state#get(a:bufnum)
  endif
  return state
endfunction

function! annotation#frontend#del_buffer(bufnum)
  if annotation#state#exists(a:bufnum)
    return annotation#state#remove(a:bufnum)
  endif
  return {}
endfunction

function! annotation#frontend#add_property(bufnum, lnum, col, end_lnum, end_col)
    let newprops = {'lnum': a:lnum, 'col': a:col, 'end_lnum': a:end_lnum, 'end_col': a:end_col}
    let [new, linenumbers] = annotation#state#newprop(a:bufnum, newprops)

    let new.type = g:annotation_property
    let new.bufnr = a:bufnum
    let new.end_lnum = a:end_lnum
    let new.end_col = a:end_col

    if !exists('new.id')
        throw printf('annotation.MissingPropertyError: No identifier was found for new property in buffer %d.', a:bufnum)
    endif

    let id = prop_add(a:lnum, a:col, new)
    return annotation#property#get(a:bufnum, a:col, a:lnum, id)
endfunction

function! annotation#frontend#del_property(bufnum, lnum, col, id=g:annotation_property)
    let bounds = annotation#property#bounds(a:bufnum, a:col, a:lnum)
    let property = annotation#property#get(a:bufnum, a:col, a:lnum, a:id)
    if empty(property)
        throw printf('annotation.MissingPropertyError: no property was found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
    elseif !exists('bounds[property.id]')
        throw printf('annotation.MissingPropertyError: no property boundaries were found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
    endif

    let removal = copy(property)
    let removal['type'] = property.type
    let removal['bufnr'] = a:bufnum
    let removal['id'] = property.id

    let [left, top, right, bottom] = bounds[property.id]
    let removed = prop_remove(removal, top, bottom)
    if removed < 1
        throw printf('annotation.VimFunctionError: the `%s` function could not delete the following property from lines %d..%d: %s', 'prop_remove', top, bottom, removal)
    endif

    let [result, lines] = annotation#state#removeprop(a:bufnum, property.id)
    return result
endfunction

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

function! annotation#frontend#set_property_data(bufnum, lnum, col, data, id=g:annotation_property)
    let property = annotation#property#get(a:bufnum, a:col, a:lnum, a:id)
    if empty(property)
        throw printf('annotation.MissingPropertyError: no property was found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
    elseif !exists('property.id')
        throw printf('annotation.MissingKeyError: a required key (%s) was missing from the property in buffer %d at line %d column %d.', 'id', a:bufnum, a:lnum, a:col)
    endif

    if type(a:data) == v:t_func
        let [property, rows] = annotation#state#getprop(a:bufnum, property.id)
        let newdata = a:data(property)
    else
        let newdata = a:data
    endif

    let updated = annotation#state#setdata(a:bufnum, property.id, newdata)
    return [property, updated]
endfunction
