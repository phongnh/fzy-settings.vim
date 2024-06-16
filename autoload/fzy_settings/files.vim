function! s:open_file_sink(dir, vim_cmd, choice) abort
    let fpath = fnamemodify(a:dir, ':p:s?/$??') . '/' . a:choice
    let fpath = fpath->resolve()->fnamemodify(':.')->fnameescape()
    call fzy_settings#TryExe(printf('%s %s', a:vim_cmd, fpath))
endfunction

function! fzy_settings#files#run(...) abort
    let dir = get(a:, 1, getcwd())
    let vim_cmd = get(a:, 2, 'edit')
    let mods = get(a:, 3, '')
    let dir = empty(dir) ? getcwd() : dir
    let path = dir->expand(v:true)->fnamemodify(':~')->simplify()
    let cmd = printf('cd %s ; %s', path->expand(v:true)->shellescape(), g:fzy_find_command)
    let editcmd = empty(mods) ? vim_cmd : (mods . ' ' . vim_cmd)
    let stl = printf(':%s [directory: %s]', editcmd, path)
    call fzy#Start(cmd, funcref('s:open_file_sink', [path, editcmd]), fzy_settings#FzyOpts(stl))
endfunction

function! fzy_settings#files#all(...) abort
    let dir = get(a:, 1, getcwd())
    let vim_cmd = get(a:, 2, 'edit')
    let mods = get(a:, 3, '')
    let dir = empty(dir) ? getcwd() : dir
    let path = dir->expand(v:true)->fnamemodify(':~')->simplify()
    let cmd = printf('cd %s ; %s', path->expand(v:true)->shellescape(), g:fzy_find_all_command)
    let editcmd = empty(mods) ? vim_cmd : (mods . ' ' . vim_cmd)
    let stl = printf(':%s [directory: %s]', editcmd, path)
    call fzy#Start(cmd, funcref('s:open_file_sink', [path, editcmd]), fzy_settings#FzyOpts(stl))
endfunction
