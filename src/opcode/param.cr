# PARAM - Function Parameter Access
#
# Pushes the value of a function parameter by index (0-based).
# Read-only. Must be inside a FUNC body.
#
# STACK: [] - [param_value]
#
#   FUNC :add RETURN TYPE :i32 ARGS TYPE :i32 TYPE :i32
#   BODY
#     PARAM 1              ; right operand
#     PARAM 0              ; left operand
#     BINARY :add          ; arg0 + arg1
#     RET
#   ENDFUNC
#
class Myc::Opcode::Param < Myc::Opcode
  getter index : Int32

  def initialize(@index)
  end
end
