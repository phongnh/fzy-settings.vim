nnoremap <Plug>(-fzy-vim-do) :execute g:__fzy_command<CR>
nnoremap <Plug>(-fzy-/) /
nnoremap <Plug>(-fzy-:) :

function! s:history_source(type) abort
    let max = histnr(a:type)
    let fmt = '%' . len(string(max)) . 'd'
    let list = filter(map(range(1, max), 'histget(a:type, -v:val)'), '!empty(v:val)')
    return map(list, 'printf(fmt, v:key) . g:fzy_symbols.nbs . v:val')
endfunction

function! s:history_sink(type, line) abort
    let prefix = "\<Plug>(-fzy-" . a:type . ')'
    let item = matchstr(a:line, '\s*[0-9]\+' . g:fzy_symbols.nbs . '*\zs.*')
    if a:type == ':'
        call histadd(a:type, item)
    endif
    let g:__fzy_command = 'normal ' . prefix . item . "\<CR>"
    call feedkeys("\<Plug>(-fzy-vim-do)")
endfunction

function! s:history_prompt_sink(type, line) abort
    let prefix = "\<Plug>(-fzy-" . a:type . ')'
    let item = matchstr(a:line, '\s*[0-9]\+' . g:fzy_symbols.nbs . '*\zs.*')
    call histadd(a:type, item)
    redraw
    call feedkeys(a:type . "\<Up>", 'n')
endfunction

function! fzy_settings#history#command(...) abort
    let items = s:history_source(':')
    if empty(items)
        return fzy_settings#Warn('No command history items!')
    endif
    let sink = get(a:, 1, 0) ? 's:history_sink' : 's:history_prompt_sink'
    call fzy#Start(items, funcref(sink, [':']), fzy_settings#FzyOpts('CommandHistory'))
endfunction

function! fzy_settings#history#search(...) abort
    let items = s:history_source('/')
    if empty(items)
        return fzy_settings#Warn('No search history items!')
    endif
    let sink = get(a:, 1, 0) ? 's:history_sink' : 's:history_prompt_sink'
    call fzy#Start(items, funcref(sink, ['/']), fzy_settings#FzyOpts('SearchHistory'))
endfunction
