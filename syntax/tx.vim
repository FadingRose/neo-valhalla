" Vim syntax file
" Language: .tx (Transaction Trace)
" Maintainer: Your Name <your.email@example.com>
" Last Change: 2023-10-27

if exists("b:current_syntax")
  finish
endif

" Default highlighting groups
" Comment: Comments
" Constant: Numeric constants, boolean constants
" Identifier: Variable names, function names
" Statement: Keywords that denote a statement
" PreProc: Preprocessor directives
" Type: Type definitions
" Special: Special characters or constructs

" Keywords
syn keyword txKeyword Executing Traces emit log_string log_address log_uint log_bytes log_int log_bool log_named_address log_named_uint log_named_bytes log_named_int log_named_bool
syn keyword txKeyword from to value
syn keyword txKeyword Return staticcall delegatecall fallback
syn keyword txKeyword true false

" Special characters/delimiters
syn match txDelimiter /\[/
syn match txDelimiter /\]/
syn match txDelimiter /::/
syn match txDelimiter /(.\{-})/ contains=txHexNumber,txNumber,txAddress,txString,txKeyword
syn match txDelimiter /:/
syn match txDelimiter /├─/
syn match txDelimiter /│/
syn match txDelimiter /└─/
syn match txDelimiter /←/

" Numbers (decimal and hexadecimal)
syn match txNumber /\v\d+(\.\d+)?([eE][+-]?\d+)?/
syn match txHexNumber /\v0x[a-fA-F0-9]+/

" Addresses (0x followed by 40 hex characters)
syn match txAddress /\v0x[a-fA-F0-9]{40}/

" Strings (quoted)
syn region txString start=/"/ end=/"/ contains=txSpecialChar

" Contract/Function names (e.g., `0xaF2Acf3D4ab78e4c702256D214a3189A874CDC13::38f39e5c`)
syn match txContractFunction /\v0x[a-fA-F0-9]{40}::[a-fA-F0-9]+/ display

" Function arguments (e.g., `val:`, `from:`, `to:`)
syn match txFunctionArg /\v\w+:/ display

" Gas values (numbers in square brackets before address/function calls)
syn match txGas /\v\[\d+\]/ display

" Transaction hash (e.g., `[14354266]`)
syn match txTxHash /\v^\[\d+\]/ display

" Comments (lines starting with "Executing" or "Traces")
syn match txComment /^Executing.*/
syn match txComment /^Traces:.*/

" Link highlighting groups to standard Vim groups
hi def link txKeyword Statement
hi def link txDelimiter Special
hi def link txNumber Number
hi def link txHexNumber Number
hi def link txAddress Constant
hi def link txString String
hi def link txContractFunction Function
hi def link txFunctionArg Identifier
hi def link txGas PreProc
hi def link txTxHash PreProc
hi def link txComment Comment

" Set the current syntax
let b:current_syntax = "tx"
