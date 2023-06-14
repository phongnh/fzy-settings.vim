function! s:warn(message) abort
    echohl WarningMsg
    echomsg a:message
    echohl None
    return 0
endfunction

function! s:no_highlight(text) abort
    return "\x1b[m" . a:text
endfunction

if exists('*trim')
    function! s:trim(str) abort
        return trim(a:str)
    endfunction
else
    function! s:trim(str) abort
        return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
    endfunction
endif

function! s:fzy_opts(opts) abort
    let l:opts = extend({}, s:opts(''))
    let l:opts = extend(l:opts, a:opts)
    return l:opts
endfunction

function! s:opts(title, space = 0) abort
    let opts = get(g:, 'fzy', {})->copy()->extend({'statusline': a:title})
    call get(opts, 'popup', {})->extend({'title': a:space ? ' ' .. a:title : a:title})
    return opts
endfunction

function! s:outline_format(lists) abort
    let l:result = []
    let l:format = printf('%%%ds', len(string(line('$'))))
    for list in a:lists
        let linenr = list[2][:len(list[2])-3]
        let line = s:trim(getline(linenr))
        call add(l:result, [
                    \ printf("%s:%s", list[-1], printf(l:format, linenr)),
                    \ s:no_highlight(substitute(line, list[0], list[0], ''))
                    \ ])
    endfor
    return l:result
endfunction

function! s:outline_source(tag_cmds) abort
    if !filereadable(expand('%'))
        throw 'Save the file first'
    endif
    let lines = []
    for cmd in a:tag_cmds
        let lines = split(system(cmd), "\n")
        if !v:shell_error && len(lines)
            break
        endif
    endfor
    if v:shell_error
        throw get(lines, 0, 'Failed to extract tags')
    elseif empty(lines)
        throw 'No tags found'
    endif
    return map(s:outline_format(map(lines, 'split(v:val, "\t")')), 'join(v:val, "\t")')
endfunction

function! s:outline_sink(path, editcmd, line) abort
    let g:fzy_lines = a:line
    if !empty(a:line)
        let linenr = s:trim(split(split(a:line, "\t")[0], ":")[-1])
        execute printf("%s +%s %s", a:editcmd, linenr, a:path)
    endif
endfunction

function! fzy_settings#outline() abort
    try
        let filetype = get({ 'cpp': 'c++' }, &filetype, &filetype)
        let filename = expand('%:S')
        let tag_cmds = [
                    \ printf('%s -f - --sort=no --excmd=number --language-force=%s %s 2>/dev/null', g:fzy_ctags, filetype, filename),
                    \ printf('%s -f - --sort=no --excmd=number %s 2>/dev/null', g:fzy_ctags, filename)
                    \ ]
        call fzy#Start(s:outline_source(tag_cmds), funcref('s:outline_sink', [expand('%:p'), 'edit']), s:fzy_opts({ 'prompt': 'Outline> ' }))
    catch
        call s:warn(v:exception)
    endtry
endfunction
