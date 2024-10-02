function! fzy_settings#trim(str) abort
    return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

if exists('*trim')
    function! fzy_settings#trim(str) abort
        return trim(a:str)
    endfunction
endif

function! fzy_settings#warn(message) abort
    echohl WarningMsg
    echomsg a:message
    echohl None
    return 0
endfunction

function! fzy_settings#try_exe(cmd) abort
    try
        execute a:cmd
    catch
        echohl ErrorMsg
        echomsg matchstr(v:exception, '^Vim\%((\a\+)\)\=:\zs.*')
        echohl None
    endtry
endfunction

function! fzy_settings#align_lists(lists) abort
    let maxes = {}
    for list in a:lists
        let i = 0
        while i < len(list)
            let maxes[i] = max([get(maxes, i, 0), len(list[i])])
            let i += 1
        endwhile
    endfor
    for list in a:lists
        call map(list, "printf('%-'.maxes[v:key].'s', v:val)")
    endfor
    return a:lists
endfunction

function! fzy_settings#fzy_opts(title) abort
    let opts = get(g:, 'fzy', {})->deepcopy()->extend({ 'statusline': a:title })
    call get(opts, 'popup', {})->extend({ 'title': a:title })
    return opts
endfunction
