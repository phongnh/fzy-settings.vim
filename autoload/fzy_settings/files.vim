function! s:open_file_sink(dir, vim_cmd, choice) abort
    let fpath = fnamemodify(a:dir, ':p:s?/$??') . '/' . a:choice
    let fpath = fpath->resolve()->fnamemodify(':.')->fnameescape()
    call fzy_settings#TryExe(printf('%s %s', a:vim_cmd, fpath))
endfunction

function! s:opts(opts) abort
    let l:opts = extend({ 'dir': getcwd(), 'findcmd': g:fzy_find_command, 'editcmd': 'edit', 'mods': '' }, a:opts)
    let l:opts.dir = empty(l:opts.dir) ? getcwd() : l:opts.dir
    let l:opts.path = l:opts.dir->expand(v:true)->fnamemodify(':~')->simplify()
    let l:opts.filecmd = printf('cd %s ; %s', l:opts.path->expand(v:true)->shellescape(), l:opts.findcmd)
    let l:opts.opencmd = empty(l:opts.mods) ? l:opts.editcmd : (l:opts.mods . ' ' . l:opts.editcmd)
    let l:opts.stl = printf(':%s [directory: %s]', l:opts.opencmd, l:opts.path)
    return l:opts
endfunction

function! fzy_settings#files#run(...) abort
    let l:opts = s:opts(get(a:, 1, {}))
    call fzy#Start(l:opts.filecmd, funcref('s:open_file_sink', [l:opts.path, l:opts.opencmd]), fzy_settings#FzyOpts(l:opts.stl))
endfunction

function! fzy_settings#files#all(...) abort
    let l:opts = extend(get(a:, 1, {}), { 'findcmd': g:fzy_find_all_command })
    call fzy_settings#files#run(l:opts)
endfunction
