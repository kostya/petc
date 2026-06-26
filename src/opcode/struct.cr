# STRUCT - Composite Type Definition
#
# Defines a named type with ordered fields accessed by index (0-based).
#
#   STRUCT :Point
#     TYPE :i32            ; field 0
#     TYPE :i32            ; field 1
#   ENDSTRUCT
#
#   ; Stack usage
#   PUSH 10
#   LOCAL :p :Point
#   FIELD 0
#   STORE                  ; p.x = 10
#
#   ; Heap usage
#   PUSH 1
#   MALLOC :Point
#   LOCAL :p :ptr<Point>
#   STORE
#   PUSH 42
#   LOCAL :p
#   DEREF
#   FIELD 0
#   STORE                  ; p->x = 42
#
#   ; Anonymous struct
#   PUSH 42
#   LOCAL :pair "struct<i32, f64>"
#   FIELD 0
#   STORE
