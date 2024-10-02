function! s:registers_sink(line) abort
    call setreg('"', getreg(a:line[4]))
    echohl ModeMsg
    echo 'Yanked!'
    echohl None
endfunction

function! s:registers_source() abort
    let items = split(call('execute', ['registers']), '\n')[1:]
    call map(items, 'fzy_settings#trim(v:val)')
    return items
endfunction

function! fzy_settings#registers#run() abort
    let items = s:registers_source()
    if empty(items)
        return fzy_settings#warn('No register items!')
    endif
    call fzy#Start(items, funcref('s:registers_sink'), fzy_settings#fzy_opts('Registers'))
endfunction
