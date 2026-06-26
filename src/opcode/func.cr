# FUNC - Function Definition
#
# Defines a function with optional return type, arguments, attributes, and body.
# Without BODY: external link (C function, other module).
# With empty BODY: no-op function.
#
# STACK: caller pushes args, callee pops via PARAM
#
#   ; Definition
#   FUNC :add
#     RETURN TYPE :i32
#     ARGS TYPE :i32 TYPE :i32
#     BODY
#       PARAM 0
#       PARAM 1
#       BINARY :add
#       RET
#   ENDFUNC
#
#   ; External link (no BODY)
#   FUNC :printf RETURN TYPE :i32 ARGS TYPE :ptr<u8> ENDFUNC
#
#   ; Variadic
#   FUNC :printf RETURN TYPE :i32 ARGS TYPE :ptr<u8> ATTRIBUTES ATTR :vaarg ENDFUNC
#
#   ; Calling
#   PUSH 20      ; arg1
#   PUSH 10      ; arg0
#   CALL :add    ; add(10, 20)
#
