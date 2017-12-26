if exists('g:loaded_usnip')
    finish
endif
let g:loaded_usnip = 1

inoremap <expr> <Plug>(usnip-next) usnip#should_trigger() ?
            \"\<c-o>:call \usnip#expand()\<cr>" : v:char
snoremap <expr> <Plug>(usnip-next) usnip#should_trigger() ?
            \"\<c-o>:call \usnip#expand()\<cr>" : v:char

" add the default mappings if the user hasn't defined any
if !hasmapto('<Plug>(usnip-next)')
    imap <unique> <Tab> <Plug>(usnip-next)
    smap <unique> <Tab> <Plug>(usnip-next)
endif

set completefunc=usnip#complete

augroup usnip
    au!
    autocmd CompleteDone * call usnip#done(v:completed_item)
augroup END
