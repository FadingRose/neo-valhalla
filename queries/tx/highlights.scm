; ~/.config/nvim/queries/tx/highlights.scm

;==============================================================================
;== Keywords and Control Flow
;==============================================================================

"emit" @keyword
(call_type) @keyword.operator                 ; [staticcall], [delegatecall]
(return "←") @keyword.return
(return (return_type) @keyword.return)        ; [Return], [Stop]

;==============================================================================
;== Calls and Events
;==============================================================================

; 分别高亮调用的合约部分和函数部分
(call
  (contract_path) @type
  (function_name) @function)

; 高亮事件名称
(event
  (identifier) @event)

;==============================================================================
;== Literals and Constants
;==============================================================================

(boolean) @constant.builtin                   ; true, false
(number_value) @constant.numeric              ; 12345 or 123 [1.23e2]
(address) @constant.numeric.hex               ; 0x... (40 chars)
(hex_string) @string.escape                   ; 其他 0x... 字符串

;==============================================================================
;== Identifiers, Parameters, and Types
;==============================================================================

; 高亮攻击者标签，使用 text.danger 可以获得醒目的颜色（如红色）
(labeled_address
  (identifier) @text.danger)

; 高亮结构体类型名
(struct (identifier) @type)

; 高亮键值对中的 "键" (参数名)
(key_value_pair
  key: (identifier) @parameter)

; 高亮参数列表中的值。这会给所有参数一个统一的背景色或前景色
; (argument_list (_) @parameter) ; 取消注释以高亮整个参数列表

; 后备规则：任何尚未被其他规则匹配的标识符
(identifier) @variable

;==============================================================================
;== Comments and Metadata
;==============================================================================

(gas) @comment.info                           ; [351363]
(prefix) @comment.meta                        ; │  ├─ 结构符号
(preamble) @comment                           ; 文件头部的元信息
(summary) @comment                            ; 文件尾部的总结

;==============================================================================
;== Punctuation
;==============================================================================

":" @punctuation.delimiter
"," @punctuation.delimiter
"::" @punctuation.special

"(" @punctuation.bracket
")" @punctuation.bracket
; "{" @punctuation.bracket
; "}" @punctuation.bracket
"[" @punctuation.bracket
"]" @punctuation.bracket
