let s:placeholder_texts = []

let s:startdelim = get(g:, 'usnip_startdelim', '{{+')
let s:enddelim = get(g:, 'usnip_enddelim', '+}}')
let s:evalmarker = get(g:, 'usnip_evalmarker', '~')
let s:backrefmarker = get(g:, 'usnip_backrefmarker', '\\~')

let s:delimpat = '\V' . s:startdelim . '\.\{-}' . s:enddelim

function! usnip#should_trigger() abort
    return search(s:delimpat, 'e')
endfunction

" main function, called on press of Tab (or whatever key Minisnip is bound to)
function! usnip#expand() abort
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
endfunction

" this is the function that finds and selects the next placeholder
function! s:select_placeholder() abort
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
        " There's no placeholder at all, enter insert mode
        call feedkeys('i', 'n')
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
endfunction

func! usnip#done(item) abort
    if empty(a:item)
        return
    endif

    if match(a:item.word, '[\x0]') != -1
        keeppatterns silent! substitute /[\x0]/\r/g
        norm! '[=']
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
                \ 'word': join(l:content, "\n"),
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
