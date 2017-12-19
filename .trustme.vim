" 2017-08-02: Aha! EZ-CI at last!

" USAGE: See: .trustme.sh

"echomsg "You've been Vimmed! at " . expand('%')

" @% is same as expand('%'), which for some miraculous reason
" is the path relative to this file??
"autocmd BufWrite *.rb echomsg "Hooray! at " . expand('%')
"autocmd BufWrite *.rb echomsg "Hooray! at " . @%

" Use an autocmd group so it's easy to delete the group,
" since every time we call autocmd, the command is appended,
" and this file gets sourced every switch to a corresponding
" project buffer.
"augroup trustme
"  " Remove! all trustme autocommands.
"  autocmd! trustme
"  "autocmd BufWrite *.rb silent !touch TOUCH
"  "autocmd BufWrite <buffer> echom "trustme is hooked!"
"  " MEH/2017-08-02: This won't hook bin/murano.
""  autocmd BufWrite <buffer> silent !./.trustme.sh &
"  autocmd BufWritePost <buffer> silent !./.trustme.sh &
"augroup END

" NOTE: The tags path cannot be relative.
autocmd BufRead *.rb set tags=/exo/clients/exosite/exosite-murcli/tags

"echomsg 'Calling trustme.sh'
"echomsg "g:DUBS_TRUST_ME_ON_SAVE: " . g:DUBS_TRUST_ME_ON_SAVE
"silent !./.trustme.sh &
"silent !/exo/clients/exosite/exosite-murcli/.trustme.sh &

" If you open from project.vim (via the magic in=""),
" then neither of these globals will have been set
" by dubs_edit_juice.vim.
if !exists("g:DUBS_TRUST_ME_ON_FILE")
  let g:DUBS_TRUST_ME_ON_FILE = '<project.vim>'
endif
if !exists("g:DUBS_TRUST_ME_ON_SAVE")
  let g:DUBS_TRUST_ME_ON_SAVE = 0
endif

let s:cmd = '!' .
  \ ' DUBS_TRUST_ME_ON_FILE=' . g:DUBS_TRUST_ME_ON_FILE .
  \ ' DUBS_TRUST_ME_ON_SAVE=' . g:DUBS_TRUST_ME_ON_SAVE .
  \ ' /exo/clients/exosite/exosite-murcli/.trustme.sh &'
silent exec s:cmd

