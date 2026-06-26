# ADDR - Address Of Local Variable
#
# Takes the address of a local variable (Alloca).
# Global and Field are already pointers - ADDR not needed.
#
# STACK: [Alloca] - [ptr<T>]
#
#   LOCAL :x :i32
#   ADDR                 ; ptr<i32>
#   CALL :increment      ; increment(&x)
#
#   LOCAL :x :i32
#   ADDR                 ; ptr<i32>
#   DEREF                ; i32 (lvalue for store)
#   STORE                ; *ptr = ...
#
class Myc::Opcode::Addr < Myc::Opcode
end
