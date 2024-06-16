" columns: tag | filename | linenr | kind | ref
function! s:btags_format(line) abort
    let columns = split(a:line, "\t")
    let format = '%' . len(string(line('$'))) . 's'
    let linenr = columns[2][:len(columns[2])-3]
    if len(columns) > 4
        return extend([printf(format, linenr)], [columns[0], columns[-2], columns[-1]])
    else
        return extend([printf(format, linenr)], [columns[0], columns[-1]])
    endif
endfunction

function! s:btags_source(tag_cmds) abort
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

    return map(fzy_settings#AlignLists(map(lines, 's:btags_format(v:val)')), 'join(v:val, g:fzy_symbols.tab)')
endfunction

function! s:btags_sink(path, editcmd, line) abort
    let linenr = fzy_settings#Trim(split(a:line, g:fzy_symbols.tab)[0])
    execute printf("%s +%s %s", a:editcmd, linenr, a:path)
endfunction

function! s:btags_commands() abort
    let language = get({ 'cpp': 'c++' }, &filetype, &filetype)
    let filename = expand('%:S')
    let null = has('win32') || has('win64') ? 'nul' : '/dev/null'
    let sort = executable('sort') ? '| sort -s -k 5' : ''
    let ctags_options = '-f - --sort=no --excmd=number' . get({ 'ruby': ' --kinds-ruby=-r' }, language, '')
    return [
                \ printf('%s %s --language-force=%s %s 2> %s %s', g:fzy_ctags_bin, ctags_options, language, filename, null, sort),
                \ printf('%s %s %s 2> %s %s', g:fzy_ctags_bin, ctags_options, filename, null, sort),
                \ ]
endfunction

function! fzy_settings#btags#run() abort
    try
        let tag_cmds = s:btags_commands()
        call fzy#Start(s:btags_source(tag_cmds), funcref('s:btags_sink', [expand('%:p'), 'silent edit']), fzy_settings#FzyOpts(' BufTag: ' . expand('%') . ' '))
    catch
        call fzy_settings#Warn(v:exception)
    endtry
endfunction
