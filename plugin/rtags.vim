if has('nvim') || (has('job') && has('channel'))
    let s:rtagsAsync = 1
    let s:job_cid = 0
    let s:jobs = {}
    let s:job_args = {}
    let s:result_stdout = {}
    let s:result_handlers = {}
else
    let s:rtagsAsync = 0
endif

if has('python3')
    let g:rtagsPy = 'python3'
elseif has('python')
    let g:rtagsPy = 'python'
else
    echohl DiffDelete | echomsg "[vim-rtags] Vim is missing python(3) support" | echohl None
    finish
end

" DEBUG job/channel override
"let s:rtagsAsync = 0

set mfd=5000

if !exists("g:rtagsRcCmd")
    let g:rtagsRcCmd = "rc"
endif

if !exists("g:rtagsRdmCmd")
    let g:rtagsRdmCmd = "rdm"
endif

if !exists("g:rtagsAutoLaunchRdm")
    let g:rtagsAutoLaunchRdm = 0
endif

let g:rtagsJumpStack = []
if !exists("g:rtagsJumpStackMaxSize")
    let g:rtagsJumpStackMaxSize = 100
endif

if !exists("g:rtagsExcludeSysHeaders")
    let g:rtagsExcludeSysHeaders = 0
endif

if !exists("g:rtagsUseLocationList")
    let g:rtagsUseLocationList = 1
endif

if !exists("g:rtagsUseDefaultMappings")
    let g:rtagsUseDefaultMappings = 1
endif

if !exists("g:rtagsMinCharsForCommandCompletion")
    let g:rtagsMinCharsForCommandCompletion = 4
endif

if !exists("g:rtagsMaxSearchResultWindowHeight")
    let g:rtagsMaxSearchResultWindowHeight = 10
endif

if !exists("g:rtagsAutoReindexOnWrite")
    let g:rtagsAutoReindexOnWrite = 0
endif

if !exists("g:rtagsUseColonKeyword")
    let g:rtagsUseColonKeyword = 0
endif

if g:rtagsAutoLaunchRdm
    "silent call system(g:rtagsRcCmd." -w")
    "if v:shell_error != 0
    "    silent call system(g:rtagsRdmCmd." --tempdir /tmp/rdm-".$USER." --log-file /tmp/rdm-".$USER.".log --daemon")
    "end
    " much faster method on wsl, should probably only check when first rc command is issued
    if executable("pgrep") && executable(g:rtagsRdmCmd)
        let chkcmd = 'pgrep --exact ' . g:rtagsRdmCmd
        let chkpid = system(chkcmd)
        if empty(chkpid)
            silent call system("setsid " . g:rtagsRdmCmd . " --tempdir /tmp/rdm-".$USER." --log-file /tmp/rdm-".$USER.".log --daemon")
        endif
    endif
end

let g:SAME_WINDOW = 'same_window'
let g:H_SPLIT = 'hsplit'
let g:V_SPLIT = 'vsplit'
let g:NEW_TAB = 'tab'
let g:NEW_TAB_IF_DIFF_FILE = 'new_tab_if_diff_file'

let s:LOC_OPEN_OPTS = {
            \ g:SAME_WINDOW : '',
            \ g:H_SPLIT : ' ',
            \ g:V_SPLIT : 'vert',
            \ g:NEW_TAB : 'tab',
            \ g:NEW_TAB_IF_DIFF_FILE : 'tab'
            \ }

if g:rtagsUseDefaultMappings == 1
    nmap <Leader>rs <C-\><C-n>:<C-u>call rtags#SymbolInfo()<CR>

    nmap <Leader>ro <C-\><C-n>:<C-u>call rtags#Diagnostics()<CR>

    nmap <Leader>rj <C-\><C-n>:<C-u>call rtags#JumpTo(g:SAME_WINDOW)<CR>
    nmap <Leader>rd <C-\><C-n>:<C-u>call rtags#JumpTo(g:SAME_WINDOW)<CR>

    nmap <Leader>rJ <C-\><C-n>:<C-u>call rtags#JumpTo(g:SAME_WINDOW, { '--declaration-only' : '' })<CR>
    nmap <Leader>rD <C-\><C-n>:<C-u>call rtags#JumpTo(g:SAME_WINDOW, { '--declaration-only' : '' })<CR>

    nmap <Leader>rf <C-\><C-n>:<C-u>call rtags#FindRefs()<CR>
    nmap <Leader>rF <C-\><C-n>:<C-u>call rtags#FindRefsCallTree()<CR>

    nmap <Leader>rv <C-\><C-n>:<C-u>call rtags#FindVirtuals()<CR>
    nmap <Leader>ri <C-\><C-n>:<C-u>call rtags#FindVirtuals()<CR>

    "nmap <Leader>rS <C-\><C-n>:<C-u>call rtags#JumpTo(g:H_SPLIT)<CR>
    nmap <Leader>rV <C-\><C-n>:<C-u>call rtags#JumpTo(g:V_SPLIT)<CR>
    " mck - add rH for Horizontal split
    nmap <Leader>rH <C-\><C-n>:<C-u>call rtags#JumpTo(g:H_SPLIT)<CR>
    " mck - really a tab split if same file
    nmap <Leader>rX <C-\><C-n>:<C-u>call rtags#JumpTo(g:NEW_TAB)<CR>
    " mck - to match tmux ...
    nmap <Leader>r\| <C-\><C-n>:<C-u>call rtags#JumpTo(g:V_SPLIT)<CR>
    nmap <Leader>r_  <C-\><C-n>:<C-u>call rtags#JumpTo(g:H_SPLIT)<CR>
    " mck - add rt for new tab if diff file
    nmap <Leader>r<Tab> <C-\><C-n>:<C-u>call rtags#JumpTo(g:NEW_TAB_IF_DIFF_FILE)<CR>

    nmap <Leader>rp <C-\><C-n>:<C-u>call rtags#JumpToParent()<CR>

    nmap <Leader>rb <C-\><C-n>:<C-u>call rtags#JumpBack()<CR>
    nmap <Leader>r, <C-\><C-n>:<C-u>call rtags#JumpBack()<CR>
    nmap <Leader>r. <C-\><C-n>:<C-u>call rtags#JumpForward()<CR>
    nmap <Leader>rh <C-\><C-n>:<C-u>call rtags#ShowHierarchy()<CR>
    nmap <Leader>rC <C-\><C-n>:<C-u>call rtags#FindSuperClasses()<CR>
    nmap <Leader>rc <C-\><C-n>:<C-u>call rtags#FindSubClasses()<CR>

    " CompleteSymbols can be huge and take too long ...
    "nmap <Leader>rn <C-\><C-n>:<C-u>call rtags#FindRefsByName(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    nmap <Leader>rn <C-\><C-n>:<C-u>call rtags#FindRefsByName(input("Pattern? "))<CR>
    nmap <Leader>rk <C-\><C-n>:<C-u>call rtags#FindSymbolsOfWordUnderCursor()<CR>
    "nmap <Leader>rK <C-\><C-n>:<C-u>call rtags#FindSymbols(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    nmap <Leader>rK <C-\><C-n>:<C-u>call rtags#FindSymbols(input("Pattern? "))<CR>
    "nmap <Leader>rm <C-\><C-n>:<C-u>call rtags#JumpToMethod(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    nmap <Leader>rm <C-\><C-n>:<C-u>call rtags#JumpToMethod(input("Pattern? "))<CR>

    nmap <Leader>rl <C-\><C-n>:<C-u>call rtags#ProjectList()<CR>
    nmap <Leader>rw <C-\><C-n>:<C-u>call rtags#RenameSymbolUnderCursor()<CR>

    nmap <silent> <Leader>rr <C-\><C-n>:<C-u>call rtags#ReindexFile(1)<CR>

    nmap <silent> <Leader>rL <Cmd>call rtags#TailRDMLog()<CR>

    nmap <silent> <Leader>rR <Cmd>call rtags#ReindexFile(2)<CR>

    nmap <Leader>r0 <C-\><C-n>:<C-u>call rtags#SuspendIndexing()<CR>
    nmap <Leader>r1 <C-\><C-n>:<C-u>call rtags#ResumeIndexing()<CR>
    nmap <Leader>r: <C-\><C-n>:<C-u>call rtags#ToggleColonKeyword()<CR>

    " NOTE: also suggest these mappings:
    "nmap <C-]> <C-\><C-n>:<C-u>call rtags#JumpTo(g:SAME_WINDOW)<CR>
    "vmap <C-]> <Nop>
    "autocmd BufReadPost quickfix nmap <silent> <buffer> <C-]> <Return>
endif

let s:script_folder_path = escape( expand( '<sfile>:p:h' ), '\' )

function rtags#QuitIfOnlyHidden(bnum) abort
    " just to clear the cmdline of this function ...
    redraw!
    echo "\r"
    "echom "a:bnum = " . a:bnum
    let l:doquit = 1
    for b in getbufinfo()
        "echom "bufnr = " . b.bufnr
        "echom "bname = " . bufname(b.bufnr)
        "echom "hidden = " . b.hidden
        "echom "listed = " . b.listed
        "echom "changd = " . b.changed
        if b.bufnr == a:bnum
            continue
        elseif empty(bufname(b.bufnr)) && !b.listed
            continue
        elseif !b.hidden
            let l:doquit = 0
            break
        elseif b.changed
            let l:doquit = 0
            break
        elseif getbufvar(b.bufnr, '&modified')
            let l:doquit = 0
            break
        elseif getbufvar(b.bufnr, '&buftype') ==# 'terminal'
            let l:doquit = 0
            break
        endif
    endfor
    "echom "l:doquit = " . l:doquit
    if l:doquit == 1
        " TODO: is it ok to quit like this ?
        cquit
    endif
endfunction

function! rtags#TailRDMLog() abort
    if has("nvim")
        let tcmd = '$tabnew | terminal tail -f /tmp/rdm-' . $USER . '.log'
        autocmd TermOpen  term://* if (expand('<afile>') =~ ":tail -f /tmp/rdm-") | se scl=no | call nvim_input('i') | endif
        autocmd TermClose term://* if (expand('<afile>') =~ ":tail -f /tmp/rdm-") | call nvim_input('<CR>') | endif
        autocmd BufDelete term://* if (expand('<afile>') =~ ":tail -f /tmp/rdm-") | call rtags#QuitIfOnlyHidden(bufnr('%')) | endif
    else
        let tcmd = '$tabnew | terminal ++close ++norestore ++kill=term ++curwin tail -f /tmp/rdm-' . $USER . '.log'
    endif
    execute tcmd
    if !has("nvim")
        se scl=no
    endif
endfunction

function! rtags#InitPython()
    let s:pyInitScript = "
\ import vim;
\ script_folder = vim.eval('s:script_folder_path');
\ sys.path.insert(0, script_folder);
\ import vimrtags"

    exe g:rtagsPy." ".s:pyInitScript
endfunction

call rtags#InitPython()

"""
" Logging routine
"""
function! rtags#Log(message)
    if exists("g:rtagsLog")
        call writefile([string(a:message)], g:rtagsLog, "a")
    endif
endfunction

"
" Executes rc with given arguments and returns rc output
"
" param[in] args - dictionary of arguments
"-
" return output split by newline
function! rtags#ExecuteRC(args, cmdinfo)
    let cmd = rtags#getRcCmd()

    " Give rdm unsaved file content, so that you don't have to save files
    " before each rc invocation.
    if exists('b:rtags_sent_content')
        let content = join(getline(1, line('$')), "\n")
        if b:rtags_sent_content != content
            let unsaved_content = content
        endif
    elseif &modified
        let unsaved_content = join(getline(1, line('$')), "\n")
    endif
    if exists('unsaved_content')
        let filename = expand("%:p")
        silent let output = system(printf("%s --wait --unsaved-file=%s:%s -V %s", cmd, filename, strlen(unsaved_content), filename), unsaved_content)
        let b:rtags_sent_content = unsaved_content
    endif

    " prepare for the actual command invocation
    for [key, value] in items(a:args)
        let cmd .= " ".key
        if len(value) > 1
            let cmd .= " ".value
        endif
    endfor

    let cmd1 = cmd
    let cmd2 = '/bin/bash -c "' . cmd . ' 2>&1 | sort | head -n 500"'
    let cmd = cmd2

    silent let output = system(cmd)
    if v:shell_error
        echohl DiffDelete
        echomsg "[vim-rtags] Error: " . cmdinfo
        echomsg cmd1
        if len(output) > 0
            let output = substitute(output, '\n', '', '')
            echomsg output
        endif
        echohl None
        return []
    endif

    return split(output, '\n\+')
endfunction

function! rtags#CreateProject()

endfunction

"
" param[in] results - List of found locations by rc
" return locations - List of locations dict's recognizable by setloclist
"
function! rtags#ParseResults(results)
    let locations = []
    let nr = 1
    for record in a:results
        " mck - ?
        if len(split(record, '\s\+')) == 0
            continue
        endif
        " mck - ?
        let [location; rest] = split(record, '\s\+')
        let [file, lnum, col] = rtags#parseSourceLocation(location)

        let entry = {}
        "        let entry.bufn = 0
        let entry.filename = substitute(file, getcwd().'/', '', 'g')
        let entry.filepath = file
        let entry.lnum = lnum
        "        let entry.pattern = ''
        let entry.col = col
        let entry.vcol = 0
        "        let entry.nr = nr
        let entry.text = join(rest, ' ')
        let entry.type = 'ref'

        call add(locations, entry)

        let nr = nr + 1
    endfor
    return locations
endfunction

function! rtags#ExtractClassHierarchyLine(line)
    return substitute(a:line, '\v.*\s+(\S+:[0-9]+:[0-9]+:\s)', '\1', '')
endfunction

"
" Converts a class hierarchy of 'rc --class-hierarchy' like:
"
" Superclasses:
"   class Foo src/Foo.h:56:7: class Foo : public Bar {
"     class Bar	src/Bar.h:46:7:	class Bar : public Bas {
"       class Bas src/Bas.h:47:7: class Bas {
" Subclasses:
"   class Foo src/Foo.h:56:7: class Foo : public Bar {
"     class Foo2 src/Foo2.h:56:7: class Foo2 : public Foo {
"     class Foo3 src/Foo3.h:56:7: class Foo3 : public Foo {
"
" into the super classes:
"
" src/Foo.h:56:7: class Foo : public Bar {
" src/Bar.h:46:7: class Bar : public Bas {
" src/Bas.h:47:7: class Bas {
"
function! rtags#ExtractSuperClasses(results, symbol)
    let extracted = []
    if len(a:results) == 1 && a:results[0] ==# 'Not indexed'
        let extLine = 'Not indexed'
        call add(extracted, extLine)
        return extracted
    endif
    for line in a:results
        if line == "Superclasses:"
            continue
        endif

        if line == "Subclasses:"
            break
        endif

        let extLine = rtags#ExtractClassHierarchyLine(line)
        call add(extracted, extLine)
    endfor
    return extracted
endfunction

"
" Converts a class hierarchy of 'rc --class-hierarchy' like:
"
" Superclasses:
"   class Foo src/Foo.h:56:7: class Foo : public Bar {
"     class Bar	src/Bar.h:46:7:	class Bar : public Bas {
"       class Bas src/Bas.h:47:7: class Bas {
" Subclasses:
"   class Foo src/Foo.h:56:7: class Foo : public Bar {
"     class Foo2 src/Foo2.h:56:7: class Foo2 : public Foo {
"     class Foo3 src/Foo3.h:56:7: class Foo3 : public Foo {
"
" into the sub classes:
"
" src/Foo.h:56:7: class Foo : public Bar {
" src/Foo2.h:56:7: class Foo2 : public Foo {
" src/Foo3.h:56:7: class Foo3 : public Foo {
"
function! rtags#ExtractSubClasses(results, symbol)
    let extracted = []
    if len(a:results) == 1 && a:results[0] ==# 'Not indexed'
        let extLine = 'Not indexed'
        call add(extracted, extLine)
        return extracted
    endif
    let atSubClasses = 0
    for line in a:results
        if atSubClasses == 0
            if line == "Subclasses:"
                let atSubClasses = 1
            endif

            continue
        endif

        let extLine = rtags#ExtractClassHierarchyLine(line)
        call add(extracted, extLine)
    endfor
    return extracted
endfunction

"
" param[in] locations - List of locations, one per line
"
function! rtags#DisplayLocations(locations, args)
    let num_of_locations = len(a:locations)
    if num_of_locations == 0
        if type(a:args) == 1
            let symbol = a:args
        elseif type(a:args) == 3 || type(a:args) == 4
            let symbol = get(a:args, 'symbol', '<unable to determine symbol>')
        endif
        echohl DiffDelete | echomsg "[vim-rtags] No loc info returned for: " . symbol | echohl None
        return
    endif
    if num_of_locations == 1
        " dict: [{'lnum': '', 'vcol': 0, 'col': '', 'filename': '', 'type': 'ref', 'text': '', 'filepath': ''}]
        let lnum = a:locations[0].lnum
        let lcol = a:locations[0].col
        let lfile = a:locations[0].filename
        let ltext = a:locations[0].text
        if empty(lnum) && empty(lcol) && empty(lfile) && empty(ltext)
            if type(a:args) == 1
                let symbol = a:args
            elseif type(a:args) == 3 || type(a:args) == 4
                let symbol = get(a:args, 'symbol', '<unable to determine symbol>')
            endif
            echohl DiffDelete | echomsg "[vim-rtags] Invalid loc info returned for: " . symbol | echohl None
            return
        endif
    endif
    if g:rtagsUseLocationList == 1
        call setloclist(winnr(), a:locations)
        if num_of_locations > 0
            exe 'ccl'
            exe 'lopen '.min([g:rtagsMaxSearchResultWindowHeight, num_of_locations]) | set nowrap | clearjumps
        endif
    else
        call setqflist(a:locations)
        if num_of_locations > 0
            exe 'lcl'
            exe 'copen '.min([g:rtagsMaxSearchResultWindowHeight, num_of_locations]) | set nowrap | clearjumps
        endif
    endif
    " mck - clear cmdline to signify rtags func is complete
    "let w:quickfix_title=<something>
    "echohl None | echomsg "" | echohl None
    redraw!
    echo " "
endfunction

"
" param[in] results - List of locations, one per line
"
" Format of each line: <path>,<line>\s<text>
function! rtags#DisplayResults(results, args)
    if len(a:results) == 1 && a:results[0] ==# 'Not indexed'
        echohl ErrorMsg | echomsg "[vim-rtags] Current file is not indexed!" | echohl None
        return
    endif
    let locations = rtags#ParseResults(a:results)
    call rtags#DisplayLocations(locations, a:args)
endfunction

"
" Creates a tree viewer for references to a symbol
"
" param[in] results - List of locations, one per line
"
" Format of each line: <path>,<line>\s<text>\sfunction: <caller path>
function! rtags#ViewReferences(results, args)
    if len(a:results) == 1 && a:results[0] ==# 'Not indexed'
        echohl ErrorMsg | echomsg "[vim-rtags] Current file is not indexed!" | echohl None
        return
    endif
    let cmd = g:rtagsMaxSearchResultWindowHeight . "new References"
    silent execute cmd

    " TODO - add these lines to a quickfix window instead of a split window ...

    setlocal noswapfile
    setlocal buftype=nowrite
    setlocal bufhidden=delete
    setlocal nowrap
    setlocal tw=0

    iabc <buffer>

    setlocal modifiable
    silent normal ggdG
    setlocal nomodifiable
    let b:rtagsLocations=[]
    call rtags#AddReferences(a:results, -1)
    setlocal modifiable
    silent normal ggdd
    setlocal nomodifiable

    let cpo_save = &cpo
    set cpo&vim
    nmap <buffer> <cr> :call <SID>OpenReference()<cr>
    nmap <buffer> o    :call <SID>ExpandReferences()<cr>
    nmap <buffer> <C-]> <cr>
    nmap <buffer> <Leader>cc <Leader>qq
    let &cpo = cpo_save
endfunction

"
" Expands the callers of the reference on the current line.
"
function! s:ExpandReferences() " <<<
    let ln = line(".")

    " Detect expandable region
    if !empty(b:rtagsLocations[ln - 1].source)
        let location = b:rtagsLocations[ln - 1].source
        let rnum = b:rtagsLocations[ln - 1].rnum
        let b:rtagsLocations[ln - 1].source = ''
        let args = {
                \ '--containing-function-location' : '',
                \ '-r' : location }
        let symbol = 'ExpandReferences' " TODO
        call rtags#ExecuteThen(args, [[function('rtags#AddReferences'), rnum]], symbol)
    endif
endfunction " >>>

"
" Opens the reference for viewing in the window below.
"
function! s:OpenReference() " <<<
    let ln = line(".")

    " Detect openable region
    if ln - 1 < len(b:rtagsLocations)
        let jump_file = b:rtagsLocations[ln - 1].filename
        let lnum = b:rtagsLocations[ln - 1].lnum
        let col = b:rtagsLocations[ln - 1].col
        wincmd j
        " Add location to the jumplist
        normal m'
        if rtags#jumpToLocation(jump_file, lnum, col)
            normal zz
        endif
    endif
endfunction " >>>

"
" Adds the list of references below the targeted item in the reference
" viewer window.
"
" param[in] results - List of locations, one per line
" param[in] rnum - The record number the references are calling or -1
"
" Format of each line: <path>,<line>\s<text>\sfunction: <caller path>
function! rtags#AddReferences(results, rnum)
    let ln = line(".")
    let depth = 0
    let nr = len(b:rtagsLocations)
    let i = -1
    " If a reference number is provided, find this entry in the list and insert
    " after it.
    if a:rnum >= 0
        let i = 0
        while i < nr && b:rtagsLocations[i].rnum != a:rnum
            let i += 1
        endwhile
        if i == nr
            " We didn't find the source record, something went wrong
            echo "Error finding insertion point."
            return
        endif
        let depth = b:rtagsLocations[i].depth + 1
        exec (":" . (i + 1))
    endif
    let prefix = repeat(" ", depth * 2)
    let new_entries = []
    setlocal modifiable
    for record in a:results
        let [line; sourcefunc] = split(record, '\s\+function: ')
        let [location; rest] = split(line, '\s\+')
        let [file, lnum, col] = rtags#parseSourceLocation(location)
        let entry = {}
        let entry.filename = substitute(file, getcwd().'/', '', 'g')
        let entry.filepath = file
        let entry.lnum = lnum
        let entry.col = col
        let entry.vcol = 0
        let entry.text = join(rest, ' ')
        let entry.type = 'ref'
        let entry.depth = depth
        let entry.source = matchstr(sourcefunc, '[^\s]\+')
        let entry.rnum = nr
        silent execute "normal! A\<cr>\<esc>i".prefix . substitute(entry.filename, '.*/', '', 'g').':'.entry.lnum.' '.entry.text."\<esc>"
        call add(new_entries, entry)
        let nr = nr + 1
    endfor
    call extend(b:rtagsLocations, new_entries, i + 1)
    setlocal nomodifiable
    exec (":" . ln)
endfunction

" Creates a viewer for hierarachy results
"
" param[in] results - List of class hierarchy
"
" Hierarchy references have format: <type> <name> <file>:<line>:<col>: <text>
"
function! rtags#ViewHierarchy(results)
    if len(a:results) == 1 && a:results[0] ==# 'Not indexed'
        echohl ErrorMsg | echomsg "[vim-rtags] Current file is not indexed!" | echohl None
        return
    endif
    let cmd = g:rtagsMaxSearchResultWindowHeight . "new Hierarchy"
    silent execute cmd

    " TODO - add these lines to a quickfix window instead of a split window ...

    setlocal noswapfile
    setlocal buftype=nowrite
    setlocal bufhidden=delete
    setlocal nowrap
    setlocal tw=0

    iabc <buffer>

    setlocal modifiable
    silent normal ggdG
    for record in a:results
        silent execute "normal! A\<cr>\<esc>i".record."\<esc>"
    endfor
    silent normal ggdd
    setlocal nomodifiable

    let cpo_save = &cpo
    set cpo&vim
    nmap <buffer> <cr> :call <SID>OpenHierarchyLocation()<cr>
    nmap <buffer> <C-]> <cr>
    nmap <buffer> <Leader>cc <Leader>qq
    let &cpo = cpo_save
    " mck
    redraw!
    echo " "
endfunction

"
" Opens the location on the current line.
"
" Hierarchy references have format: <type> <name> <file>:<line>:<col>: <text>
"
function! s:OpenHierarchyLocation() " <<<
    let ln = line(".")
    let l = getline(ln)
    if l[0] == ' '
        let [type, name, location; rest] = split(l, '\s\+')
        let [jump_file, lnum, col; rest] = split(location, ':')
        wincmd j
        " Add location to the jumplist
        normal m'
        if rtags#jumpToLocation(jump_file, lnum, col)
            normal zz
        endif
    endif
endfunction " >>>

function! rtags#getRcCmd()
    let cmd = g:rtagsRcCmd
    let cmd .= " --absolute-path "
    if g:rtagsExcludeSysHeaders == 1
        return cmd." -H "
    endif
    return cmd
endfunction

function! rtags#getCurrentLocation()
    let [lnum, col] = getpos('.')[1:2]
    return printf("%s:%s:%s", expand("%:p"), lnum, col)
endfunction

function! rtags#SymbolInfoHandler(output, jb_args)
    let l = len(a:output)
    if l == 0
        redraw!
        echohl ErrorMsg | echomsg "[vim-rtags] no info returned for: " . a:jb_args | echohl None
        return
    endif
    if a:output[0] ==# 'Not indexed'
        redraw!
        echohl ErrorMsg | echomsg "[vim-rtags] Current file is not indexed!" | echohl None
        return
    endif

    " --------------
    " if from async job join() uses ^@ instead of \n and we get only one line ...
    " let result = join(a:output, "\n")
    " " mck - dont redraw! here, want prompt to continue ...
    " echo result
    " --------------

    let list2 = []
    for rec in a:output
        call add(list2, { "text":rec })
    endfor
    let num_lines = len(list2)
    if num_lines > 0
        call setloclist(winnr(), list2)
        exe 'lopen '.min([g:rtagsMaxSearchResultWindowHeight, num_lines]) | set nowrap | clearjumps
    else
        redraw!
        echohl ErrorMsg | echomsg "[vim-rtags] no info returned for: " . a:jb_args | echohl None
        return
    endif
endfunction

function! rtags#SymbolInfo()
    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let symbol = expand("<cword>")
    let rtagscmdmsg = '[vim-rtags] SymbolInfo: ' . symbol
    let &iskeyword = l:oldiskeyword
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen({ '-U' : rtags#getCurrentLocation() }, [function('rtags#SymbolInfoHandler')], symbol)
    " mck - async does not work yet
    "let cmdinfo = 'SymbolInfo: ' . symbol
    "let result = rtags#ExecuteRC({ '-U' : rtags#getCurrentLocation() }, cmdinfo)
    "call rtags#ExecuteHandlers(result, [function('rtags#SymbolInfoHandler')], symbol)
    " mck
endfunction

function! rtags#cloneCurrentBuffer(type)
    if a:type == g:SAME_WINDOW
        return
    endif

    let [lnum, col] = getpos('.')[1:2]
    " mck - do we want %:p here ?
    exec s:LOC_OPEN_OPTS[a:type]." new ".expand("%:p")
    call cursor(lnum, col)
endfunction

function! rtags#jumpToLocation(file, line, col)
    call rtags#saveLocation()
    return rtags#jumpToLocationInternal(a:file, a:line, a:col)
endfunction

function! rtags#jumpToLocationInternal(file, line, col)
    try
        if a:file != expand("%:p")
            exe "e ".a:file
        endif
        "call cursor(a:line, a:col)
        let curlistpos = [a:line, a:col]
        call cursor(curlistpos)
        " mck - clear cmdline to signify rtags func is complete
        redraw!
        echo " "
        return 1
    catch /.*/
        echohl DiffDelete
        echomsg v:exception
        echohl None
        return 0
    endtry
endfunction

function! rtags#JumpToHandler(results, args)
    let results = a:results
    let open_opt = a:args['open_opt']
    let symbol = a:args['symbol']
    let skipjump = get(a:args, 'skip_jump', 'n')

    if len(results) > 1
        call rtags#DisplayResults(results, a:args)
    elseif len(results) == 1 && results[0] ==# 'Not indexed'
        echohl ErrorMsg | echomsg "[vim-rtags] Current file is not indexed!" | echohl None
    elseif len(results) == 1
        try
            let [location; symbol_detail] = split(results[0], '\s\+')
            let [jump_file, lnum, col; rest] = split(location, ':')
        catch
            echohl ErrorMsg | echomsg "[vim-rtags] Error: " . results[0] | echohl None
            return
        endtry

        " mck - new tab if different file and tab split if same file and want new tab
        if !((open_opt == g:SAME_WINDOW) || (open_opt == g:NEW_TAB_IF_DIFF_FILE && jump_file ==# expand("%:p")))
            if open_opt == g:NEW_TAB && jump_file ==# expand("%:p")
                exec "tab split"
            else
                call rtags#cloneCurrentBuffer(open_opt)
            endif
        endif
        " mck - new tab if different file and tab split if same file and want new tab

        if skipjump != 'y'
            " Add location to the jumplist
            normal! m'
        endif

        if rtags#jumpToLocation(jump_file, lnum, col)
            if skipjump != 'y'
                normal! zz
            else
                keepjumps normal! zz
            endif
        endif
    else
        if empty(symbol)
            let symbol = '<unable to determine symbol>'
        endif
        echohl DiffText | echomsg "[vim-rtags] No addl loc info for: " . symbol | echohl None
    endif
endfunction

"
" JumpTo(open_type, ...)
"     open_type - Vim command used for opening desired location.
"     Allowed values:
"       * g:SAME_WINDOW
"       * g:H_SPLIT
"       * g:V_SPLIT
"       * g:NEW_TAB
"       * g:NEW_TAB_IF_DIFF_FILE
"
"     a:1 - dictionary of additional arguments for 'rc'
"
function! rtags#JumpTo(open_opt, ...)
    if &buftype == 'terminal'
        redraw!
        echo " "
        return
    endif

    let args = {}
    if a:0 > 0
        let args = a:1
    endif

    call extend(args, { '-f' : rtags#getCurrentLocation() })
    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let symbol = expand("<cword>")
    let rtagscmdmsg = '[vim-rtags] JumpTo: '. symbol
    let &iskeyword = l:oldiskeyword
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen(args, [[function('rtags#JumpToHandler'), { 'open_opt' : a:open_opt, 'symbol' : symbol }]], symbol)
endfunction

function! rtags#parseSourceLocation(string)
    let [location; symbol_detail] = split(a:string, '\s\+')
    let splittedLine = split(location, ':')
    if len(splittedLine) == 3
        let [jump_file, lnum, col; rest] = splittedLine
        " Must be a path, therefore leading / is compulsory
        if jump_file[0] == '/'
            return [jump_file, lnum, col]
        endif
    endif
    return ["","",""]
endfunction

function! rtags#saveLocation()
    " mck - not used right now
    return

    let [lnum, col] = getpos('.')[1:2]
    let jump_file = expand("%:p")
"   call rtags#pushToStack([jump_file, lnum, col])
    if len(g:rtagsJumpStack) > 0
        let [old_file, olnum, ocol] = get(g:rtagsJumpStack, -1)
        if old_file == jump_file && olnum == lnum && ocol == col
            "echo "skipping dup entry on jump stack"
        else
            call rtags#pushToStack([jump_file, lnum, col])
        endif
    else
        call rtags#pushToStack([jump_file, lnum, col])
    endif
endfunction

function! rtags#pushToStack(location)
    let jumpListLen = len(g:rtagsJumpStack) 
    if jumpListLen > g:rtagsJumpStackMaxSize
        call remove(g:rtagsJumpStack, 0)
    endif
    call add(g:rtagsJumpStack, a:location)
endfunction

function! rtags#JumpBack()
    execute "normal \<C-o>"
    "if len(g:rtagsJumpStack) > 0
    "    "let [jump_file, lnum, col] = remove(g:rtagsJumpStack, -1)
    "    let [jump_file, lnum, col] = get(g:rtagsJumpStack, -1)
    "    call rtags#jumpToLocationInternal(jump_file, lnum, col)
    "else
    "    "echo "rtags: jump stack is empty"
    "    execute "normal \<C-o>"
    "endif
endfunction

function! rtags#JumpForward()
    " NOTE: need the 1 before the \<C-i> ...
    execute "normal 1\<C-i>"
    "if len(g:rtagsJumpStack) > 0
    "    "let [jump_file, lnum, col] = remove(g:rtagsJumpStack, 0)
    "    let [jump_file, lnum, col] = get(g:rtagsJumpStack, 0)
    "    call rtags#jumpToLocationInternal(jump_file, lnum, col)
    "else
    "    "echo "rtags: jump stack is empty"
    "    execute "normal 1\<C-i>"
    "endif
endfunction

function! rtags#JumpToParentHandler(results, symbol)
    if len(a:results) == 1 && a:results[0] ==# 'Not indexed'
        echohl ErrorMsg | echomsg "[vim-rtags] Current file is not indexed!" | echohl None
        return
    endif
    let results = a:results
    for line in results
        let matched = matchend(line, "^Parent: ")
        if matched == -1
            continue
        endif
        let [jump_file, lnum, col] = rtags#parseSourceLocation(line[matched:-1])
        if !empty(jump_file)
            if a:0 > 0
                call rtags#cloneCurrentBuffer(a:1)
            endif

            " Add location to the jumplist
            normal! m'
            if rtags#jumpToLocation(jump_file, lnum, col)
                normal! zz
            endif
            return
        endif
    endfor
    " mck - is it an error if here ?
    "echohl DiffText | echomsg "[vim-rtags] No Parent info for: " . a:symbol | echohl None
    let [clnum, ccol] = getpos('.')[1:2]
    let cfile = expand("%:p")
    " mck - ask if want to try to jump more
    echohl DiffText | echomsg "[vim-rtags] No Parent info for: " . a:symbol . " Try to jump? (<y>/n): " | echohl None
    let ans=nr2char(getchar())
    if ans ==# 'y' || ans ==# 'Y' || ans ==# ''
        let result = rtags#ExecuteRC({ '-f' : rtags#getCurrentLocation() }, a:symbol)
        call rtags#JumpToHandler(result, { 'open_opt' : g:SAME_WINDOW, 'symbol' : a:symbol, 'skip_jump' : 'y' })
        let [nlnum, ncol] = getpos('.')[1:2]
        let nfile = expand("%:p")
        if nfile == cfile && nlnum == clnum && ncol == ccol
            echohl DiffAdd | echomsg "[vim-rtags] No addl Parent info for: " . a:symbol | echohl None
            sleep 651m
            redraw!
            echo " "
        else
            call rtags#JumpToParent()
        endif
    else
        redraw!
        echo " "
    endif
endfunction

function! rtags#JumpToParent()
    let args = {
                \ '-U' : rtags#getCurrentLocation(),
                \ '--symbol-info-include-parents' : '' }

    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let symbol = expand("<cword>")
    let rtagscmdmsg = '[vim-rtags] JumpToParent: '. symbol
    let &iskeyword = l:oldiskeyword
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen(args, [[function('rtags#JumpToParentHandler'), symbol]], symbol)
endfunction

function! s:GetCharacterUnderCursor()
    return matchstr(getline('.'), '\%' . col('.') . 'c.')
endfunction

function! rtags#JumpToMethod(pattern)
    let current_file = expand("%:p")
    let args = {
                \ '-a' : '',
                \ '-F' : a:pattern,
                \ '--kind-filter' : 'CXXMethod',
                \ '-i' : current_file }

    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let symbol = expand("<cword>")
    let rtagscmdmsg = '[vim-rtags] JumpToMethod: '. symbol
    let &iskeyword = l:oldiskeyword
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    "let result = rtags#ExecuteRC(args, symbol)
    "call rtags#JumpToHandler(result, { 'open_opt' : g:SAME_WINDOW, 'symbol' : symbol, 'skip_jump' : 'n' })
    call rtags#ExecuteThen(args, [[function('rtags#JumpToHandler'), { 'open_opt' : g:SAME_WINDOW, 'symbol' : symbol, 'skip_jump' : 'n' }]], symbol)
endfunction

function! rtags#RenameSymbolUnderCursorHandler(output)
    let locations = rtags#ParseResults(a:output)
    if len(locations) > 0
        let newName = input("Enter new name: ")
        let yesToAll = 0
        if !empty(newName)
            for loc in reverse(locations)
                if !rtags#jumpToLocationInternal(loc.filepath, loc.lnum, loc.col)
                    return
                endif
                normal! zv
                normal! zz
                redraw
                let choice = yesToAll
                if choice == 0
                    let location = loc.filepath.":".loc.lnum.":".loc.col
                    let choices = "&Yes\nYes to &All\n&No\n&Cancel"
                    let choice = confirm("Rename symbol at ".location, choices)
                endif
                if choice == 2
                    let choice = 1
                    let yesToAll = 1
                endif
                if choice == 1
                    " Special case for destructors
                    if s:GetCharacterUnderCursor() == '~'
                        normal! l
                    endif
                    exec "normal! ciw".newName."\<Esc>"
                    write!
                elseif choice == 4
                    return
                endif
            endfor
        endif
    endif
endfunction

function! rtags#RenameSymbolUnderCursor()
    let args = {
                \ '-e' : '',
                \ '-r' : rtags#getCurrentLocation(),
                \ '--rename' : '' }

    let symbol = expand("<cword>")
    call rtags#ExecuteThen(args, [function('rtags#RenameSymbolUnderCursorHandler')], symbol)
endfunction

function! rtags#TempFile(job_cid)
    return '/tmp/neovim_async_rtags.tmp.' . getpid() . '.' . a:job_cid
endfunction

function! rtags#ExecuteRCAsync(args, handlers, symbol)
    let cmd = rtags#getRcCmd()

    " Give rdm unsaved file content, so that you don't have to save files
    " before each rc invocation.
    if exists('b:rtags_sent_content')
        let content = join(getline(1, line('$')), "\n")
        if b:rtags_sent_content != content
            let unsaved_content = content
        endif
    elseif &modified
        let unsaved_content = join(getline(1, line('$')), "\n")
    endif
    if exists('unsaved_content')
        let filename = expand("%:p")
        silent let output = system(printf("%s --wait --unsaved-file=%s:%s -V %s", cmd, filename, strlen(unsaved_content), filename), unsaved_content)
        let b:rtags_sent_content = unsaved_content
    endif

    " prepare for the actual command invocation
    for [key, value] in items(a:args)
        let cmd .= " ".key
        if len(value) > 1
            let cmd .= " ".value
        endif
    endfor

    let cmd2 = '/bin/bash -c "' . cmd . ' 2>&1 | sort | head -n 500"'
    let cmd = cmd2

    let s:job_cid = s:job_cid + 1
    if s:job_cid > 9999
        let s:job_cid = 1
    endif

    " should have out+err redirection portable for various shells.

    if has('nvim')

        let s:callbacks = {
            \ 'on_exit' : function('rtags#HandleResults')
            \ }
        let cmd = cmd . ' >' . rtags#TempFile(s:job_cid)
        let job = jobstart(cmd, s:callbacks)
        let s:jobs[job] = s:job_cid
        let s:result_handlers[job] = a:handlers
        let s:job_args[job] = a:symbol

    elseif has('job') && has('channel')

        " mck - vim 8+ job/channel method

        "let l:opts = {}
        "let l:opts.mode = 'nl'
        "let l:opts.out_cb = {ch, data -> rtags#HandleResults(ch_info(ch).id, data, 'vim_stdout')}
        "let l:opts.exit_cb = {ch, data -> rtags#HandleResults(ch_info(ch).id, data,'vim_exit')}
        "let l:opts.stoponexit = 'kill'
        "let job = job_start(cmd, l:opts)
        "let channel = ch_info(job_getchannel(job)).id
        "let s:result_stdout[channel] = []
        "let s:jobs[channel] = s:job_cid
        "let s:result_handlers[channel] = a:handlers

        let job = job_start(cmd, { 'out_mode':'nl' , 'stoponexit':'kill' , 'close_cb':'rtags#CloseCallback' })
        let channel = job_getchannel(job)
        let ch = ch_info(channel).id
        let s:jobs[ch] = s:job_cid
        let s:result_handlers[ch] = a:handlers
        let s:job_args[ch] = a:symbol

    endif

endfunction

" mck - vim 8+ job/channel method
function! rtags#CloseCallback(channel) abort
        let ch = ch_info(a:channel).id
        let job_cid = remove(s:jobs, ch)
        let handlers = remove(s:result_handlers, ch)
        let jb_symbol = remove(s:job_args, ch)
        let output = []
        while ch_status(a:channel, { 'part':'out' }) == 'buffered'
            call add(output, ch_read(a:channel))
        endwhile
        call rtags#ExecuteHandlers(output, handlers, jb_symbol)
endfunction

function! rtags#HandleResults(job_id, data, event)
    if a:event == 'vim_stdout'
       "call add(s:result_stdout[a:job_id], a:data)
        if !exists('s:result_stdout[a:job_id]')
          sleep 551m
        endif
        if exists('s:result_stdout[a:job_id]')
          call add(s:result_stdout[a:job_id], a:data)
        else
          let l:errmsg = "rtags#HandleResults() stdout ERR"
          echohl DiffDelete | echomsg errmsg | echohl None
        endif
    elseif a:event == 'vim_exit'
        let job_cid = remove(s:jobs, a:job_id)
        let handlers = remove(s:result_handlers, a:job_id)
        " TODO: mck - probably need to check if any buffered output is present to read in ...
        let output = remove(s:result_stdout, a:job_id)
        let jb_symbol = remove(s:job_args, ch)
        call rtags#ExecuteHandlers(output, handlers, jb_symbol)
    else
        let job_cid = remove(s:jobs, a:job_id)
        let temp_file = rtags#TempFile(job_cid)
        let output = readfile(temp_file)
        execute 'silent !rm -f ' . temp_file
        let handlers = remove(s:result_handlers, a:job_id)
        let jb_symbol = remove(s:job_args, a:job_id)
        call rtags#ExecuteHandlers(output, handlers, jb_symbol)
    endif
endfunction

function! rtags#ExecuteHandlers(output, handlers, jb_symbol)
    let result = a:output
    for Handler in a:handlers
        if type(Handler) == 3
            let HandlerFunc = Handler[0]
            let args = Handler[1]
            call HandlerFunc(result, args)
        else
            try
                let result = Handler(result, a:jb_symbol)
            catch /E*/
                " If we're not returning the right type we're probably done
                echohl DiffDelete
                echomsg "[vim-rtags] ExecuteHandlers Error:"
                echomsg v:exception
                echomsg v:throwpoint
                echohl None
                for record in a:output
                    echomsg record
                endfor
                return
            endtry
        endif
    endfor 
endfunction

function! rtags#ExecuteThen(args, handlers, symbol)
    if s:rtagsAsync == 1
        call rtags#ExecuteRCAsync(a:args, a:handlers, a:symbol)
    else
        let result = rtags#ExecuteRC(a:args, a:symbol)
        call rtags#ExecuteHandlers(result, a:handlers, a:symbol)
    endif
endfunction

function! rtags#FindRefs()
    let args = {
                \ '-e' : '',
                \ '-r' : rtags#getCurrentLocation() }

    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let symbol = expand("<cword>")
    let rtagscmdmsg = '[vim-rtags] FindRefs: ' . symbol
    let &iskeyword = l:oldiskeyword
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')], symbol)
endfunction

function! rtags#ShowHierarchy()
    let args = {'--class-hierarchy' : rtags#getCurrentLocation() }

    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let symbol = expand("<cword>")
    let rtagscmdmsg = '[vim-rtags] ShowHierarchy: ' . symbol
    let &iskeyword = l:oldiskeyword
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen(args, [function('rtags#ViewHierarchy')], symbol)
endfunction

function! rtags#FindRefsCallTree()
    let args = {
                \ '--containing-function-location' : '',
                \ '-r' : rtags#getCurrentLocation() }

    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let symbol = expand("<cword>")
    let rtagscmdmsg = '[vim-rtags] FindRefsCallTree: '. symbol
    let &iskeyword = l:oldiskeyword
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen(args, [function('rtags#ViewReferences')], symbol)
endfunction

function! rtags#FindSuperClasses()
    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let symbol = expand("<cword>")
    let rtagscmdmsg = '[vim-rtags] FindSuperClasses: '. symbol
    let &iskeyword = l:oldiskeyword
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    let cmdinfo = 'FindSuperClasses: ' . symbol
    call rtags#ExecuteThen({ '--class-hierarchy' : rtags#getCurrentLocation() },
                \ [function('rtags#ExtractSuperClasses'), function('rtags#DisplayResults')], cmdinfo)
endfunction

function! rtags#FindSubClasses()
    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let symbol = expand("<cword>")
    let rtagscmdmsg = '[vim-rtags] FindSubClasses: ' . symbol
    let &iskeyword = l:oldiskeyword
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    let cmdinfo = 'FindSubClasses: ' . symbol
    let result = rtags#ExecuteThen({ '--class-hierarchy' : rtags#getCurrentLocation() }, [
                \ function('rtags#ExtractSubClasses'),
                \ function('rtags#DisplayResults')], cmdinfo)
endfunction

function! rtags#FindVirtuals()
    let args = {
                \ '-k' : '',
                \ '-r' : rtags#getCurrentLocation() }

    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let symbol = expand("<cword>")
    let rtagscmdmsg = '[vim-rtags] FindVirtuals: ' . symbol
    let &iskeyword = l:oldiskeyword
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')], symbol)
endfunction

function! rtags#FindRefsByName(name)
    let args = {
                \ '-a' : '',
                \ '-e' : '',
                \ '-R' : a:name }

    let rtagscmdmsg = '[vim-rtags] FindRefsByName: ' . a:name
    redraw!
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')], a:name)
endfunction

" case insensitive FindRefsByName
function! rtags#IFindRefsByName(name)
    let args = {
                \ '-a' : '',
                \ '-e' : '',
                \ '-R' : a:name,
                \ '-I' : '' }

    let rtagscmdmsg = '[vim-rtags] IFindRefsByName: ' . a:name
    redraw!
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')], a:name)
endfunction

" Find all those references which has the name which is equal to the word
" under the cursor
function! rtags#FindRefsOfWordUnderCursor()
    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let wordUnderCursor = expand("<cword>")
    let &iskeyword = l:oldiskeyword
    call rtags#FindRefsByName(wordUnderCursor)
endfunction

""" rc -HF <pattern>
function! rtags#FindSymbols(pattern)
    if empty(a:pattern)
        echo "<empty input>"
        sleep 551m
        redraw!
        echo " "
        return
    endif
    let args = {
                \ '-a' : '',
                \ '-F' : a:pattern }

    let rtagscmdmsg = '[vim-rtags] FindSymbols: ' . a:pattern
    redraw!
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')], a:pattern)
endfunction

" Method for tab-completion for vim's commands
function! rtags#CompleteSymbols(arg, line, pos)
    if len(a:arg) < g:rtagsMinCharsForCommandCompletion
        return []
    endif
    call rtags#ExecuteThen({ '-S' : a:arg }, [function('filter')], a:pattern)
endfunction

" case insensitive FindSymbol
function! rtags#IFindSymbols(pattern)
    if empty(a:pattern)
        echo "<empty input>"
        sleep 551m
        redraw!
        echo " "
        return
    endif
    let args = {
                \ '-a' : '',
                \ '-I' : '',
                \ '-F' : a:pattern }

    let rtagscmdmsg = '[vim-rtags] IFindSymbols: ' . a:pattern
    redraw!
    echohl Comment | echo rtagscmdmsg | echohl None
    call rtags#saveLocation()
    call rtags#ExecuteThen(args, [function('rtags#DisplayResults')], a:pattern)
endfunction

function! rtags#ProjectListHandler(output, jb_args)
    let projects = a:output
    if len(projects) == 0
        echohl DiffDelete | echomsg "[vim-rtags] No projects found" | echohl None
        return
    endif
    let i = 1
    for p in projects
        echo '['.i.'] '.p
        let i = i + 1
    endfor
    let choice = input('Choice: ')
    if choice > 0 && choice <= len(projects)
        call rtags#ProjectOpen(projects[choice-1])
    endif
endfunction

function! rtags#ProjectList()
    let symbol = 'ProjectList'
    "call rtags#ExecuteThen({ '-w' : '' }, [function('rtags#ProjectListHandler')], symbol)
    " mck - async does not work yet
    let result = rtags#ExecuteRC({ '-w' : '' }, symbol)
    call rtags#ExecuteHandlers(result, [function('rtags#ProjectListHandler')], symbol)
    " mck
endfunction

function! rtags#ProjectOpen(pattern)
    if empty(a:pattern)
        echo "<empty input>"
        sleep 551m
        redraw!
        echo " "
        return
    endif
    "call rtags#ExecuteThen({ '-w' : a:pattern }, [], a:pattern)
    call rtags#ExecuteRC({ '-w' : a:pattern }, 'ProjectOpen')
endfunction

function! rtags#LoadCompilationDb(pattern)
    if empty(a:pattern)
        echo "<empty input>"
        sleep 551m
        redraw!
        echo " "
        return
    endif
    "call rtags#ExecuteThen({ '-J' : a:pattern }, [], a:pattern)
    call rtags#ExecuteRC({ '-J' : a:pattern }, 'LoadCompilationDb')
endfunction

function! rtags#ProjectClose(pattern)
    if empty(a:pattern)
        echo "<empty input>"
        sleep 551m
        redraw!
        echo " "
        return
    endif
    "call rtags#ExecuteThen({ '-u' : a:pattern }, [], a:pattern)
    call rtags#ExecuteRC({ '-u' : a:pattern }, 'ProjectClose')
endfunction

function! rtags#PreprocessFileHandler(result)
    vnew
    call append(0, a:result)
endfunction

function! rtags#PreprocessFile()
    let symbol = 'PreprocessFile' " TODO
    call rtags#ExecuteThen({ '-E' : expand("%:p") }, [function('rtags#PreprocessFileHandler')], symbol)
endfunction

function! rtags#ReindexFile(arg)
    if a:arg != 0
        redraw!
    endif
    if &filetype ==# 'qf'
        echo " "
        return
    elseif &buftype ==# 'terminal'
        echo " "
        return
    elseif &buftype ==# 'quickfix'
        echo " "
        return
    elseif !&buflisted
        echo " "
        return
    endif
    let rifile = expand("%:p")
    if empty(rifile)
        echo " "
        return
    endif
    if a:arg == 2
        let rtagscmdmsg = '[vim-rtags] Check index [all]'
        let symbol = 'Check index [all]' " TODO
    else
        let rtagscmdmsg = '[vim-rtags] ReindexFile: ' . expand("%:p")
        let symbol = 'ReindexFile' " TODO
    endif
    if a:arg != 0
        echohl Comment | echo rtagscmdmsg | echohl None
    endif
    "call rtags#ExecuteThen({ '-V' : expand("%:p") }, [], symbol)
    " mck - async does not work yet
    if a:arg == 2
        call rtags#ExecuteRC({ '-x' : '' }, 'Check index [all]')
        sleep 551m
        redraw!
        echo " "
    elseif a:arg == 1
        call rtags#ExecuteRC({ '--wait -V' : expand("%:p") }, 'ReindexFile')
        sleep 551m
        redraw!
        echo " "
    else
        " TODO: -V or -x here ?
        call rtags#ExecuteRC({ '-x' : expand("%:p") }, 'ReindexFile')
    endif
endfunction

function! rtags#FindSymbolsOfWordUnderCursor()
    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let wordUnderCursor = expand("<cword>")
    let &iskeyword = l:oldiskeyword
    call rtags#FindSymbols(wordUnderCursor)
endfunction

function! rtags#Diagnostics()
    let s:file = expand("%:p")
    let rtagscmdmsg = '[vim-rtags] run diagnostics'
    redraw!
    echohl Comment | echo rtagscmdmsg | echohl None
    return s:Pyeval("vimrtags.get_diagnostics()")
endfunction

function! rtags#SuspendIndexing()
    let result = rtags#ExecuteRC({ '--suspend' : 'all' }, 'SuspendIndexing')
    let rtagscmdmsg = '[vim-rtags] Indexing: ' . result[0]
    redraw!
    echohl DiffText | echo rtagscmdmsg | echohl None
endfunction

function! rtags#ResumeIndexing()
    let result = rtags#ExecuteRC({ '--suspend' : 'clear' }, 'ResumeIndexing')
    let rtagscmdmsg = '[vim-rtags] Indexing: ' . result[0]
    redraw!
    echohl DiffText | echo rtagscmdmsg | echohl None
endfunction

function! rtags#ToggleColonKeyword()
    if (g:rtagsUseColonKeyword == 0)
        let g:rtagsUseColonKeyword = 1
        let l:rtagskeywordmsg = '[vim-rtags] use symbol colon is enabled'
    else
        let g:rtagsUseColonKeyword = 0
        let l:rtagskeywordmsg = '[vim-rtags] use symbol colon is disabled'
    endif
    echohl DiffChange | echo l:rtagskeywordmsg | echohl None
    sleep 651m
    redraw!
    echo " "
endfunction

"
" This function assumes it is invoked from insert mode
"
function! rtags#CompleteAtCursor(wordStart, base)
    let flags = "--synchronous-completions -l"
    let file = expand("%:p")
    let pos = getpos('.')
    let line = pos[1] 
    let col = pos[2]

    if index(['.', '::', '->'], a:base) != -1
        let col += 1
    endif

    let rcRealCmd = rtags#getRcCmd()

    exec "normal! \<Esc>"
    let stdin_lines = join(getline(1, "$"), "\n").a:base
    let offset = len(stdin_lines)

    exec "startinsert!"
    "    echomsg getline(line)
    "    sleep 1
    "    echomsg "DURING INVOCATION POS: ".pos[2]
    "    sleep 1
    "    echomsg stdin_lines
    "    sleep 1
    " sed command to remove CDATA prefix and closing xml tag from rtags output
    let sed_cmd = "sed -e 's/.*CDATA\\[//g' | sed -e 's/.*\\/completions.*//g'"
    let cmd = printf("%s %s %s:%s:%s --unsaved-file=%s:%s | %s", rcRealCmd, flags, file, line, col, file, offset, sed_cmd)
    call rtags#Log("Command line:".cmd)

    let result = split(system(cmd, stdin_lines), '\n\+')
    "    echomsg "Got ".len(result)." completions"
    "    sleep 1
    call rtags#Log("-----------")
    "call rtags#Log(result)
    call rtags#Log("-----------")
    return result
    "    for r in result
    "        echo r
    "    endfor
    "    call rtags#DisplayResults(result)
endfunction

function! s:Pyeval( eval_string )
  if g:rtagsPy == 'python3'
      return py3eval( a:eval_string )
  else
      return pyeval( a:eval_string )
  endif
endfunction
    
function! s:RcExecuteJobCompletion()
    call rtags#SetJobStateFinish()
    if ! empty(b:rtags_state['stdout']) && mode() == 'i'
        call feedkeys("\<C-x>\<C-o>", "t")
    else
        call RtagsCompleteFunc(0, RtagsCompleteFunc(1, 0))
    endif
endfunction

"{{{ RcExecuteJobHandler
"Handles stdout/stderr/exit events, and stores the stdout/stderr received from the shells.
function! RcExecuteJobHandler(job_id, data, event)
    if a:event == 'exit'
        call s:RcExecuteJobCompletion()
    else
        call rtags#AddJobStandard(a:event, a:data)
    endif
endf

function! rtags#SetJobStateFinish()
    let b:rtags_state['state'] = 'finish'
endfunction

function! rtags#AddJobStandard(eventType, data)
    call add(b:rtags_state[a:eventType], a:data)
endfunction

function! rtags#SetJobStateReady()
    let b:rtags_state['state'] = 'ready'
endfunction

function! rtags#IsJobStateReady()
    if b:rtags_state['state'] == 'ready'
        return 1
    endif
    return 0
endfunction

function! rtags#IsJobStateBusy()
    if b:rtags_state['state'] == 'busy'
        return 1
    endif
    return 0
endfunction

function! rtags#IsJobStateFinish()
    if b:rtags_state['state'] == 'finish'
        return 1
    endif
    return 0
endfunction


function! rtags#SetStartJobState()
    let b:rtags_state['state'] = 'busy'
    let b:rtags_state['stdout'] = []
    let b:rtags_state['stderr'] = []
endfunction

function! rtags#GetJobStdOutput()
    return b:rtags_state['stdout']
endfunction

function! rtags#ExistsAndCreateRtagsState()
    if !exists('b:rtags_state')
        let b:rtags_state = { 'state': 'ready', 'stdout': [], 'stderr': [] }
    endif
endfunction

"{{{ s:RcExecute
" Execute clang binary to generate completions and diagnostics.
" Global variable:
" Buffer vars:
"     b:rtags_state => {
"       'state' :  // updated to 'ready' in sync mode
"       'stdout':  // updated in sync mode
"       'stderr':  // updated in sync mode
"     }
"
"     b:clang_execute_job_id  // used to stop previous job
"
" @root Clang root, project directory
" @line Line to complete
" @col Column to complete
" @return [completion, diagnostics]
function! s:RcJobExecute(offset, line, col)

    let file = expand("%:p")
    let l:cmd = printf("rc --absolute-path --synchronous-completions -l %s:%s:%s --unsaved-file=%s:%s", file, a:line, a:col, file, a:offset)

    if exists('b:rc_execute_job_id') && job_status(b:rc_execute_job_id) == 'run'
      try
        call job_stop(b:rc_execute_job_id, 'term')
        unlet b:rc_execute_job_id
      catch
        " Ignore
      endtry
    endif

    call rtags#SetStartJobState()

    let l:argv = l:cmd
    let l:opts = {}
    let l:opts.mode = 'nl'
    let l:opts.in_io = 'buffer'
    let l:opts.in_buf = bufnr('%')
    let l:opts.out_cb = {ch, data -> RcExecuteJobHandler(ch, data,  'stdout')}
    let l:opts.err_cb = {ch, data -> RcExecuteJobHandler(ch, data,  'stderr')}
    let l:opts.exit_cb = {ch, data -> RcExecuteJobHandler(ch, data, 'exit')}
    let l:opts.stoponexit = 'kill'

    let l:jobid = job_start(l:argv, l:opts)
    let b:rc_execute_job_id = l:jobid

    if job_status(l:jobid) != 'run'
        unlet b:rc_execute_job_id
    endif

endf

"""
" Temporarily the way this function works is:
"     - completeion invoked on
"         object.meth*
"       , where * is cursor position
"     - find the position of a dot/arrow
"     - invoke completion through rc
"     - filter out options that start with meth (in this case).
"     - show completion options
" 
"     Reason: rtags returns all options regardless of already type method name
"     portion
"""

function! RtagsCompleteFunc(findstart, base)
    if s:rtagsAsync == 1 && !has('nvim')
        return s:RtagsCompleteFunc(a:findstart, a:base, 1)
    else
        return s:RtagsCompleteFunc(a:findstart, a:base, 0)
    endif
endfunction

function! s:RtagsCompleteFunc(findstart, base, async)
    call rtags#Log("RtagsCompleteFunc: [".a:findstart."], [".a:base."]")

    if a:findstart
        let s:line = getline('.')
        let s:start = col('.') - 2
        return s:Pyeval("vimrtags.get_identifier_beginning()")
    else
        let pos = getpos('.')
        let s:file = expand("%:p")
        let s:line = str2nr(pos[1])
        let s:col = str2nr(pos[2]) + len(a:base)
        let s:prefix = a:base
        return s:Pyeval("vimrtags.send_completion_request()")
    endif
endfunction

if &completefunc == ""
    set completefunc=RtagsCompleteFunc
endif

" Helpers to access script locals for unit testing {{{
function! s:get_SID()
    return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction
let s:SID = s:get_SID()
delfunction s:get_SID

function! rtags#__context__()
    return { 'sid': s:SID, 'scope': s: }
endfunction
"}}}

command! -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsFindSymbols call rtags#FindSymbols(<q-args>)
command! -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsFindRefsByName call rtags#FindRefsByName(<q-args>)

command! -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsIFindSymbols call rtags#IFindSymbols(<q-args>)
command! -nargs=1 -complete=customlist,rtags#CompleteSymbols RtagsIFindRefsByName call rtags#IFindRefsByName(<q-args>)

command! -nargs=1 -complete=dir RtagsLoadCompilationDb call rtags#LoadCompilationDb(<q-args>)

" The most commonly used find operation
command! -nargs=1 -complete=customlist,rtags#CompleteSymbols Rtag RtagsIFindSymbols <q-args>

function! rtags#CheckReindexFile()
    if g:rtagsAutoReindexOnWrite ==# 1
        silent call rtags#ReindexFile(0)
    endif
endfunction
autocmd Filetype c,cpp autocmd BufWritePost,FileWritePost,FileAppendPost <buffer> call rtags#CheckReindexFile()

