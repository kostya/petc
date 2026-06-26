# RET — Return from Function
#
# Exits current function immediately.
# For non-void functions: pops return value from stack.
# For void functions: no stack arguments.
# Type must match function's RETURN type.
#
# STACK: [value] - []   (non-void)
# STACK: [] - []        (void)
#
#   FUNC :add RETURN TYPE :i32 ARGS TYPE :i32 TYPE :i32 BODY
#     PARAM 1 PARAM 0 BINARY :add RET    ; returns sum
#   ENDFUNC
#
#   ; Void function
#   FUNC :greet BODY
#     PUSH "hi\n" PRINTF 0
#     RET                ; returns nothing
#   ENDFUNC
#
#   ; Return from variable
#   LOCAL :x :i32
#   RET                  ; returns x
#
#   ; Early return with value
#   PUSH 0 RET           ; returns 0 immediately
#
class Myc::Opcode::Ret < Myc::Opcode
end
