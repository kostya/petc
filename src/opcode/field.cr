# FIELD - Struct/Enum/Flat Field Access
#
# Extracts a field by index. Returns l-value (can be stored).
# Works on structs, enums, enum variants, and flat arrays.
#
# STACK: [composite] - [field]
#
#   STRUCT :Point TYPE :i32 TYPE :i32 ENDSTRUCT
#
#   PUSH 10
#   LOCAL :p :Point
#   FIELD 0                ; l-value of p.x
#   STORE                  ; p.x = 10
#
#   LOCAL :p
#   FIELD 1                ; value of p.y
#   LOCAL :x :i32
#   STORE                  ; x = p.y
#
class Myc::Opcode::Field < Myc::Opcode
  getter index : Int32

  def initialize(@index)
  end
end
