let s:startdelim = get(g:, 'usnip_startdelim', '{{+')
let s:enddelim = get(g:, 'usnip_enddelim', '+}}')
let s:evalmarker = get(g:, 'usnip_evalmarker', '~')
let s:backrefmarker = get(g:, 'usnip_backrefmarker', '\\~')

let s:delimpat = '\V' . s:startdelim . '\.\{-}' . s:enddelim

func! usnip#should_trigger() abort
    silent! unlet! s:snippetfile
    let l:cword = matchstr(getline('.'), '\v\f+%' . col('.') . 'c')

    let l:dirs = join(s:directories(), ',')
    let l:all = globpath(l:dirs, l:cword.'.snip', 0, 1)
    call filter(l:all, {_, path -> filereadable(path)})

    if len(l:all) > 0
        let s:snippetfile = l:all[0]
        return 1
    endif

    return search(s:delimpat, 'e')
endfunc

" main func, called on press of Tab (or whatever key Minisnip is bound to)
func! usnip#expand() abort
    if exists('s:snippetfile')
        " reset placeholder text history (for backrefs)
        let s:placeholder_texts = []
        let s:placeholder_text = ''
        " remove the snippet name
        normal! "_diw
        " adjust the indentation, use the current line as reference
        let l:ws = matchstr(getline(line('.')), '^\s\+')
        let l:lns = map(readfile(s:snippetfile), 'empty(v:val)? v:val : l:ws.v:val')
        " insert the snippet
        call append(line('.'), l:lns)
        " remove the empty line before the snippet
        normal! "_dd
        " select the first placeholder
        call s:select_placeholder()
    else
        " Make sure '< mark is set so the normal command won't error out.
        if getpos("'<") == [0, 0, 0, 0]
            call setpos("'<", getpos('.'))
        endif

        " save the current placeholder's text so we can backref it
        let l:old_s = @s
        normal! ms"syv`<`s
        let s:placeholder_text = @s
        let @s = l:old_s
        " jump to the next placeholder
        call s:select_placeholder()
    endif
endfunc

" this is the function that finds and selects the next placeholder
func! s:select_placeholder() abort
    " don't clobber s register
    let l:old_s = @s

    " get the contents of the placeholder
    " we use /e here in case the cursor is already on it (which occurs ex.
    "   when a snippet begins with a placeholder)
    " we also use keeppatterns to avoid clobbering the search history /
    "   highlighting all the other placeholders
    try
        " gn misbehaves when 'wrapscan' isn't set (see vim's #1683)
        let [l:ws, &ws] = [&ws, 1]
        silent keeppatterns execute 'normal! /' . s:delimpat . "/e\<cr>gn\"sy"
    catch /E486:/
        " There's no placeholder at all
        return
    finally
        let &ws = l:ws
    endtry

    " save the contents of the previous placeholder (for backrefs)
    call add(s:placeholder_texts, s:placeholder_text)

    " save length of entire placeholder for reference later
    let l:slen = len(@s)

    " remove the start and end delimiters
    let @s=substitute(@s, '\V' . s:startdelim, '', '')
    let @s=substitute(@s, '\V' . s:enddelim, '', '')

    " is this placeholder marked as 'evaluate'?
    if @s =~ '\V\^' . s:evalmarker
        " remove the marker
        let @s=substitute(@s, '\V\^' . s:evalmarker, '', '')
        " substitute in any backrefs
        let @s=substitute(@s, '\V' . s:backrefmarker . '\(\d\)',
            \"\\=\"'\" . substitute(get(
            \    s:placeholder_texts,
            \    len(s:placeholder_texts) - str2nr(submatch(1)), ''
            \), \"'\", \"''\", 'g') . \"'\"", 'g')
        " evaluate what's left
        let @s=eval(@s)
    endif

    if empty(@s)
        " the placeholder was empty, so just enter insert mode directly
        normal! gvd
        if col("'>") - l:slen >= col('$') - 1
            norm! $
        endif
    else
        " paste the placeholder's default value in and enter select mode on it
        execute "normal! gv\"spgv\<C-g>"
    endif

    " restore old value of s register
    let @s = l:old_s
endfunc

func! usnip#done(item) abort
    if empty(a:item)
        return
    endif

    if match(a:item.word, s:delimpat) != -1
        let s:placeholder_texts = []
        let s:placeholder_text = ''

        call s:select_placeholder()
    endif
endfunc

func! usnip#complete(findstart, base) abort
    if a:findstart
        " Locate the start of the word
        let l:line = getline('.')
        let l:start = col('.') - 1
        while l:start > 0 && l:line[l:start - 1] =~? '\a'
            let l:start -= 1
        endwhile

        return l:start
    endif

    " Load all snippets that match.
    let l:dirs = join(s:directories(), ',')
    let l:all = globpath(l:dirs, a:base.'*.snip', 0, 1)
    call filter(l:all, {_, path -> filereadable(path)})
    call map(l:all, funcref('s:build_comp'))
    call sort(l:all, {a,b-> a.abbr ==? b.abbr ? 0 : a.abbr > b.abbr ? 1 : -1})

    return l:all
endfunc

func! s:build_comp(_, path) abort
    let l:name = fnamemodify(a:path, ':t:r')
    let l:content = readfile(a:path)

    return {
                \ 'icase': 1,
                \ 'dup': 1,
                \ 'kind': 's',
                \ 'word': l:name,
                \ 'abbr': l:name,
                \ 'menu': l:content[0],
                \ 'info': join(l:content, "\n"),
                \ }
endfunc

func! s:directories() abort
    let l:filetypes = split(&filetype, '\.')
    let l:ret = []

    for l:dir in get(g:, 'usnip_dirs', ['~/.vim/snippets'])
        let l:ret += map(l:filetypes, {_, val -> l:dir.'/'.val}) + [l:dir]
    endfor

    return l:ret
endfunc
