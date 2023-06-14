" https://stackoverflow.com/questions/4842424/list-of-ansi-color-escape-sequences
let s:codes = {
            \ 'reset': "\x1b[0m",
            \ 'blue':  "\x1b[34m",
            \ }

function! s:warn(message) abort
    echohl WarningMsg
    echomsg a:message
    echohl None
    return 0
endfunction

function! s:align_lists(lists)
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

if exists('*trim')
    function! s:trim(str) abort
        return trim(a:str)
    endfunction
else
    function! s:trim(str) abort
        return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
    endfunction
endif

function! s:opts(title, space = 0) abort
    let opts = get(g:, 'fzy', {})->copy()->extend({ 'statusline': a:title })
    call get(opts, 'popup', {})->extend({ 'title': a:space ? ' ' .. a:title : a:title })
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

" ------------------------------------------------------------------
" FzyBufferLines
" ------------------------------------------------------------------
function! s:buffer_lines_sink(line) abort
  normal! m'
  execute split(a:line, '\t')[0]
  normal! ^zvzz
endfunction

function! s:buffer_lines_source() abort
    let linefmt = " %4d " . "\t%s"
    let fmtexpr = 'printf(linefmt, v:key + 1, s:codes.reset . v:val)'
    let lines = getline(1, '$')
    return map(lines, fmtexpr)
endfunction

function! fzy_settings#buffer_lines() abort
    let items = s:buffer_lines_source()
    if empty(items)
        call s:warn('No lines!')
        return
    endif
    call fzy#Start(items, funcref('s:buffer_lines_sink'), s:opts('BufLines: ' . expand('%')))
endfunction

" ------------------------------------------------------------------
" FzyBufferTag
" ------------------------------------------------------------------
" columns: tag | filename | linenr | kind | ref
function! s:buffer_tag_format(columns) abort
    let format = printf('%%%ds', len(string(line('$'))))
    let linenr = a:columns[2][:len(a:columns[2])-3]
    return extend([printf(format, linenr)], [s:codes.reset . s:codes.blue . a:columns[0] . s:codes.reset, a:columns[-2], a:columns[-1]])
endfunction

function! s:buffer_tag_source(tag_cmds) abort
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
    return map(s:align_lists(map(lines, 's:buffer_tag_format(split(v:val, "\t"))')), 'join(v:val, "\t")')
endfunction

function! s:buffer_tag_sink(path, editcmd, line) abort
    if !empty(a:line)
        let linenr = s:trim(split(a:line, "\t")[0])
        execute printf("%s +%s %s", a:editcmd, linenr, a:path)
    endif
endfunction

function! fzy_settings#buffer_tag() abort
    try
        let filetype = get({ 'cpp': 'c++' }, &filetype, &filetype)
        let filename = expand('%:S')
        let sort = executable('sort') ? '| sort -s -k 5' : ''
        let tag_cmds = [
                    \ printf('%s -f - --sort=no --excmd=number --language-force=%s %s 2>/dev/null %s', g:fzy_ctags, filetype, filename, sort),
                    \ printf('%s -f - --sort=no --excmd=number %s 2>/dev/null %s', g:fzy_ctags, filename, sort)
                    \ ]
        call fzy#Start(s:buffer_tag_source(tag_cmds), funcref('s:buffer_tag_sink', [expand('%:p'), 'edit']), s:opts('BufTag: ' . expand('%')))
    catch
        call s:warn(v:exception)
    endtry
endfunction

" ------------------------------------------------------------------
" FzyOutline
" ------------------------------------------------------------------
" columns: tag | filename | linenr | kind | ref
function! s:outline_format(columns) abort
    let format = printf('%%%ds', len(string(line('$'))))
    let linenr = a:columns[2][:len(a:columns[2])-3]
    let line = s:trim(getline(linenr))
    return extend([printf(format, linenr)], [s:codes.reset . substitute(line, a:columns[0], s:codes.blue . a:columns[0] . s:codes.reset, '')])
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
    return map(map(lines, 's:outline_format(split(v:val, "\t"))'), 'join(v:val, "\t")')
endfunction

function! s:outline_sink(path, editcmd, line) abort
    if !empty(a:line)
        let linenr = s:trim(split(a:line, "\t")[0])
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
        call fzy#Start(s:outline_source(tag_cmds), funcref('s:outline_sink', [expand('%:p'), 'edit']), s:opts('Outline: ' . expand('%')))
    catch
        call s:warn(v:exception)
    endtry
endfunction

" ------------------------------------------------------------------
" FzyQuickfix
" FzyLocationList
" ------------------------------------------------------------------
function! s:quickfix_sink(line) abort
    let line = a:line
    let filename = fnameescape(split(line, ':\d\+:')[0])
    let linenr = matchstr(line, ':\d\+:')[1:-2]
    let colum = matchstr(line, '\(:\d\+\)\@<=:\d\+:')[1:-2]
    execute 'edit ' . filename
    call cursor(linenr, colum)
endfunction

function! s:quickfix_format(v) abort
    return bufname(a:v.bufnr) . ':' . a:v.lnum . ':' . a:v.col . ':' . a:v.text
endfunction

function! s:quickfix_source() abort
    return map(getqflist(), 's:quickfix_format(v:val)')
endfunction

function! fzy_settings#quickfix() abort
    let items = s:quickfix_source()
    if empty(items)
        call s:warn('No quickfix items!')
        return
    endif
    let title = get(getqflist({ 'title': 1 }), 'title', '')
    let title = 'Quickfix' . (strlen(title) ? ': ' : '') . title
    call fzy#Start(items, funcref('s:quickfix_sink'), s:opts(title))
endfunction

function! s:location_list_source() abort
    return map(getloclist(0), 's:quickfix_format(v:val)')
endfunction

function! fzy_settings#location_list() abort
    let items = s:location_list_source()
    if empty(items)
        call s:warn('No location list items!')
        return
    endif
    let title = get(getloclist(0, { 'title': 1 }), 'title', '')
    let title = 'LocationList' . (strlen(title) ? ': ' : '') . title
    call fzy#Start(items, funcref('s:quickfix_sink'), s:opts(title))
endfunction

" ------------------------------------------------------------------
" FzyRegisters
" ------------------------------------------------------------------
function! s:registers_sink(line) abort
    call setreg('"', getreg(a:line[4]))
    echohl ModeMsg
    echo 'Yanked!'
    echohl None
endfunction

function! s:registers_source() abort
    let items = split(call('execute', ['registers']), '\n')[1:]
    call map(items, 's:trim(v:val)')
    return items
endfunction

function! fzy_settings#registers() abort
    let items = s:registers_source()
    if empty(items)
        call s:warn('No register items!')
        return
    endif
    call fzy#Start(items, funcref('s:registers_sink'), s:opts('Registers'))
endfunction

" ------------------------------------------------------------------
" FzyMessages
" ------------------------------------------------------------------
function! s:messages_sink(e) abort
    let @" = a:e
    echohl ModeMsg
    echo 'Yanked!'
    echohl None
endfunction

function! s:messages_source() abort
    return split(call('execute', ['messages']), '\n')
endfunction

function! fzy_settings#messages() abort
    let items = s:messages_source()
    if empty(items)
        call s:warn('No message items!')
        return
    endif
    call fzy#Start(items, funcref('s:messages_sink'), s:opts('Messages'))
endfunction

" ------------------------------------------------------------------
" FzyJumps
" ------------------------------------------------------------------
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

    execute 'edit ' filepath
    call cursor(linenr, column)
endfunction

function! s:jumps_source() abort
    return split(call('execute', ['jumps']), '\n')[1:]
endfunction

function! fzy_settings#jumps() abort
    let items = s:jumps_source()
    if len(items) < 2
        call s:warn('No jump items!')
        return
    endif
    call fzy#Start(items, funcref('s:jumps_sink'), s:opts('Jumps'))
endfunction
