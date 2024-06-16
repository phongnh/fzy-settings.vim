function! s:quickfix_sink(line) abort
    let line = a:line
    let filename = fnameescape(split(line, ':\d\+:')[0])
    let linenr = matchstr(line, ':\d\+:')[1:-2]
    let colum = matchstr(line, '\(:\d\+\)\@<=:\d\+:')[1:-2]
    execute 'edit ' . filename
    call cursor(linenr, colum)
endfunction

function! s:quickfix_format(v) abort
    return bufname(a:v.bufnr) . ':' . a:v.lnum . ':' . a:v.col . ':' . a:v.text
endfunction

function! s:quickfix_source() abort
    return map(getqflist(), 's:quickfix_format(v:val)')
endfunction

function! fzy_settings#quickfix#run() abort
    let items = s:quickfix_source()
    if empty(items)
        return fzy_settings#Warn('No quickfix items!')
    endif
    let title = get(getqflist({ 'title': 1 }), 'title', '')
    let title = ' Quickfix' . (strlen(title) ? ': ' : '') . title . ' '
    call fzy#Start(items, funcref('s:quickfix_sink'), fzy_settings#FzyOpts(title))
endfunction

function! s:location_list_source() abort
    return map(getloclist(0), 's:quickfix_format(v:val)')
endfunction

function! fzy_settings#quickfix#loclist() abort
    let items = s:location_list_source()
    if empty(items)
        return fzy_settings#Warn('No location list items!')
    endif
    let title = get(getloclist(0, { 'title': 1 }), 'title', '')
    let title = ' LocationList' . (strlen(title) ? ': ' : '') . title . ' '
    call fzy#Start(items, funcref('s:quickfix_sink'), fzy_settings#FzyOpts(title))
endfunction
