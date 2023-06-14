if globpath(&rtp, 'plugin/fzy.vim') == ''
    echohl WarningMsg | echomsg 'vim-fzy is not found.' | echohl none
    finish
endif

if get(g:, 'loaded_fzy_settings_vim', 0)
    finish
endif

" Check if Popup/Floating Win is available for FZF or not
if has('nvim')
    let s:has_popup = exists('*nvim_win_set_config') && has('nvim-0.4.2')
else
    let s:has_popup = exists('*popup_create') && has('patch-8.2.0204')
endif

let g:fzy = {
            \ 'lines':  15,
            \ 'prompt': '>>> ',
            \ 'popupwin': get(g:, 'fzy_popup', 1) && s:has_popup ? v:true : v:false,
            \ }

let g:fzy.popup = {
            \   'padding':     [0, 1, 0, 1],
            \   'borders':     [0, 0, 0, 0],
            \   'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
            \   'minwidth':    90,
            \ }

function! s:IsUniversalCtags(ctags_path) abort
    try
        return system(printf('%s --version', a:ctags_path)) =~# 'Universal Ctags'
    catch
        return 0
    endtry
endfunction

let g:fzy_ctags        = get(g:, 'fzy_ctags', 'ctags')
let g:fzy_ctags_ignore = get(g:, 'fzy_ctags_ignore', expand('~/.ctagsignore'))

if get(g:, 'fzf_universal_ctags', s:IsUniversalCtags(g:fzy_ctags)) && filereadable(g:fzy_ctags_ignore)
    let g:fzy_tags_command = printf('%s --exclude=@%s -R', g:fzy_ctags, g:fzy_ctags_ignore)
else
    let g:fzy_tags_command = printf('%s -R', g:fzy_ctags)
endif

let g:fzy_file_root_markers = [
            \ 'Gemfile',
            \ 'rebar.config',
            \ 'mix.exs',
            \ 'Cargo.toml',
            \ 'shard.yml',
            \ 'go.mod',
            \ ]

let g:fzy_root_markers = ['.git', '.hg', '.svn', '.bzr', '_darcs'] + g:fzy_file_root_markers

let s:fzy_ignored_root_dirs = [
            \ '/',
            \ '/root',
            \ '/Users',
            \ '/home',
            \ '/usr',
            \ '/usr/local',
            \ '/opt',
            \ '/etc',
            \ '/var',
            \ expand('~'),
            \ ]

let s:fzy_ignored_root_dirs = [
            \ '/',
            \ '/root',
            \ '/Users',
            \ '/home',
            \ '/usr',
            \ '/usr/local',
            \ '/opt',
            \ '/etc',
            \ '/var',
            \ expand('~'),
            \ ]

function! s:find_project_dir(starting_dir) abort
    if empty(a:starting_dir)
        return ''
    endif

    let l:root_dir = ''

    for l:root_marker in g:fzy_root_markers
        if index(g:fzy_file_root_markers, l:root_marker) > -1
            let l:root_dir = findfile(l:root_marker, a:starting_dir . ';')
        else
            let l:root_dir = finddir(l:root_marker, a:starting_dir . ';')
        endif
        let l:root_dir = substitute(l:root_dir, l:root_marker . '$', '', '')

        if strlen(l:root_dir)
            let l:root_dir = fnamemodify(l:root_dir, ':p:h')
            break
        endif
    endfor

    if empty(l:root_dir) || index(s:ctrlp_ignored_root_dirs, l:root_dir) > -1
        if index(s:ctrlp_ignored_root_dirs, getcwd()) > -1
            let l:root_dir = a:starting_dir
        elseif stridx(a:starting_dir, getcwd()) == 0
            let l:root_dir = getcwd()
        else
            let l:root_dir = a:starting_dir
        endif
    endif

    return fnamemodify(l:root_dir, ':p:~')
endfunction

command! FzyFindRoot execute 'FzyFind' s:find_project_dir(expand('%:p:h'))

let s:fzy_available_commands = filter(['rg', 'fd'], 'executable(v:val)')

if empty(s:fzy_available_commands)
    command! -nargs=? -complete=dir FzyFindAll FzyFind <args>
endif

let g:fzy_find_tool    = get(g:, 'fzy_find_tool', 'rg')
let g:fzy_follow_links = get(g:, 'fzy_follow_links', 0)
let s:fzy_follow_links = g:fzy_follow_links
let g:fzy_no_ignores   = get(g:, 'fzy_no_ignores', 0)
let s:fzy_no_ignores   = g:fzy_no_ignores

let s:fzy_find_commands = {
            \ 'rg': 'rg --files --color never --no-ignore-vcs --ignore-dot --ignore-parent --hidden',
            \ 'fd': 'fd --type file --color never --no-ignore-vcs --hidden',
            \ }

let s:fzy_find_all_commands = {
            \ 'rg': 'rg --files --color never --no-ignore --hidden',
            \ 'fd': 'fd --type file --color never --no-ignore --hidden',
            \ }

function! s:build_fzy_find_command() abort
    let l:cmd = s:fzy_find_commands[s:fzy_current_command]
    if s:fzy_no_ignores
        let l:cmd = s:fzy_find_all_commands[s:fzy_current_command]
    endif
    if s:fzy_follow_links
        let l:cmd .= ' --follow'
    endif
    let g:fzy.findcmd = l:cmd
    return l:cmd
endfunction

function! s:detect_fzy_current_command() abort
    let idx = index(s:fzy_available_commands, g:fzy_find_tool)
    let s:fzy_current_command = get(s:fzy_available_commands, idx > -1 ? idx : 0)
endfunction

function! s:print_fzy_current_command_info() abort
    echo 'Fzy is using command `' . s:fzy_file_command . '`!'
endfunction

command! PrintFzyCurrentCommandInfo call <SID>print_fzy_current_command_info()

function! s:change_fzy_find_command(bang, command) abort
    " Reset to default command
    if a:bang
        call s:detect_fzy_current_command()
    elseif strlen(a:command)
        if index(s:fzy_available_commands, a:command) == -1
            return
        endif
        let s:fzy_current_command = a:command
    else
        let idx = index(s:fzy_available_commands, s:fzy_current_command)
        let s:fzy_current_command = get(s:fzy_available_commands, idx + 1, s:fzy_available_commands[0])
    endif
    call s:build_fzy_find_command()
    call s:print_fzy_current_command_info()
endfunction

function! s:list_fzy_available_commands(...) abort
    return s:fzy_available_commands
endfunction

command! -nargs=? -bang -complete=customlist,<SID>list_fzy_available_commands ChangeFzyFindCommand call <SID>change_fzy_find_command(<bang>0, <q-args>)

function! s:toggle_fzy_follow_links() abort
    if s:fzy_follow_links == 0
        let s:fzy_follow_links = 1
        echo 'Fzy follows symlinks!'
    else
        let s:fzy_follow_links = 0
        echo 'Fzy does not follow symlinks!'
    endif
    call s:build_fzy_find_command()
endfunction

command! ToggleFzyFollowLinks call <SID>toggle_fzy_follow_links()

function! s:toggle_fzy_no_ignores() abort
    if s:fzy_no_ignores == 0
        let s:fzy_no_ignores = 1
        echo 'Fzy does not respect ignores!'
    else
        let s:fzy_no_ignores = 0
        echo 'Fzy respects ignore!'
    endif
    call s:build_fzy_find_command()
endfunction

command! ToggleFzyNoIgnores call <SID>toggle_fzy_no_ignores()

function! s:fzy_find_all(dir) abort
    let current = s:fzy_no_ignores
    try
        let s:fzy_no_ignores = 1
        call s:build_fzy_find_command()
        execute 'FzyFind' a:dir
    finally
        let s:fzy_no_ignores = current
        call s:build_fzy_find_command()
    endtry
endfunction

command! -nargs=? -complete=dir FzyFindAll call <SID>fzy_find_all(<q-args>)

call s:detect_fzy_current_command()
call s:build_fzy_find_command()

" Extra commands

function! s:opts(title, space = 0) abort
    let opts = get(g:, 'fzy', {})->copy()->extend({'statusline': a:title})
    call get(opts, 'popup', {})->extend({'title': a:space ? ' ' .. a:title : a:title})
    return opts
endfunction

function! s:find_cb(dir, vim_cmd, choice) abort
    let fpath = fnamemodify(a:dir, ':p:s?/$??') .. '/' .. a:choice
    let fpath = resolve(fpath)->fnamemodify(':.')->fnameescape()
    call histadd('cmd', a:vim_cmd .. ' ' .. fpath)
    call s:tryexe(a:vim_cmd .. ' ' .. fpath)
endfunction

function! s:open_file_cb(vim_cmd, choice) abort
    const fname = fnameescape(a:choice)
    call histadd('cmd', a:vim_cmd .. ' ' .. fname)
    call s:tryexe(a:vim_cmd .. ' ' .. fname)
endfunction

function! s:open_tag_cb(vim_cmd, choice) abort
    call histadd('cmd', a:vim_cmd .. ' ' .. a:choice)
    call s:tryexe(a:vim_cmd .. ' ' .. escape(a:choice, '"'))
endfunction

function! s:fzy_opts(opts) abort
    let l:opts = extend({}, s:opts(''))
    let l:opts = extend(l:opts, a:opts)
    return l:opts
endfunction

function! s:warn(message) abort
    echohl WarningMsg
    echomsg a:message
    echohl None
    return 0
endfunction

function! s:fzy_bufopen(e) abort
    let list = split(a:e)
    if len(list) < 4
        return
    endif

    let [linenr, col, file_text] = [list[1], list[2]+1, join(list[3:])]
    let lines = getbufline(file_text, linenr)
    let path = file_text
    if empty(lines)
        if stridx(join(split(getline(linenr))), file_text) == 0
            let lines = [file_text]
            let path = bufname('%')
        elseif filereadable(path)
            let lines = ['buffer unloaded']
        else
            " Skip.
            return
        endif
    endif

    execute 'edit '  . path
    call cursor(linenr, col)
endfunction

function! s:no_highlight(text) abort
    return "\x1b[m" . a:text
endfunction

function! s:buffer_line_handler(line) abort
  normal! m'
  execute split(a:line, '\t')[0]
  normal! ^zvzz
endfunction

function! s:buffer_lines() abort
    let linefmt = " %4d " . "\t%s"
    let fmtexpr = 'printf(linefmt, v:key + 1, s:no_highlight(v:val))'
    let lines = getline(1, '$')
    return map(lines, fmtexpr)
endfunction

function! s:fzy_buf_lines() abort
    call fzy#start(<SID>buffer_lines(), funcref('s:buffer_line_handler'), s:fzy_opts({ 'prompt': 'BufLines> ' }))
endfunction

command! FzyBufLines call <SID>fzy_buf_lines()

function! s:fzy_jumplist() abort
    return split(call('execute', ['jumps']), '\n')[1:]
endfunction

function! s:fzy_jumps() abort
    call fzy#start(<SID>fzy_jumplist(), funcref('s:fzy_bufopen'), s:fzy_opts({ 'prompt': 'Jumps> ' }))
endfunction

command! FzyJumps call <SID>fzy_jumps()

function! s:fzy_yank_sink(e) abort
    let @" = a:e
    echohl ModeMsg
    echo 'Yanked!'
    echohl None
endfunction

function! s:fzy_messages_source() abort
    return split(call('execute', ['messages']), '\n')
endfunction

function! s:fzy_messages() abort
    call fzy#start(<SID>fzy_messages_source(), funcref('s:fzy_yank_sink'), s:fzy_opts({ 'prompt': 'Messages> ' }))
endfunction

command! FzyMessages call <SID>fzy_messages()

function! s:fzy_open_quickfix_item(e) abort
    let line = a:e
    let filename = fnameescape(split(line, ':\d\+:')[0])
    let linenr = matchstr(line, ':\d\+:')[1:-2]
    let colum = matchstr(line, '\(:\d\+\)\@<=:\d\+:')[1:-2]
    execute 'e ' . filename
    call cursor(linenr, colum)
endfunction

function! s:fzy_quickfix_to_grep(v) abort
    return bufname(a:v.bufnr) . ':' . a:v.lnum . ':' . a:v.col . ':' . a:v.text
endfunction

function! s:fzy_get_quickfix() abort
    return map(getqflist(), 's:fzy_quickfix_to_grep(v:val)')
endfunction

function! s:fzy_quickfix() abort
    let s:source = 'quickfix'
    let items = <SID>fzy_get_quickfix()
    if len(items) == 0
        call s:warn('No quickfix items!')
        return
    endif
    call fzy#start(items, funcref('s:fzy_open_quickfix_item'), s:fzy_opts({ 'prompt': 'Quickfix> ' }))
endfunction

function! s:fzy_get_location_list() abort
    return map(getloclist(0), 's:fzy_quickfix_to_grep(v:val)')
endfunction

function! s:fzy_location_list() abort
    let s:source = 'location_list'
    let items = <sid>fzy_get_location_list()
    if len(items) == 0
        call s:warn('No location list items!')
        return
    endif
    call fzy#start(items, funcref('s:fzy_open_quickfix_item'), s:fzy_opts({ 'prompt': 'LocationList> ' }))
endfunction

command! FzyQuickfix call s:fzy_quickfix()
command! FzyLocationList call s:fzy_location_list()

function! s:fzy_yank_register(line) abort
    call setreg('"', getreg(a:line[4]))
    echohl ModeMsg
    echo 'Yanked!'
    echohl None
endfunction

function! s:fzy_get_registers() abort
    let l:items = split(call('execute', ['registers']), '\n')[1:]
    call map(l:items, 's:strip(v:val)')
    return l:items
endfunction

function! s:fzy_registers() abort
    let items = <SID>fzy_get_registers()
    if len(items) == 0
        call s:warn('No register items!')
        return
    endif
    call fzy#start(items, funcref('s:fzy_yank_register'), s:fzy_opts({ 'prompt': 'Registers> ' }))
endfunction

command! FzyRegisters call s:fzy_registers()

if exists('*trim')
    function! s:strip(str) abort
        return trim(a:str)
    endfunction
else
    function! s:strip(str) abort
        return substitute(a:str, '^\s*\(.\{-}\)\s*$', '\1', '')
    endfunction
endif

command! FzyOutline call fzy_settings#outline()

let g:loaded_fzy_settings_vim = 1
