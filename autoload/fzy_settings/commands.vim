function! s:commands_format(line) abort
    let attr = a:line[0:3]
    let [name; line] = split(a:line[4:], ' ')
    let line = fzy_settings#trim(join(line, ' '))
    let args = fzy_settings#trim(line[0:3])
    " let address = line[5:11]
    " let complete = line[13:22]
    let definition = fzy_settings#trim(line[25:])
    let result = [
                \ attr . fzy_settings#trim(args) . g:fzy_symbols.nbs . name,
                \ fzy_settings#trim(definition),
                \ ]
    return result
endfunction

function! s:commands_source() abort
    let items = split(call('execute', ['command']), '\n')[1:]
    return map(fzy_settings#align_lists(map(items, 's:commands_format(v:val)')), 'join(v:val, " ")')
endfunction

function! s:commands_sink(line) abort
    let cmd = matchstr(a:line[7:], '\zs\S*\ze')
    call feedkeys(':' . cmd . (a:line[0] == '!' ? '' : ' '), 'n')
endfunction

function! fzy_settings#commands#run() abort
    let items = s:commands_source()
    if empty(items)
        return fzy_settings#warn('No command items!')
    endif
    call fzy#Start(items, funcref('s:commands_sink'), fzy_settings#fzy_opts('Commands'))
endfunction
