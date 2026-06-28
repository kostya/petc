# INSPECT - Debug Print Stack Top
#
# Pops and prints the top value in human-readable format.
# All types supported. Use STACK :dup to keep value.
#
# STACK: [value] - []
#
#   PUSH 42
#   INSPECT                      ; prints "42"
#
#   PUSH 42
#   STACK :dup
#   INSPECT                      ; prints "42", stack: [42]
#
#   PUSH 20
#   PUSH 10
#   BINARY :add                  ; 10 + 20
#   INSPECT                      ; prints "30"
#
#   PUSH true
#   PUSH 1.5
#   CREATE "struct<f64, bool>"
#   INSPECT                      ; struct<f64, bool>(1.5, true)
class Myc::Opcode::Inspect < Myc::Opcode
  getter internal : Bool

  def initialize(@internal = false)
  end
end
