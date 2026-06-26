# CREATE - Construct Composite Value
#
# Pops fields from stack and constructs a struct, enum variant, or flat.
# For enum variants, tag is set automatically.
#
# STACK: [fieldN, ..., field0] - [composite]
#
#   PUSH 20
#   PUSH 10
#   CREATE :Point              ; Point(10, 20)
#
#   PUSH true
#   PUSH 1.5
#   CREATE "struct<f64, bool>" ; struct<f64, bool>(1.5000000, true)
#
#   PUSH 42
#   CREATE :Option::Some       ; Option::Some(42)
#
#   PUSH 3
#   PUSH 2
#   PUSH 1
#   CREATE "flat<i32, 3>"      ; flat<i32, 3>(1, 2, 3)
#
class Myc::Opcode::Create < Myc::Opcode
  getter type : Type

  def initialize(@type)
  end
end
