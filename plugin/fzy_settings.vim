if globpath(&rtp, 'plugin/fzy.vim') == ''
    echohl WarningMsg | echomsg 'vim-fzy is not found.' | echohl none
    finish
endif

if get(g:, 'loaded_fzy_settings_vim', 0)
    finish
endif

let g:fzy = {
            \ 'prompt': '> ',
            \ 'showinfo': v:true,
            \ 'term_highlight': 'NormalDark',
            \ 'popup': {
            \   'minwidth': 120,
            \   'highlight': 'NormalDark',
            \   'borderhighlight': ['GreyDark'],
            \   'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
            \ },
            \ 'disable_cmd_history': v:true,
            \ }

if exists('g:fzy_exe') && !empty(g:fzy_exe)
    let g:fzy.exe = g:fzy_exe
endif

if get(g:, 'fzy_popup_borderchars', 'default') ==# 'round'
    let g:fzy.popup.borderchars = ['─', '│', '─', '│', '╭', '╮', '╯', '╰']
endif

let g:fzy_find_tool    = get(g:, 'fzy_find_tool', 'fd')
let g:fzy_follow_links = get(g:, 'fzy_follow_links', 0)

" Check if Popup/Floating Win is available
if (has('nvim') && exists('*nvim_open_win') && has('nvim-0.4.2')) ||
            \ (exists('*popup_create') && has('patch-8.2.191'))
    let g:fzy_popup = v:true
else
    let g:fzy_popup = v:false
endif

let g:fzy_ctags        = get(g:, 'fzy_ctags', 'ctags')
let g:fzy_ctags_ignore = get(g:, 'fzy_ctags_ignore', expand('~/.ctagsignore'))

function! s:is_universal_ctags(ctags_path) abort
    try
        return system(printf('%s --version', a:ctags_path)) =~# 'Universal Ctags'
    catch
        return 0
    endtry
endfunction

if get(g:, 'fzy_universal_ctags', s:is_universal_ctags(g:fzy_ctags)) && filereadable(g:fzy_ctags_ignore)
    let g:fzy_tags_command = printf('%s --exclude=@%s -R', g:fzy_ctags, g:fzy_ctags_ignore)
else
    let g:fzy_tags_command = printf('%s -R', g:fzy_ctags)
endif

function! s:build_find_command() abort
    let find_commands = {
                \ 'fd': 'fd --type file --color never --no-ignore-vcs --hidden --strip-cwd-prefix',
                \ 'rg': 'rg --files --color never --no-ignore-vcs --ignore-dot --ignore-parent --hidden',
                \ }

    if g:fzy_follow_links
        call map(find_commands, 'v:val . " --follow"')
    endif

    if g:fzy_find_tool ==# 'rg' && executable('rg')
        let g:fzy_find_command = find_commands['rg']
    else
        let g:fzy_find_tool = 'fd'
        let g:fzy_find_command = find_commands['fd']
    endif

    call extend(g:fzy, { 'findcmd': g:fzy_find_command })
endfunction

function! s:build_find_all_command() abort
    let find_all_commands = {
                \ 'fd': 'fd --type file --color never --no-ignore --hidden --follow --strip-cwd-prefix',
                \ 'rg': 'rg --files --color never --no-ignore --hidden --follow',
                \ }

    if g:fzy_find_tool ==# 'rg' && executable('rg')
        let g:fzy_find_all_command = find_all_commands['rg']
    else
        let g:fzy_find_tool = 'fd'
        let g:fzy_find_all_command = find_all_commands['fd']
    endif

    call extend(g:fzy, { 'findcmd': g:fzy_find_all_command })
endfunction

function! s:build_grep_command() abort
    let g:fzy_grep_command = 'rg --color=never -H --no-heading --line-number --smart-case --hidden'
    let g:fzy_grep_command .= g:fzy_follow_links ? ' --follow' : ''
    let g:fzy_grep_command .= get(g:, 'fzy_grep_ignore_vcs', 0) ? ' --no-ignore-vcs' : ''
    call extend(g:fzy, { 'grepcmd': g:fzy_grep_command, 'grepformat': '%f:%l:%m' })
endfunction

function! s:toggle_fzy_follow_links() abort
    if g:fzy_follow_links == 0
        let g:fzy_follow_links = 1
        echo 'Fzy follows symlinks!'
    else
        let g:fzy_follow_links = 0
        echo 'Fzy does not follow symlinks!'
    endif
    call s:build_find_command()
    call s:build_grep_command()
endfunction

command! -nargs=? -complete=dir FzyFindAll call fzy_settings#find_all(<q-args>)

command! ToggleFzyFollowLinks call <SID>toggle_fzy_follow_links()

command! FzyMru                call fzy_settings#mru()
command! FzyMruInCwd           call fzy_settings#mru_in_cwd()
command! FzyBufferLines        call fzy_settings#buffer_lines()
command! FzyBufferTag          call fzy_settings#buffer_tag()
command! FzyOutline            call fzy_settings#outline()
command! FzyQuickfix           call fzy_settings#quickfix()
command! FzyLocationList       call fzy_settings#location_list()
command! FzyCommands           call fzy_settings#commands()
command! FzyCommandHistory     call fzy_settings#command_history()
command! FzySearchHistory      call fzy_settings#search_history()
command! FzyCommandHistoryEdit call fzy_settings#command_history_edit()
command! FzySearchHistoryEdit  call fzy_settings#search_history_edit()
command! FzyRegisters          call fzy_settings#registers()
command! FzyMessages           call fzy_settings#messages()
command! FzyJumps              call fzy_settings#jumps()

function! s:setup_fzy_settings() abort
    call s:build_find_all_command()
    call s:build_find_command()
    call s:build_grep_command()
    call s:update_popup_settings()
endfunction

function! s:update_popup_settings()
    let l:popupwin = g:fzy_popup && winwidth(0) >= 120 ? v:true : v:false
    let l:lines = l:popupwin ? (&lines >= 20 ? float2nr(&lines * 0.85 / 2) + 3 : min([&lines - 3, 12])) : 10
    call extend(g:fzy, {
                \ 'lines': l:lines,
                \ 'popupwin': l:popupwin,
                \ })
endfunction

augroup FzySettings
    autocmd!
    autocmd VimEnter * call <SID>setup_fzy_settings()
    autocmd VimResized * call <SID>update_popup_settings()
augroup END

let g:loaded_fzy_settings_vim = 1
