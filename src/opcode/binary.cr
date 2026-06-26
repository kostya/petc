# BINARY - Binary Operation
#
# Pops two values, performs the operation, pushes result.
# First popped = RIGHT operand, second popped = LEFT operand.
#
# STACK: [right, left] - [result]
#
#   PUSH 10      ; right
#   PUSH 5       ; left
#   BINARY :less ; 5 < 10 = true
#
#   PUSH 3       ; right
#   PUSH 2       ; left
#   BINARY :sub  ; 2 - 3 = -1
#
# Operations: add, sub, mul, div, rem (Int/Float)
#             and, or, xor, shl, lshr, ashr (Int/Bool)
#             eq, not_eq, less, less_eq, more, more_eq - Bool
#
#
# Pointer arithmetic:
#   When left is ptr<T> and right is Int, :add and :sub perform
#   pointer arithmetic. The Int is automatically multiplied by
#   sizeof(T) before the operation.
#
#   PUSH 3 :i32           ; right (index)
#   LOCAL :arr :ptr<i32>  ; left (pointer)
#   BINARY :add           ; ptr = arr + 3 * sizeof(i32)
#
#   PUSH 1 :i32           ; right
#   LOCAL :p :ptr<u8>     ; left
#   BINARY :sub           ; ptr = p - 1 * sizeof(u8)
#
class Myc::Opcode::Binary < Myc::Opcode
  enum Op
    Add
    Sub
    Mul
    Div
    Rem

    And
    Or
    Xor
    Shl
    LShr
    AShr

    Eq
    NotEq
    Less
    LessEq
    More
    MoreEq
  end

  getter op : Op

  def initialize(@op)
  end
end
