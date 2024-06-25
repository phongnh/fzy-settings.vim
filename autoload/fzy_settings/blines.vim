function! s:blines_sink(line) abort
  normal! m'
  execute split(a:line, g:fzy_symbols.sep)[0]
  normal! ^zvzz
endfunction

function! s:blines_source() abort
    let linefmt = '%' . len(string(line('$'))) . 'd'
    let format = linefmt . g:fzy_symbols.sep . '%s'
    return map(getline(1, '$'), 'printf(format, v:key + 1, v:val)')
endfunction

function! fzy_settings#blines#run() abort
    let items = s:blines_source()
    if empty(items)
        return fzy_settings#Warn('No lines!')
    endif
    call fzy#Start(items, funcref('s:blines_sink'), fzy_settings#FzyOpts('BufLines: ' . expand('%')))
endfunction
