function! fzy_settings#Trim(str) abort
    return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

if exists('*trim')
    function! fzy_settings#Trim(str) abort
        return trim(a:str)
    endfunction
endif

function! fzy_settings#Warn(message) abort
    echohl WarningMsg
    echomsg a:message
    echohl None
    return 0
endfunction

function! fzy_settings#TryExe(cmd) abort
    try
        execute a:cmd
    catch
        echohl ErrorMsg
        echomsg matchstr(v:exception, '^Vim\%((\a\+)\)\=:\zs.*')
        echohl None
    endtry
endfunction

function! fzy_settings#AlignLists(lists) abort
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

function! fzy_settings#IsUniversalCtags(ctags_bin) abort
    return system(a:ctags_bin . ' --version') =~# 'Universal Ctags'
endfunction

function! fzy_settings#FzyOpts(title) abort
    let opts = get(g:, 'fzy', {})->copy()->extend({ 'statusline': a:title })
    call get(opts, 'popup', {})->extend({ 'title': a:title })
    return opts
endfunction

" ------------------------------------------------------------------
" FzyFindAll
" ------------------------------------------------------------------
function! fzy_settings#find_all(dir) abort
    try
        let g:fzy.findcmd = g:fzy_find_all_command
        execute 'FzyFind ' a:dir
    finally
        let g:fzy.findcmd = g:fzy_find_command
    endtry
endfunction
