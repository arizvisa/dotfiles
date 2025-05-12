""" Text-properties / Virtual-text test for annotation of plaintext files.
""" XXX: This is _very_ preliminary and still being experimented with.

if exists('g:loaded_annotation') && g:loaded_annotation
    finish
endif
let g:loaded_annotation = v:true

""" FIXME: the things in this script need to be renamed and refactored into
"""        their own autoload library as the `annotation#frontend` namespace.

function! AddState(bufnum)
    let state = annotation#state#new(a:bufnum)
    echoconsole printf("Added state for buffer %d: %s", a:bufnum, state)
endfunction

function! RemoveState(bufnum)
    let oldstate = annotation#state#remove(a:bufnum)
    echoconsole printf("Removed state for buffer %d: %s", a:bufnum, oldstate)
endfunction

function! AddStateIdempotent(bufnum)
    if !annotation#state#exists(a:bufnum)
        let state = annotation#state#new(a:bufnum)
        echoconsole printf("Added state for buffer %d: %s", a:bufnum, state)
    else
        echoconsole printf("Refusing to add already existing state for buffer %d.", a:bufnum)
    endif
endfunction

function! RemoveStateIdempotent(bufnum)
    if annotation#state#exists(a:bufnum)
        let oldstate = annotation#state#remove(a:bufnum)
        echoconsole printf("Removed state for buffer %d: %s", a:bufnum, oldstate)
    else
        echoconsole printf("Refusing to remove non-existing state for buffer %d.", a:bufnum)
    endif
endfunction

function! AddProperty(bufnum, lnum, col, end_lnum, end_col)
    let newprops = {'lnum': a:lnum, 'end_lnum': a:end_lnum}
    let [new, linenumbers] = annotation#state#newprop(a:bufnum, newprops)

    let new.type = 'annotation'
    let new.bufnr = a:bufnum
    let new.end_lnum = a:end_lnum
    let new.end_col = a:end_col

    if !exists('new.id')
        throw printf('annotation.MissingPropertyError: No identifier was found for new property in buffer %d.', a:bufnum)
    endif

    let id = prop_add(a:lnum, a:col, new)
    return annotation#property#get(a:bufnum, a:col, a:lnum, id)
endfunction

function! RemoveProperty(bufnum, lnum, col)
    let bounds = annotation#property#bounds(a:bufnum, a:col, a:lnum)
    let property = annotation#property#get(a:bufnum, a:col, a:lnum, 'annotation')
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

function! GetPropertyData(bufnum, lnum, col)
    let property = annotation#property#get(a:bufnum, a:col, a:lnum, 'annotation')
    if empty(property)
        throw printf('annotation.MissingPropertyError: no property was found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
    elseif !exists('property.id')
        throw printf('annotation.MissingKeyError: a required key (%s) was missing from the property in buffer %d at line %d column %d.', 'id', a:bufnum, a:lnum, a:col)
    endif

    let data = annotation#state#getdata(a:bufnum, property.id)
    echoconsole printf('Fetching data: %s', data)
    return [property, data]
endfunction

function! SetPropertyData(bufnum, lnum, col)
    let property = annotation#property#get(a:bufnum, a:col, a:lnum, 'annotation')
    if empty(property)
        throw printf('annotation.MissingPropertyError: no property was found in buffer %d at line %d column %d.', a:bufnum, a:lnum, a:col)
    elseif !exists('property.id')
        throw printf('annotation.MissingKeyError: a required key (%s) was missing from the property in buffer %d at line %d column %d.', 'id', a:bufnum, a:lnum, a:col)
    endif

    let data = annotation#state#getdata(a:bufnum, property.id)
    if !exists('data.note')
        let data['note'] = []
    endif

    let newnote = input('Note: ')
    call add(data['note'], newnote)
    let updated = annotation#state#setdata(a:bufnum, property.id, data)
    return [property, updated]
endfunction

" FIXME: need some event for dealing with (empty) buffers created at startup
augroup annotations
    autocmd!
    autocmd BufRead * call AddStateIdempotent(expand('<abuf>'))
    autocmd BufAdd * call AddStateIdempotent(expand('<abuf>'))
    autocmd BufDelete * call RemoveStateIdempotent(expand('<abuf>'))
augroup END

call prop_type_add('annotation', {'highlight': 'DiffText', 'override': v:true})

xmap <C-m>n <Esc><Cmd>call AddProperty(bufnr(), getpos("'<")[1], getpos("'<")[2], getpos("'>")[1], 1 + getpos("'>")[2])<CR>
nmap <C-m>n <Esc><Cmd>call AddProperty(bufnr(), line('.'), match(getline('.'), '\S'), line('.'), col('$'))<CR>
nmap <C-m>x <Cmd>call RemoveProperty(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
nmap <C-m>N <Cmd>call SetPropertyData(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
nmap <C-m>? <Cmd>call GetPropertyData(bufnr(), getpos('.')[1], getpos('.')[2])<CR>
