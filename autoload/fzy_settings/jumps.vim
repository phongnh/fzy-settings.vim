function! s:jumps_sink(line) abort
    let list = split(a:line)
    if len(list) < 4
        return
    endif

    let [linenr, column, filepath] = [list[1], list[2]+1, join(list[3:])]

    let lines = getbufline(filepath, linenr)
    if empty(lines)
        if stridx(join(split(getline(linenr))), filepath) == 0
            let filepath = bufname('%')
        elseif !filereadable(filepath)
            return
        endif
    endif

    execute 'silent edit ' filepath
    call cursor(linenr, column)
endfunction

function! s:jumps_source() abort
    return split(call('execute', ['jumps']), '\n')[1:]
endfunction

function! fzy_settings#jumps#run() abort
    let items = s:jumps_source()
    if len(items) < 2
        return fzy_settings#Warn('No jump items!')
    endif
    call fzy#Start(items, funcref('s:jumps_sink'), fzy_settings#FzyOpts(' Jumps '))
endfunction
