"-----------------------------------------------------------------------------"
" Global plugin settings
"-----------------------------------------------------------------------------"
" Define mappings and delimiters
if !exists('g:shortcuts_templates_path')
  let g:shortcuts_templates_path = '~/templates'
endif
if !exists('g:shortcuts_surround_prefix')
  let g:shortcuts_surround_prefix = '<C-s>'
endif
if !exists('g:shortcuts_snippet_prefix')
  let g:shortcuts_snippet_prefix = '<C-d>'
endif
if !exists('g:shortcuts_prevdelim_map')
  let g:shortcuts_prevdelim_map = '<C-h>'
endif
if !exists('g:shortcuts_nextdelim_map')
  let g:shortcuts_nextdelim_map = '<C-l>'
endif
if !exists('g:shortcuts_delimjump_regex')
  let g:shortcuts_delimjump_regex = '[()\[\]{}<>\$]' " list of 'outside' delimiters for jk matching
endif

" Function used with input() to prevent tab expansion and literal tab insertion
function! NullList(...) abort
  return []
endfunction

"-----------------------------------------------------------------------------"
" Local functions (cannot be defined in autoload)
"-----------------------------------------------------------------------------"
" Move to right of previous delim  ( [ [ ( "  "  asd) sdf    ]  sdd   ]  as) h adfas)
" Note: matchstrpos is relatively new/less portable, e.g. fails on midway
" Used to use matchstrpos, now just use match(); much simpler
" Note: Why up to two places to left of current position col('.') - 1? There is
" delimiter to our left, want to ignore that. If delimiter is left of cursor, we are at
" a 'next to the cursor' position; want to test line even further to the left.
function! s:prev_delim()
  let string = getline('.')[:col('.') - 3]
  let string = join(reverse(split(string, '.\zs')), '')  " search the *reversed* string
  let pos = 0
  for i in range(max([v:count, 1]))
    let result = match(string, g:shortcuts_delimjump_regex, pos)  " get info on *first* match
    if result == -1 | break | endif
    let pos = result + 1  " go to next one
  endfor
  if pos == 0 " relative position is zero, i.e. don't move
    return ''
  else
    return repeat("\<Left>", pos)
  endif
endfunction

" Move to right of next delim. Why starting from current position? Even if cursor is on
" delimiter, want to find it and move to the right of it
function! s:next_delim()
  let string = getline('.')[col('.') - 1:]
  let pos = 0
  echom 'Start!'
  for i in range(max([v:count, 1]))
    let result = match(string, g:shortcuts_delimjump_regex, pos)  " get info on *first* match
    if result == -1 | break | endif
    let pos = result + 1  " go to next one
    echom 'Move! ' . pos
  endfor
  if mode() !~# '[rRiI]' && pos + col('.') >= col('$') " want to put cursor at end-of-line, but can't because not in insert mode
    let pos = col('$') - col('.') - 1
  endif
  if pos == 0 " relative position is zero, i.e. don't move
    return ''
  else
    return repeat("\<Right>", pos)
  endif
endfunction

" Define the maps, with special consideration for whether popup menu is open.
" See: https://github.com/lukelbd/dotfiles/blob/master/.vimrc
function! s:popup_close()
  if !pumvisible()
    return ''
  elseif b:menupos == 0  " exit
    return "\<C-e>"
  else
    let b:menupos = 0  " approve and exit
    return "\<C-y>"
  endif
endfunction

"-----------------------------------------------------------------------------"
" Define commands and mappings
"-----------------------------------------------------------------------------"
" Apply plugin mappings
" Note: Lowercase Isurround plug inserts delims without newlines. Instead of
" using ISurround we define special begin end delims with newlines baked in.
inoremap <Plug>ResetUndo <C-g>u
inoremap <silent> <Plug>IsurroundShow <C-o>:echo shortcuts#print_bindings('surround')<CR>
inoremap <silent> <Plug>IsnippetShow <C-o>:echo shortcuts#print_bindings('snippet')<CR>
inoremap <silent> <expr> <Plug>Isnippet shortcuts#insert_snippet()
inoremap <silent> <expr> <Plug>PrevDelim <sid>popup_close() . <sid>prev_delim()
inoremap <silent> <expr> <Plug>NextDelim <sid>popup_close() . <sid>next_delim()

" Apply custom prefixes
" Todo: Support surround-like '\1' notation for user input-dependent snippets...
" ...or not. While current method prohibits snippets with function substrings, it
" permits custom user-input functions that call FZF instead of input().
exe 'vmap ' . g:shortcuts_surround_prefix   . ' <Plug>VSurround'
exe 'imap ' . g:shortcuts_surround_prefix   . ' <Plug>ResetUndo<Plug>Isurround'
exe 'imap ' . g:shortcuts_snippet_prefix . ' <Plug>ResetUndo<Plug>Isnippet'
exe 'imap ' . repeat(g:shortcuts_surround_prefix, 2) . ' <Plug>IsurroundShow'
exe 'imap ' . repeat(g:shortcuts_snippet_prefix, 2) . ' <Plug>IsnippetShow'
exe 'imap ' . g:shortcuts_prevdelim_map . ' <Plug>PrevDelim'
exe 'imap ' . g:shortcuts_nextdelim_map . ' <Plug>NextDelim'
nnoremap <silent> ds :call shortcuts#delete_delims()<CR>
nnoremap <silent> cs :call shortcuts#change_delims()<CR>

" Add autocommands
" Todo: Support additional filetypes!
" Note: Arguments passed to function() partial are passed to underlying func first.
augroup templates
  au!
  au BufNewFile * if exists('*fzf#run') | call fzf#run({
    \ 'source': shortcuts#template_source(expand('<afile>:e')),
    \ 'options': '--no-sort --prompt="Template> "',
    \ 'down': '~30%',
    \ 'sink': function('shortcuts#template_read'),
    \ }) | endif
augroup END