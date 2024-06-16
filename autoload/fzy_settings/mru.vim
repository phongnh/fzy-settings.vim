let s:fzy_mru_exclude = [
            \ '^/usr/',
            \ '^/opt/',
            \ '^/etc/',
            \ '^/var/',
            \ '^/tmp/',
            \ '^/private/',
            \ '\.git/',
            \ '/\?\.gems/',
            \ '\.vim/plugged/',
            \ '\.fugitiveblame$',
            \ 'COMMIT_EDITMSG$',
            \ 'git-rebase-todo$',
            \ ]

function! s:buflisted() abort
    return filter(range(1, bufnr('$')), 'buflisted(v:val) && getbufvar(v:val, "&filetype") != "qf"')
endfunction

function! s:vim_recent_files() abort
    let recent_files = fzy_settings#uniq(
                \ map(
                \   filter([expand('%')], 'len(v:val)')
                \   + filter(map(s:buflisted(), 'bufname(v:val)'), 'len(v:val)')
                \   + filter(copy(v:oldfiles), "filereadable(fnamemodify(v:val, ':p'))"),
                \   'fnamemodify(v:val, ":~:.")'
                \ )
                \ )

    for l:pattern in s:fzy_mru_exclude
        call filter(recent_files, 'v:val !~ l:pattern')
    endfor

    return recent_files
endfunction

function! s:vim_recent_files_in_cwd() abort
    let l:pattern = '^' . getcwd()
    return filter(s:vim_recent_files(), 'fnamemodify(v:val, ":p") =~ l:pattern')
endfunction

function! s:mru_sink(editcmd, choice) abort
    let fname = fnameescape(a:choice)
    call fzy_settings#TryExe(printf('%s %s', a:editcmd, fname))
endfunction

function! fzy_settings#mru#run() abort
    let items = s:vim_recent_files()
    if empty(items)
        return fzy_settings#Warn('No MRU items!')
    endif
    call fzy#Start(items, funcref('s:mru_sink', ['edit']), fzy_settings#FzyOpts(' MRU '))
endfunction

function! fzy_settings#mru#run_in_cwd() abort
    let items = s:vim_recent_files_in_cwd()
    if empty(items)
        return fzy_settings#Warn('No MRU items!')
    endif
    call fzy#Start(items, funcref('s:mru_sink', ['edit']), fzy_settings#FzyOpts(printf(' MRU [directory: %s] ', getcwd())))
endfunction
