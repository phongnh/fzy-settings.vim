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
        call fzy_settings#Warn('No lines!')
        return
    endif
    call fzy#Start(items, funcref('s:buffer_lines_sink'), s:opts('BufLines: ' . expand('%')))
endfunction

" ------------------------------------------------------------------
" FzyBufferTag
" ------------------------------------------------------------------
" columns: tag | filename | linenr | kind | ref
function! s:buffer_tag_format(line) abort
    let columns = split(a:line, "\t")
    let format = '%' . len(string(line('$'))) . 's'
    let linenr = columns[2][:len(columns[2])-3]
    if len(columns) > 4
        return extend([printf(format, linenr)], [columns[0], columns[-2], columns[-1]])
    else
        return extend([printf(format, linenr)], [columns[0], columns[-1]])
    endif
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
    return map(fzy_settings#AlignLists(map(lines, 's:buffer_tag_format(v:val)')), 'join(v:val, s:tab)')
endfunction

function! s:buffer_tag_sink(path, editcmd, line) abort
    let linenr = fzy_settings#Trim(split(a:line, s:tab)[0])
    execute printf("%s +%s %s", a:editcmd, linenr, a:path)
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
        call fzy_settings#Warn(v:exception)
    endtry
endfunction

" ------------------------------------------------------------------
" FzyOutline
" ------------------------------------------------------------------
" columns: tag | filename | linenr | kind | ref
function! s:outline_format(line) abort
    let columns = split(a:line, "\t")
    let format = '%' . len(string(line('$'))) . 's'
    let linenr = columns[2][0:len(columns[2])-3]
    let line = fzy_settings#Trim(getline(linenr))
    return join([printf(format, linenr), line], s:tab)
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
    return map(lines, 's:outline_format(v:val)')
endfunction

function! s:outline_sink(path, editcmd, line) abort
    let linenr = fzy_settings#Trim(split(a:line, s:tab)[0])
    execute printf("%s +%s %s", a:editcmd, linenr, a:path)
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
        call fzy_settings#Warn(v:exception)
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
        call fzy_settings#Warn('No quickfix items!')
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
        call fzy_settings#Warn('No location list items!')
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
    call map(items, 'fzy_settings#Trim(v:val)')
    return items
endfunction

function! fzy_settings#registers() abort
    let items = s:registers_source()
    if empty(items)
        call fzy_settings#Warn('No register items!')
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
        call fzy_settings#Warn('No message items!')
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
        call fzy_settings#Warn('No jump items!')
        return
    endif
    call fzy#Start(items, funcref('s:jumps_sink'), s:opts('Jumps'))
endfunction
