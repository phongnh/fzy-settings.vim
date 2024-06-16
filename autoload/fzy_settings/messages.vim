function! s:messages_sink(e) abort
    let @" = a:e
    echohl ModeMsg
    echo 'Yanked!'
    echohl None
endfunction

function! s:messages_source() abort
    return split(call('execute', ['messages']), '\n')
endfunction

function! fzy_settings#messages#run() abort
    let items = s:messages_source()
    if empty(items)
        return fzy_settings#Warn('No message items!')
    endif
    call fzy#Start(items, funcref('s:messages_sink'), fzy_settings#FzyOpts(' Messages '))
endfunction
