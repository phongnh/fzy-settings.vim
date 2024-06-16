let s:nbs = nr2char(0xa0)
let s:tab = repeat(s:nbs, 4)

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

function! s:opts(title, space = 0) abort
    let opts = get(g:, 'fzy', {})->copy()->extend({ 'statusline': a:title })
    call get(opts, 'popup', {})->extend({ 'title': a:space ? ' ' .. a:title : a:title })
    return opts
endfunction

function! fzy_settings#uniq(list)
    let visited = {}
    let ret = []
    for l in a:list
        if !empty(l) && !has_key(visited, l)
            call add(ret, l)
            let visited[l] = 1
        endif
    endfor
    return ret
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

" ------------------------------------------------------------------
" FzyCommands
" ------------------------------------------------------------------
function! s:commands_format(line) abort
    let attr = a:line[0:3]
    let [name; line] = split(a:line[4:], ' ')
    let line = fzy_settings#Trim(join(line, ' '))
    let args = fzy_settings#Trim(line[0:3])
    " let address = line[5:11]
    " let complete = line[13:22]
    let definition = fzy_settings#Trim(line[25:])
    let result = [
                \ attr . fzy_settings#Trim(args) . s:nbs . name,
                \ fzy_settings#Trim(definition),
                \ ]
    return result
endfunction

function! s:commands_source() abort
    let items = split(call('execute', ['command']), '\n')[1:]
    return map(fzy_settings#AlignLists(map(items, 's:commands_format(v:val)')), 'join(v:val, " ")')
endfunction

function! s:commands_sink(line) abort
    let cmd = matchstr(a:line[7:], '\zs\S*\ze')
    call feedkeys(':' . cmd . (a:line[0] == '!' ? '' : ' '), 'n')
endfunction

function! fzy_settings#commands() abort
    let items = s:commands_source()
    if empty(items)
        call fzy_settings#Warn('No command items!')
        return
    endif
    call fzy#Start(items, funcref('s:commands_sink'), s:opts('Commands'))
endfunction

" ------------------------------------------------------------------
" FzyCommandHistory
" FzySearchHistory
" FzyCommandHistoryEdit
" FzySearchHistoryEdit
" ------------------------------------------------------------------
function! s:history_source(type) abort
    let max = histnr(a:type)
    let fmt = '%' . len(string(max)) . 'd'
    let list = filter(map(range(1, max), 'histget(a:type, -v:val)'), '!empty(v:val)')
    return map(list, 'printf(fmt, v:key) . s:nbs . v:val')
endfunction

nnoremap <Plug>(-fzy-vim-do) :execute g:__fzy_command<CR>
nnoremap <Plug>(-fzy-/) /
nnoremap <Plug>(-fzy-:) :

function! s:history_sink(type, line) abort
    let prefix = "\<Plug>(-fzy-" . a:type . ')'
    let item = matchstr(a:line, '\s*[0-9]\+' . s:nbs . '*\zs.*')
    if a:type == ':'
        call histadd(a:type, item)
    endif
    let g:__fzy_command = 'normal ' . prefix . item . "\<CR>"
    call feedkeys("\<Plug>(-fzy-vim-do)")
endfunction

function! fzy_settings#command_history() abort
    let items = s:history_source(':')
    if empty(items)
        call fzy_settings#Warn('No command history items!')
        return
    endif
    call fzy#Start(items, funcref('s:history_sink', [':']), s:opts('CommandHistory'))
endfunction

function! fzy_settings#search_history() abort
    let items = s:history_source('/')
    if empty(items)
        call fzy_settings#Warn('No search history items!')
        return
    endif
    call fzy#Start(items, funcref('s:history_sink', ['/']), s:opts('SearchHistory'))
endfunction

function! s:history_edit_sink(type, line) abort
    let prefix = "\<Plug>(-fzy-" . a:type . ')'
    let item = matchstr(a:line, '\s*[0-9]\+' . s:nbs . '*\zs.*')
    call histadd(a:type, item)
    redraw
    call feedkeys(a:type . "\<Up>", 'n')
endfunction

function! fzy_settings#command_history_edit() abort
    let items = s:history_source(':')
    if empty(items)
        call fzy_settings#Warn('No command history items!')
        return
    endif
    call fzy#Start(items, funcref('s:history_edit_sink', [':']), s:opts('CommandHistoryEdit'))
endfunction

function! fzy_settings#search_history_edit() abort
    let items = s:history_source('/')
    if empty(items)
        call fzy_settings#Warn('No search history items!')
        return
    endif
    call fzy#Start(items, funcref('s:history_edit_sink', ['/']), s:opts('SearchHistoryEdit'))
endfunction
