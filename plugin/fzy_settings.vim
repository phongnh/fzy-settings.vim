if globpath(&rtp, 'plugin/fzy.vim') == ''
    echohl WarningMsg | echomsg 'vim-fzy is not found.' | echohl none
    finish
endif

if get(g:, 'loaded_fzy_settings_vim', 0)
    finish
endif

let g:fzy_symbols = {
            \ 'nbs': nr2char(0xa0),
            \ 'tab': repeat(nr2char(0xa0), 4),
            \ }

let g:fzy = {
            \ 'prompt': '> ',
            \ 'histadd': v:false,
            \ 'showinfo': v:true,
            \ 'term_highlight': 'NormalDark',
            \ 'popup': {
            \   'minwidth': 120,
            \   'highlight': 'NormalDark',
            \   'borderhighlight': ['GreyDark'],
            \   'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
            \ },
            \ }

if exists('g:fzy_exe') && executable(g:fzy_exe)
    let g:fzy.exe = g:fzy_exe
endif

if get(g:, 'fzy_popup', 'default') ==# 'round'
    let g:fzy.popup.borderchars = ['─', '│', '─', '│', '╭', '╮', '╯', '╰']
endif

" Check if Popup/Floating Win is available
if (has('nvim') && exists('*nvim_open_win') && has('nvim-0.4.2')) ||
            \ (exists('*popup_create') && has('patch-8.2.191'))
    let g:fzy_popup = v:true
else
    let g:fzy_popup = v:false
endif

let g:fzy_find_tool          = get(g:, 'fzy_find_tool', 'fd')
let g:fzy_find_no_ignore_vcs = get(g:, 'fzy_find_no_ignore_vcs', 0)
let g:fzy_follow_links       = get(g:, 'fzy_follow_links', 1)
let g:fzy_grep_no_ignore_vcs = get(g:, 'fzy_grep_no_ignore_vcs', 0)

let g:fzy_ctags_bin    = get(g:, 'fzy_ctags_bin', 'ctags')
let g:fzy_ctags_ignore = get(g:, 'fzy_ctags_ignore', expand('~/.ctagsignore'))

if get(g:, 'fzy_universal_ctags', fzy_settings#IsUniversalCtags(g:fzy_ctags_bin)) && filereadable(g:fzy_ctags_ignore)
    let g:fzy_tags_command = printf('%s --exclude=@%s -R', g:fzy_ctags_bin, g:fzy_ctags_ignore)
else
    let g:fzy_tags_command = printf('%s -R', g:fzy_ctags_bin)
endif

function! s:BuildFindCommand() abort
    let find_commands = {
                \ 'fd': 'fd --type file --color never --hidden',
                \ 'rg': 'rg --files --color never --ignore-dot --ignore-parent --hidden',
                \ }

    if g:fzy_find_tool ==# 'rg' && executable('rg')
        let g:fzy_find_command = find_commands['rg']
    else
        let g:fzy_find_tool = 'fd'
        let g:fzy_find_command = find_commands['fd']
    endif

    let g:fzy_find_command .= (g:fzy_follow_links ? ' --follow' : '')
    let g:fzy_find_command .= (g:fzy_find_no_ignore_vcs ? ' --no-ignore-vcs' : '')

    call extend(g:fzy, { 'findcmd': g:fzy_find_command })
endfunction

function! s:BuildFindAllCommand() abort
    let find_all_commands = {
                \ 'fd': 'fd --type file --color never --no-ignore --exclude .git --hidden --follow',
                \ 'rg': 'rg --files --color never --no-ignore --exclude .git --hidden --follow',
                \ }

    if g:fzy_find_tool ==# 'rg' && executable('rg')
        let g:fzy_find_all_command = find_all_commands['rg']
    else
        let g:fzy_find_all_command = find_all_commands['fd']
    endif

    call extend(g:fzy, { 'findcmd': g:fzy_find_all_command })
endfunction

function! s:BuildGrepCommand() abort
    let g:fzy_grep_command = 'rg --color=never -H --no-heading --line-number --smart-case --hidden'
    let g:fzy_grep_command .= g:fzy_follow_links ? ' --follow' : ''
    let g:fzy_grep_command .= g:fzy_grep_no_ignore_vcs ? ' --no-ignore-vcs' : ''
    call extend(g:fzy, { 'grepcmd': g:fzy_grep_command, 'grepformat': '%f:%l:%m' })
endfunction

function! s:SetupFzySettings() abort
    call s:BuildFindAllCommand()
    call s:BuildFindCommand()
    call s:BuildGrepCommand()
    call s:UpdatePopupSettings()
endfunction

function! s:UpdatePopupSettings() abort
    let l:popupwin = g:fzy_popup && &columns >= 120 ? v:true : v:false
    call extend(g:fzy, {
                \ 'lines': l:popupwin ? float2nr(&lines * 0.85 / 2) : 12,
                \ 'popupwin': l:popupwin,
                \ })
    call extend(g:fzy.popup, {
                \ 'minwidth': max([float2nr(&columns * 0.70), 150]),
                \ 'minheight': float2nr(&lines * 0.85),
                \ })
endfunction

augroup FzySettings
    autocmd!
    autocmd VimEnter * call <SID>SetupFzySettings()
    autocmd VimResized * call <SID>UpdatePopupSettings()
augroup END

function! s:ToggleFzyFollowLinks() abort
    if g:fzy_follow_links == 0
        let g:fzy_follow_links = 1
        echo 'Fzy follows symlinks!'
    else
        let g:fzy_follow_links = 0
        echo 'Fzy does not follow symlinks!'
    endif
    call s:BuildFindCommand()
    call s:BuildGrepCommand()
endfunction

command! ToggleFzyFollowLinks call <SID>ToggleFzyFollowLinks()

command! -nargs=? -complete=dir FzyFiles         call fzy_settings#files#run({ 'dir': empty(<q-args>) ? getcwd() : <q-args> })
command! -nargs=? -complete=dir FzyAllFiles      call fzy_settings#files#all({ 'dir': empty(<q-args>) ? getcwd() : <q-args> })
command! -nargs=? -complete=dir FzyFilesSplit    call fzy_settings#files#run({ 'dir': empty(<q-args>) ? getcwd() : <q-args>, 'editcmd': 'split', 'mods': <q-mods> })
command! -nargs=? -complete=dir FzyAllFilesSplit call fzy_settings#files#all({ 'dir': empty(<q-args>) ? getcwd() : <q-args>, 'editcmd': 'split', 'mods': <q-mods> })

command!       FzyMru            call fzy_settings#mru#run()
command!       FzyMruCwd         call fzy_settings#mru#run_in_cwd()
command!       FzyMruInCwd       call fzy_settings#mru#run_in_cwd()
command!       FzyBLines         call fzy_settings#blines#run()
command!       FzyBTags          call fzy_settings#btags#run()
command!       FzyBOutline       call fzy_settings#boutline#run()
command!       FzyQuickfix       call fzy_settings#quickfix#run()
command!       FzyLocationList   call fzy_settings#quickfix#loclist()
command!       FzyCommands       call fzy_settings#commands#run()
command! -bang FzyCommandHistory call fzy_settings#history#command(<bang>)
command! -bang FzySearchHistory  call fzy_settings#history#search(<bang>)
command!       FzyRegisters      call fzy_settings#registers#run()
command!       FzyMessages       call fzy_settings#messages#run()
command!       FzyJumps          call fzy_settings#jumps#run()

let g:loaded_fzy_settings_vim = 1
