# μSnip

Minimalistic snippet management for Vim.

## Installation

Check your favourite plugin manager or `:h pack-add` if you do not use any.

## Usage

This plugin uses `:h compl-function` to expand snippets. This also requires it
to attach to `CompleteDone` auto command which has some changes in default
behaviour:

- All completions that contain `NUL` will have that characters replaced with new
  line. If it is a problem for you, then I feel truly sorry, but you need help.
- Expansion syntax (`{{++}}` by default, for now) will be used in all your
  completions. On the one hand this is a pro, on the other it can be con. If
  that bothers you, then there is a lot of other snippets plugins. Feel free to
  chose any of them.

Oh, and this currently remaps `<Tab>` in insert mode in the way that it doesn't
work anymore. I will try to fix it soon, but for now you should change to use
`i_CTRL-T` and `i_CTRL-D` instead.

## Special thanks

- [@KeyboardFire](https://github.com/KeyboardFire)
- Martin Tournoij [@Carpetsmoker](https://github.com/Carpetsmoker)
- Joe Reynolds [@joereynolds](https://github.com/joereynolds)

And other authors of [vim-minisnip][minisnip]. This is greatly based on their
tremendous work.

[minisnip]: https://github.com/joereynolds/vim-minisnip "Mnisnip"
