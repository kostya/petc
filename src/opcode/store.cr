# STORE - Store Value
#
# Writes a value to an l-value (pointer from LOCAL, GLOBAL, FIELD, DEREF).
#
# STACK: [value, l-value] - []
#
#   PUSH 42
#   LOCAL :x :i32
#   STORE                  ; x = 42
#
#   PUSH 42
#   PUSH 2
#   LOCAL :arr :ptr<i32>
#   BINARY :add
#   DEREF
#   STORE                  ; arr[2] = 42
#
#   PUSH 10
#   GLOBAL :counter
#   STORE                  ; counter = 10
#
class Myc::Opcode::Store < Myc::Opcode
end
