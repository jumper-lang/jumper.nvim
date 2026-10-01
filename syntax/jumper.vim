" Jumper syntax: Java-like, plus `dyn` and the keys of table literals `{ key: v }`.
" The base coloring, before and besides the language server's semantic tokens (jmp --lsp), which then
" tell parameters, fields, methods, host globals and built-ins apart.
if exists('b:current_syntax') | finish | endif

syn keyword jumperConditional if else switch
syn keyword jumperRepeat      while for do
syn keyword jumperStatement   return break continue
syn keyword jumperLabel       case default
syn keyword jumperException   try catch finally throw
syn keyword jumperType        dyn int long double boolean void
syn keyword jumperStorage     static
syn keyword jumperStructure   class extends
syn keyword jumperOperatorKw  new
syn keyword jumperConstant    true false null
syn keyword jumperThis        this super
syn keyword jumperInclude     import nextgroup=jumperPackage skipwhite
syn match   jumperPackage     contained '\h\w*\%(\.\h\w*\)*'

" classes: capitalized names (String, HashMap, Point); ALL_CAPS are constants
syn match   jumperClass       '\<\u\w*\l\w*\>\|\<\u\>'
syn match   jumperClassDecl   '\%(\<class\s\+\)\@<=\h\w*'
" calls, then declarations (a later match wins where two start at the same place)
syn match   jumperCall        '\<\h\w*\ze\s*('
syn match   jumperFuncDecl    '\%(\<\%(dyn\|int\|long\|double\|boolean\|void\|String\|\u\w*\)\s\+\)\@<=\h\w*\ze\s*('
syn match   jumperNewClass    '\%(\<new\s\+\)\@<=\h\w*\%(\.\h\w*\)*'
syn match   jumperMember      '\.\@<=\s*\h\w*' contains=NONE
syn match   jumperMethod      '\.\@<=\s*\h\w*\ze\s*('
" table literals: `{ key: v, other: w }` - a name after `{` or `,` (or at a line start) before `:`
syn match   jumperTableKey    '\%(\%([{,]\s*\)\@<=\|^\s*\)\%(case\>\|default\>\)\@!\h\w*\ze\s*:'

syn match   jumperNumber      '\<0[xX]\x\+[lL]\=\>'
syn match   jumperNumber      '\<\d\+\%(\.\d\+\)\=\%([eE][+-]\=\d\+\)\=[lL]\=\>'
syn match   jumperEscape      contained '\\\%(u\x\{4}\|.\)'
syn region  jumperString      start=+"+ skip=+\\\\\|\\"+ end=+"+ end=+$+ contains=jumperEscape
syn region  jumperString      start=+'+ skip=+\\\\\|\\'+ end=+'+ end=+$+ contains=jumperEscape
syn keyword jumperTodo        contained TODO FIXME XXX NOTE
syn region  jumperComment     start='//' end='$' contains=jumperTodo,@Spell
syn region  jumperComment     start='/\*' end='\*/' contains=jumperTodo,@Spell
syn match   jumperArrow       '->'

hi def link jumperConditional Conditional
hi def link jumperRepeat      Repeat
hi def link jumperStatement   Statement
hi def link jumperLabel       Label
hi def link jumperException   Exception
hi def link jumperType        Type
hi def link jumperStorage     StorageClass
hi def link jumperStructure   Structure
hi def link jumperOperatorKw  Keyword
hi def link jumperConstant    Constant
hi def link jumperThis        Special
hi def link jumperInclude     Include
hi def link jumperPackage     Identifier
hi def link jumperClass       Type
hi def link jumperClassDecl   Type
hi def link jumperNewClass    Type
hi def link jumperFuncDecl    Function
hi def link jumperCall        Function
hi def link jumperMethod      Function
hi def link jumperMember      Identifier
hi def link jumperTableKey    Identifier
hi def link jumperNumber      Number
hi def link jumperString      String
hi def link jumperEscape      SpecialChar
hi def link jumperComment     Comment
hi def link jumperTodo        Todo
hi def link jumperArrow       Operator

let b:current_syntax = 'jumper'
