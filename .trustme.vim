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
augroup trustme
  " Remove! all trustme autocommands.
  autocmd! trustme
  "autocmd BufWrite *.rb silent !touch TOUCH
  " MEH/2017-08-02: This won't hook bin/murano.
  autocmd BufWrite *.rb silent !./.trustme.sh &
augroup END

