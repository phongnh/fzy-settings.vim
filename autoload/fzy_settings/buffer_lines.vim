function! s:buffer_lines_sink(line) abort
  normal! m'
  execute split(a:line, s:tab)[0]
  normal! ^zvzz
endfunction

function! s:buffer_lines_source() abort
    let linefmt = '%' . len(string(line('$'))) . 'd'
    let format = linefmt . s:tab . '%s'
    return map(getline(1, '$'), 'printf(format, v:key + 1, v:val)')
endfunction

function! fzy_settings#buffer_lines#run() abort
    let items = s:buffer_lines_source()
    if empty(items)
        return fzy_settings#Warn('No lines!')
    endif
    call fzy#Start(items, funcref('s:buffer_lines_sink'), fzy_settings#FzyOpts(' BufLines: ' . expand('%') . ' '))
endfunction
