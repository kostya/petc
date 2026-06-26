# UNARY - Unary Operation
#
# Pops one value, performs operation, pushes result.
#
# STACK: [value] - [result]
#
#   :lnot  - Logical NOT (!)
#            Int-Int: 0 -> 1, !=0 -> 0
#            Bool-Bool: true -> false, false -> true
#            Example: PUSH 1, UNARY :lnot -> 0
#                     PUSH 0, UNARY :lnot -> 1
#
#   :bnot  - Bitwise NOT (~)
#            Int-Int: inverts all bits
#            Example: PUSH 1, UNARY :bnot -> -2
#                     PUSH 0, UNARY :bnot -> -1
#
#   :neg   - Arithmetic negation (-)
#            Int-Int: negates value
#            Float-Float: negates value
#            Example: PUSH 42, UNARY :neg -> -42
#                     PUSH 3.14, UNARY :neg -> -3.14
#
# Examples:
#
#   PUSH true
#   UNARY :lnot             ; false
#
#   PUSH 42
#   UNARY :neg              ; -42
#
#   PUSH 1
#   UNARY :bnot             ; -2
#
#   PUSH 5
#   UNARY :lnot             ; 0
#
class Myc::Opcode::Unary < Myc::Opcode
  enum Op
    Lnot
    Bnot
    Neg
  end

  getter op : Op

  def initialize(@op)
  end
end
