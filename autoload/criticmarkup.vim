function! criticmarkup#Init()
    command! -buffer -nargs=1 -complete=custom,criticmarkup#CriticCompleteFunc 
                \Critic call criticmarkup#Critic("<args>")
endfunction

function! criticmarkup#InjectHighlighting()
    " Guard against re-initialization for performance
    if exists('b:criticmarkup_syntax_loaded')
        return
    endif
    let b:criticmarkup_syntax_loaded = 1

    " Create syntax cluster for containment - much faster than repeating long lists
    syn cluster criticContainers contains=pandocAtxHeader,pandocBlockQuote,pandocCodeBlock,pandocFootnoteBlock,pandocListItem,pandocUListItem,pandocDefinitionBlock,pandocYAMLHeader,yamlBlock,yamlHeader,yamlPlainScalar,yamlFlowString,htmlH1,htmlH2,htmlH3,htmlH4,htmlH5,htmlH6,mkdBlockquote,mkdCode,mkdLinkDefTarget,mkdListItem,mkdListItemLine,mkdMath,mkdNonListItem,mkdNonListItemBlock

    syn region criticAddition matchgroup=criticAdd start=/{++/ end=/++}/ containedin=@criticContainers concealends
    syn region criticDeletion matchgroup=criticDel start=/{--/ end=/--}/ containedin=@criticContainers concealends
    syn region criticSubstitutionDeletion start=/{\~\~/ end=/.\(\~>\)\@=/ containedin=@criticContainers keepend
    syn region criticSubstitutionAddition start=/\~>/ end=/\~\~}/ containedin=@criticContainers keepend
    syn match criticSubstitutionDeletionMark /{\~\~/ contained containedin=criticSubstitutionDeletion conceal
    syn match criticSubstitutionAdditionMark /\~\~}/ contained containedin=criticSubstitutionAddition conceal
    syn region criticComment matchgroup=criticMeta start=/{>>/ end=/<<}/ containedin=@criticContainers concealends
    syn region criticHighlight matchgroup=criticHighlighter start=/{==/ end=/==}/ containedin=@criticContainers concealends

    hi criticAdd guibg=#00ff00 guifg=#101010 ctermbg=46 ctermfg=16
    hi criticDel guibg=#ff0000 guifg=#ffffff ctermbg=196 ctermfg=231
    hi link criticAddition criticAdd
    hi link criticDeletion criticDel
    hi link criticSubstitutionAddition criticAddition
    hi link criticSubstitutionDeletion criticDeletion
    hi link criticSubstitutionAdditionMark criticAddition
    hi link criticSubstitutionDeletionMark criticDeletion
    hi criticMeta guibg=#0099FF guifg=#101010 ctermbg=33 ctermfg=16
    hi criticHighlighter guibg=#ffff00 guifg=#101010 ctermbg=11 ctermfg=16
    hi link criticComment criticMeta
    hi link criticHighlight criticHighlighter
endfunction

function! criticmarkup#Accept()
    " Cache synID lookup for performance
    let kind = synIDattr(synID(line("."), col("."), 1), "name")

    if kind =~ "criticAdd"
        " Remove markup, keep content: {++text++} -> text
        if search("{++", "cb")
            silent exe "normal! 3x"
            if search("++}", "c")
                silent exe "normal! 3x"
            endif
        endif
    elseif kind =~ "criticDel"
        " Remove entire deletion: {--text--} -> (nothing)
        if search("{--", "cb")
            silent exe "normal! v/--}\<cr>d"
        endif
    elseif kind =~ "criticSubstitution"
        " Keep addition part: {~~old~>new~~} -> new
        if search('{\~\~', "cb")
            silent exe "normal! v/\\~>\<cr>d"
            if search('\~\~}', "c")
                silent exe "normal! 3x"
            endif
        endif
    endif
endfunction

function! criticmarkup#Reject()
    " Cache synID lookup for performance
    let kind = synIDattr(synID(line("."), col("."), 1), "name")

    if kind =~ "criticDel"
        " Keep content, remove markup: {--text--} -> text
        if search("{--", "cb")
            silent exe "normal! 3x"
            if search("--}", "c")
                silent exe "normal! 3x"
            endif
        endif
    elseif kind =~ "criticAdd"
        " Remove entire addition: {++text++} -> (nothing)
        if search("{++", "cb")
            silent exe "normal! v/++}\<cr>d"
        endif
    elseif kind =~ "criticSubstitution"
        " Keep deletion part: {~~old~>new~~} -> old
        if search('{\~\~', "cb")
            silent exe "normal! 4x"
            if search('\~>', "c")
                silent exe "normal! v/\\~\\~}\<cr>d"
            endif
        endif
    endif
endfunction

function! criticmarkup#Critic(args)
    if a:args =~ "accept"
        call criticmarkup#Accept()
    elseif a:args =~ "reject"
        call criticmarkup#Reject()
    endif
endfunction

function! criticmarkup#JumpNext(editorial)
	if a:editorial == 1
		exe "normal ".v:count1."/{[-+\\~]\\{2\\}\<CR>"
	else
		exe "normal ".v:count1."/{[-+\\~\>=]\\{2\\}\<CR>"
	endif
endfunction

function! criticmarkup#JumpPrevious(editorial)
	if a:editorial == 1
		exe "normal ".v:count1."?{[-+\\~]\\{2\\}\<CR>"
	else
		exe "normal ".v:count1."?{[-+\\~\>=]\\{2\\}\<CR>"
	endif
endfunction

function! criticmarkup#CriticNext()
	call criticmarkup#JumpNext(1)
    let op = input("What to do? ", "", "custom,criticmarkup#CriticCompleteFunc")
    if op =~ "accept"
        call criticmarkup#Accept()
    elseif op =~ "reject"
        call criticmarkup#Reject()
    endif
endfunction

function! criticmarkup#CriticCompleteFunc(a, c, p)
    if len(split(a:c, " ", 1)) < 3
        return "accept\nreject"
    else
        return ""
    endif
endfunction

nnoremap <buffer> ]m :call criticmarkup#JumpNext(0)<CR>
nnoremap <buffer> [m :call criticmarkup#JumpPrevious(0)<CR>

nnoremap <buffer> <localleader>ed :set operatorfunc=CMDelOperator<cr>g@
vnoremap <buffer> <localleader>ed :<c-u>call CMOperator(visualmode(),'<','>','{--','--}')<cr>
nnoremap <buffer> <localleader>ea :set operatorfunc=CMAddOperator<cr>g@
vnoremap <buffer> <localleader>ea :<c-u>call CMOperator(visualmode(),'<','>','{++','++}')<cr>
nnoremap <buffer> <localleader>eh :set operatorfunc=CMHilOperator<cr>g@
vnoremap <buffer> <localleader>eh :<c-u>call CMOperator(visualmode(),'<','>','{==','==}')<cr>
nnoremap <buffer> <localleader>ec :set operatorfunc=CMComOperator<cr>g@
vnoremap <buffer> <localleader>ec :<c-u>call CMOperator(visualmode(),'<','>','{>>','<<}')<cr>
nnoremap <buffer> <localleader>es :set operatorfunc=CMSubOperator<cr>g@
vnoremap <buffer> <localleader>es :<c-u>call CMOperator(visualmode(),'<','>','{~~','~>~~}')<cr>

function! CMDelOperator(type)
    call CMOperator(a:type,'[',']','{--','--}')
endfunction

function! CMAddOperator(type)
    call CMOperator(a:type,'[',']','{++','++}')
endfunction

function! CMHilOperator(type)
    call CMOperator(a:type,'[',']','{==','==}')
endfunction

function! CMComOperator(type)
    call CMOperator(a:type,'[',']','{>>','<<}')
endfunction

function! CMSubOperator(type)
    call CMOperator(a:type,'[',']','{~~','~>~~}')
endfunction

function! CMOperator(type, m0, m1, t0, t1)
    " Removed paste mode manipulation for better performance
    " Using setreg() instead to avoid autoindent issues
    let saved_reg = @"

    if a:type ==# 'v' || a:type == 'char'
        silent exe "normal! `" . a:m0 . "v`" . a:m1 . "\"_d"
        call setreg('"', a:t0 . @" . a:t1)
        silent exe "normal! P"
    elseif a:type ==# 'V' || a:type == 'line'
        silent exe "normal! `" . a:m0 . "V`" . a:m1 . "\"_d"
        call setreg('"', a:t0 . "\n" . a:t1)
        silent exe "normal! P"
    endif

    let @" = saved_reg
endfunction

