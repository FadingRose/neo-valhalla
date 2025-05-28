" Vim syntax file
" Language: .tx (Transaction Trace)
" Maintainer: Your Name <your.email@example.com>
" Last Change: 2023-12-01

if exists("b:current_syntax")
  finish
endif

" Reset all syntax items in buffer
syntax clear

" Core components
syn match txBlockNumber /^  \[\d\+\]/
syn match txGasUsage /\[\d\+\]/ containedin=txCall
syn match txFunctionName /::\w\+/ contains=txDoubleColon
syn match txDoubleColon /::/
syn match txArrow /└─\|├─\|←/

" Contracts and addresses
syn match txContractAddress /\v0x[a-fA-F0-9]{40}/ display
syn match txContractName /<\S*>/
syn match txProxyType /\(Transparent\)\?UpgradeableProxy\|Proxy\>/

" Function calls
syn region txCall start=/├─ \[\d\+\] \S\+/ end=/)$/ contains=txGasUsage,txContractAddress,txFunctionName,txHexData
syn match txStaticCall /\[staticcall\]/
syn match txDelegateCall /\[delegatecall\]/
syn match txFallback /\[fallback\]/
syn match txReturn /\[Return\]/

" Log events
syn match txLogEmit /^\s*├─ emit/ nextgroup=txLogType
syn match txLogType /log_\w\+/ contained
syn match txLogValue /val:/ contained

" Hex data
syn match txHexData /\v0x[a-fA-F0-9]{32,}/
syn match txHexNumber /\v0x[a-fA-F0-9]+/ containedin=txNumber

" Numbers (decimal and scientific)
syn match txNumber /\v<\d+>/
syn match txNumber /\v<\d+\.\d+>/
syn match txNumber /\v<\d+([eE][+-]?\d+)?>/
syn match txNumber /\v\[\d+\]/

" Comments and headers
syn match txComment /^Executing.*/
syn match txComment /^Traces:.*/
syn match txCommentLine /\/\/ .*/

" Error states
syn match txError /<reverted>/

" Special cases
syn match txNamedParameter /\v\w+: ?/ display
syn match txScientificNotation /\v\[[0-9.e+-]+\]/ contains=txNumber

" Highlighting links
" Structural
hi def link txBlockNumber Special
hi def link txGasUsage Number
hi def link txDoubleColon Operator
hi def link txArrow Special

" Contracts
hi def link txContractAddress Constant
hi def link txContractName Type
hi def link txProxyType Type

" Calls
hi def link txCall PreProc
hi def link txStaticCall Keyword
hi def link txDelegateCall Keyword
hi def link txFallback Keyword
hi def link txReturn Keyword

" Logs
hi def link txLogEmit Statement
hi def link txLogType Function
hi def link txLogValue Identifier

" Data
hi def link txHexData String
hi def link txHexNumber Number

" Numbers
hi def link txNumber Number

" Comments
hi def link txComment Comment
hi def link txCommentLine Comment

" Errors
hi def link txError Error

" Parameters
hi def link txNamedParameter Identifier
hi def link txScientificNotation Number

" Special cases
hi def link txFunctionName Function



" Set the current syntax
let b:current_syntax = "tx"
