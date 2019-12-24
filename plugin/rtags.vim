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

if has('python')
    let g:rtagsPy = 'python'
elseif has('python3')
    let g:rtagsPy = 'python3'
else
    echohl ErrorMsg | echomsg "[vim-rtags] Vim is missing python support" | echohl None
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

if !exists("g:rtagsJumpStackMaxSize")
    let g:rtagsJumpStackMaxSize = 100
endif

if !exists("g:rtagsExcludeSysHeaders")
    let g:rtagsExcludeSysHeaders = 0
endif

let g:rtagsJumpStack = []

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
    call system(g:rtagsRcCmd." -w")
    if v:shell_error != 0 
       "call system(g:rtagsRdmCmd." --daemon > /dev/null")
       "call system(g:rtagsRdmCmd." --log-file /tmp/rdm.log --daemon")
        call system(g:rtagsRdmCmd." --tempdir /tmp/rdm-".$USER." --log-file /tmp/rdm-".$USER.".log --daemon")
    end
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
    noremap <Leader>ri :call rtags#SymbolInfo()<CR>
    noremap <Leader>rj :call rtags#JumpTo(g:SAME_WINDOW)<CR>
    noremap <Leader>rJ :call rtags#JumpTo(g:SAME_WINDOW, { '--declaration-only' : '' })<CR>
    "noremap <Leader>rS :call rtags#JumpTo(g:H_SPLIT)<CR>
    " mck - add rH for Horizontal split
    noremap <Leader>rH :call rtags#JumpTo(g:H_SPLIT)<CR>
    noremap <Leader>rV :call rtags#JumpTo(g:V_SPLIT)<CR>
    " mck - really a tab split if same file
    noremap <Leader>rT :call rtags#JumpTo(g:NEW_TAB)<CR>
    " mck - add rt for new tab if diff file
    noremap <Leader>rt :call rtags#JumpTo(g:NEW_TAB_IF_DIFF_FILE)<CR>
    noremap <Leader>rp :call rtags#JumpToParent()<CR>
    noremap <Leader>rf :call rtags#FindRefs()<CR>
    noremap <Leader>rF :call rtags#FindRefsCallTree()<CR>
    noremap <Leader>rn :call rtags#FindRefsByName(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    noremap <Leader>rs :call rtags#FindSymbols(input("Pattern? ", "", "customlist,rtags#CompleteSymbols"))<CR>
    noremap <Leader>rr :call rtags#ReindexFile(1)<CR>
    noremap <Leader>rl :call rtags#ProjectList()<CR>
    noremap <Leader>rw :call rtags#RenameSymbolUnderCursor()<CR>
    noremap <Leader>rv :call rtags#FindVirtuals()<CR>
    noremap <Leader>rb :call rtags#JumpBack()<CR>
    noremap <Leader>rh :call rtags#ShowHierarchy()<CR>
    noremap <Leader>rC :call rtags#FindSuperClasses()<CR>
    noremap <Leader>rc :call rtags#FindSubClasses()<CR>
    noremap <Leader>rd :call rtags#Diagnostics()<CR>
endif

let s:script_folder_path = escape( expand( '<sfile>:p:h' ), '\' )

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
function! rtags#ExecuteRC(args)
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
        let output = system(printf("%s --wait --unsaved-file=%s:%s -V %s", cmd, filename, strlen(unsaved_content), filename), unsaved_content)
        let b:rtags_sent_content = unsaved_content
    endif

    " prepare for the actual command invocation
    for [key, value] in items(a:args)
        let cmd .= " ".key
        if len(value) > 1
            let cmd .= " ".value
        endif
    endfor

    let cmd2 = '/bin/bash -c ("' . cmd . ' | sort | head -n 500) 2>&1"'
    let cmd = cmd2

    let output = system(cmd)
    if v:shell_error && len(output) > 0
        let output = substitute(output, '\n', '', '')
        echohl ErrorMsg | echomsg "[vim-rtags] Error: " . output | echohl None
        return []
    endif
    if output ==# 'Not indexed'
        echohl ErrorMsg | echomsg "[vim-rtags] Current file is not indexed!" | echohl None
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
function! rtags#ExtractSuperClasses(results)
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
function! rtags#ExtractSubClasses(results)
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
            exe 'lopen '.min([g:rtagsMaxSearchResultWindowHeight, num_of_locations]) | set nowrap | clearjumps
        endif
    else
        call setqflist(a:locations)
        if num_of_locations > 0
            exe 'copen '.min([g:rtagsMaxSearchResultWindowHeight, num_of_locations]) | set nowrap | clearjumps
        endif
    endif
    " mck - clear cmdline to signify rtags func is complete
    "let w:quickfix_title=<something>
    "echohl None | echomsg "" | echohl None
    redraw!
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
function! rtags#ViewReferences(results)
    if len(a:results) == 1 && a:results[0] ==# 'Not indexed'
        echohl ErrorMsg | echomsg "[vim-rtags] Current file is not indexed!" | echohl None
        return
    endif
    let cmd = g:rtagsMaxSearchResultWindowHeight . "new References"
    silent execute cmd
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
    nnoremap <buffer> <cr> :call <SID>OpenReference()<cr>
    nnoremap <buffer> o    :call <SID>ExpandReferences()<cr>
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
    nnoremap <buffer> <cr> :call <SID>OpenHierarchyLocation()<cr>
    let &cpo = cpo_save
    " mck
    redraw!
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

function! rtags#SymbolInfoHandler(output)
    echo join(a:output, "\n")
    " mck - dont redraw! here, want prompt to continue ...
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
    "call rtags#ExecuteThen({ '-U' : rtags#getCurrentLocation() }, [function('rtags#SymbolInfoHandler')], symbol)
    " mck - async does not work yet
    let result = rtags#ExecuteRC({ '-U' : rtags#getCurrentLocation() })
    call rtags#ExecuteHandlers(result, [function('rtags#SymbolInfoHandler')], symbol)
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
        call cursor(a:line, a:col)
        " mck - clear cmdline to signify rtags func is complete
        redraw!
        return 1
    catch /.*/
        echohl ErrorMsg
        echomsg v:exception
        echohl None
        return 0
    endtry
endfunction

function! rtags#JumpToHandler(results, args)
    let results = a:results
    let open_opt = a:args['open_opt']
    let symbol = a:args['symbol']

    if len(results) > 1
        call rtags#DisplayResults(results, args)
    elseif len(results) == 1 && results[0] ==# 'Not indexed'
        echohl ErrorMsg | echomsg "[vim-rtags] Current file is not indexed!" | echohl None
    elseif len(results) == 1
        let [location; symbol_detail] = split(results[0], '\s\+')
        let [jump_file, lnum, col; rest] = split(location, ':')

        " mck - new tab if different file and tab split if same file and want new tab
        if !((open_opt == g:SAME_WINDOW) || (open_opt == g:NEW_TAB_IF_DIFF_FILE && jump_file ==# expand("%:p")))
            if open_opt == g:NEW_TAB && jump_file ==# expand("%:p")
                exec "tab split"
            else
                call rtags#cloneCurrentBuffer(open_opt)
            endif
        endif
        " mck - new tab if different file and tab split if same file and want new tab

        " Add location to the jumplist
        normal! m'
        if rtags#jumpToLocation(jump_file, lnum, col)
            normal! zz
        endif
    else
        if empty(symbol)
            let symbol = '<unable to determine symbol>'
        endif
        echohl DiffText | echomsg "[vim-rtags] No addl loc info found for: " . symbol | echohl None
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
    let results = rtags#ExecuteThen(args, [[function('rtags#JumpToHandler'), { 'open_opt' : a:open_opt, 'symbol' : symbol }]], symbol)

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
    let [lnum, col] = getpos('.')[1:2]
"   call rtags#pushToStack([expand("%:p"), lnum, col])
    let jump_file = expand("%:p")
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
    if len(g:rtagsJumpStack) > 0
        let [jump_file, lnum, col] = remove(g:rtagsJumpStack, -1)
        call rtags#jumpToLocationInternal(jump_file, lnum, col)
    else
        "echo "rtags: jump stack is empty"
        execute "normal" "\<C-o>"
    endif
endfunction

function! rtags#JumpBackSave()
    if len(g:rtagsJumpStack) > 0
        let [jump_file, lnum, col] = get(g:rtagsJumpStack, -1)
        call rtags#jumpToLocationInternal(jump_file, lnum, col)
    else
        echo "rtags: jump stack is empty"
    endif
endfunction

function! rtags#JumpToParentHandler(results)
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
endfunction

function! rtags#JumpToParent(...)
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
    call rtags#ExecuteThen(args, [function('rtags#JumpToParentHandler')], symbol)
endfunction

function! s:GetCharacterUnderCursor()
    return matchstr(getline('.'), '\%' . col('.') . 'c.')
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
        let output = system(printf("%s --wait --unsaved-file=%s:%s -V %s", cmd, filename, strlen(unsaved_content), filename), unsaved_content)
        let b:rtags_sent_content = unsaved_content
    endif

    " prepare for the actual command invocation
    for [key, value] in items(a:args)
        let cmd .= " ".key
        if len(value) > 1
            let cmd .= " ".value
        endif
    endfor

    let cmd2 = '/bin/bash -c ("' . cmd . ' | sort | head -n 500) 2>&1"'
    let cmd = cmd2

    let s:job_cid = s:job_cid + 1
    " should have out+err redirection portable for various shells.

    if has('nvim')

        let s:callbacks = {
            \ 'on_exit' : function('rtags#HandleResults')
            \ }
        let cmd = cmd . ' >' . rtags#TempFile(s:job_cid) . ' 2>&1'
        let job = jobstart(cmd, s:callbacks)
        let s:jobs[job] = s:job_cid
        let s:result_handlers[job] = a:handlers
        let s:job_args[ch] = a:symbol

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
        let handlers = remove(s:result_handlers, a:job_id)
        let jb_symbol = remove(s:job_args, ch)
        call rtags#ExecuteHandlers(output, handlers, jb_symbol)
        execute 'silent !rm -f ' . temp_file
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
                echohl WarningMsg
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
        let result = rtags#ExecuteRC(a:args)
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
    call rtags#ExecuteThen({ '--class-hierarchy' : rtags#getCurrentLocation() },
                \ [function('rtags#ExtractSuperClasses'), function('rtags#DisplayResults')], symbol)
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
    let result = rtags#ExecuteThen({ '--class-hierarchy' : rtags#getCurrentLocation() }, [
                \ function('rtags#ExtractSubClasses'),
                \ function('rtags#DisplayResults')], symbol)
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

function! rtags#ProjectListHandler(output)
    let projects = a:output
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
    let symbol = 'Project-list'
    "call rtags#ExecuteThen({ '-w' : '' }, [function('rtags#ProjectListHandler')], symbol)
    " mck - async does not work yet
    let result = rtags#ExecuteRC({ '-w' : '' })
    call rtags#ExecuteHandlers(result, [function('rtags#ProjectListHandler')], symbol)
    " mck
endfunction

function! rtags#ProjectOpen(pattern)
    if empty(a:pattern)
        echo "<empty input>"
        sleep 551m
        redraw!
        return
    endif
    "call rtags#ExecuteThen({ '-w' : a:pattern }, [], a:pattern)
    call rtags#ExecuteRC({ '-w' : a:pattern })
endfunction

function! rtags#LoadCompilationDb(pattern)
    if empty(a:pattern)
        echo "<empty input>"
        sleep 551m
        redraw!
        return
    endif
    "call rtags#ExecuteThen({ '-J' : a:pattern }, [], a:pattern)
    call rtags#ExecuteRC({ '-J' : a:pattern })
endfunction

function! rtags#ProjectClose(pattern)
    if empty(a:pattern)
        echo "<empty input>"
        sleep 551m
        redraw!
        return
    endif
    "call rtags#ExecuteThen({ '-u' : a:pattern }, [], a:pattern)
    call rtags#ExecuteRC({ '-u' : a:pattern })
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
    redraw!
    if &filetype ==# 'qf'
        return
    elseif &buftype ==# 'terminal'
        return
    elseif &buftype ==# 'quickfix'
        return
    elseif !&buflisted
        return
    endif
    let rifile = expand("%:p")
    if empty(rifile)
        return
    endif
    let rtagscmdmsg = '[vim-rtags] ReindexFile: ' . expand("%:p")
    echohl Comment | echo rtagscmdmsg | echohl None
    let symbol = 'ReindexFile' " TODO
    "call rtags#ExecuteThen({ '-V' : expand("%:p") }, [], symbol)
    " mck - async does not work yet
    call rtags#ExecuteRC({ '-V' : expand("%:p") })
    if a:arg ==# 1
        sleep 551m
    endif
    redraw!
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
        call rtags#ReindexFile(0)
    endif
endfunction
autocmd Filetype c,cpp autocmd BufWritePost,FileWritePost,FileAppendPost <buffer> call rtags#CheckReindexFile()

