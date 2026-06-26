# AS - Type Cast
#
# Converts top of stack to the given type.
# Supported:
#   Int-Int, Int-Float, Float-Float, Float-Int,
#   Bool-Int, Int,Float-Bool,
#   Ptr-Ptr, Ptr-Int, Flat-any,
#   Enum-Variant, Variant-Enum.
#
# STACK: [value] - [value as TYPE]
#
#   PUSH 1.5      ; f64
#   AS :i32       ; 1
#
#   PUSH 42       ; i32
#   AS :f64       ; 42.0
#
#   PUSH true     ; bool
#   AS :i32       ; 1
#
#   LOCAL :var :Option
#   AS :Option::Some  ; variant access
#
class Myc::Opcode::As < Myc::Opcode
  getter type : Type

  def initialize(@type)
  end
end
