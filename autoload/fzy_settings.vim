" https://stackoverflow.com/questions/4842424/list-of-ansi-color-escape-sequences
let s:codes = {
            \ 'reset': "\x1b[0m",
            \ 'blue':  "\x1b[34m",
            \ }

let s:nbs = nr2char(0xa0)
let s:tab = repeat(s:nbs, 4)

function! s:warn(message) abort
    echohl WarningMsg
    echomsg a:message
    echohl None
    return 0
endfunction

function! s:blue(text) abort
    return printf('%s%s%s', "\x1b[38;5;4m", a:text, "\x1b[39m")
endfunction

function! s:clear_escape_sequence(text)
    let text = substitute(a:text, "\x1b[38;5;4m", '', '')
    let text = substitute(text, "\x1b[39m", '', '')
    return text
endfunction

function! s:tryexe(cmd)
    try
        execute a:cmd
    catch
        echohl ErrorMsg
        echomsg matchstr(v:exception, '^Vim\%((\a\+)\)\=:\zs.*')
        echohl None
    endtry
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
" FzyMru
" FzyMruInCwd
" ------------------------------------------------------------------
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

function! s:buflisted()
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
    call s:tryexe(printf('%s %s', a:editcmd, fname))
endfunction

function! fzy_settings#mru() abort
    let items = s:vim_recent_files()
    if empty(items)
        call s:warn('No MRU items!')
        return
    endif
    call fzy#Start(items, funcref('s:mru_sink', ['edit']), s:opts('MRU'))
endfunction

function! fzy_settings#mru_in_cwd() abort
    let items = s:vim_recent_files_in_cwd()
    if empty(items)
        call s:warn('No MRU items!')
        return
    endif
    call fzy#Start(items, funcref('s:mru_sink', ['edit']), s:opts(printf('MRU [directory: %s]', getcwd())))
endfunction

" ------------------------------------------------------------------
" FzyBufferLines
" ------------------------------------------------------------------
function! s:buffer_lines_sink(line) abort
  normal! m'
  execute split(a:line, s:tab)[0]
  normal! ^zvzz
endfunction

function! s:buffer_lines_source() abort
    let linefmt = '%' . len(string(line('$'))) . 'd'
    let format = linefmt . s:tab . '%s'
    return map(getline(1, '$'), 'printf(format, v:key + 1, v:val)')
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
" FzyCommands
" ------------------------------------------------------------------
function! s:commands_format(line) abort
    let attr = a:line[0:3]
    let [name; line] = split(a:line[4:], ' ')
    let line = s:trim(join(line, ' '))
    let args = s:trim(line[0:3])
    " let address = line[5:11]
    " let complete = line[13:22]
    let definition = s:trim(line[25:])
    let result = [
                \ attr . s:blue(name),
                \ s:trim(args),
                \ s:trim(definition),
                \ ]
    return result
endfunction

function! s:commands_source() abort
    let items = split(call('execute', ['command']), '\n')[1:]
    return map(s:align_lists(map(items, 's:commands_format(v:val)')), 'join(v:val, " ")')
endfunction

function! s:commands_sink(line) abort
    let line = s:clear_escape_sequence(a:line)
    let cmd = matchstr(line[4:], '\zs\S*\ze')
    call feedkeys(':' . cmd . (a:line[0] == '!' ? '' : ' '), 'n')
endfunction

function! fzy_settings#commands() abort
    let items = s:commands_source()
    if empty(items)
        call s:warn('No command items!')
        return
    endif
    call fzy#Start(items, funcref('s:commands_sink'), s:opts('Commands'))
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
