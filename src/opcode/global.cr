# GLOBAL - Global Variable Definition
#
# Defines a global variable. With INITIAL: definition with value.
# Without INITIAL: external link. CONSTANT flag prevents writes.
#
# STACK: [] - []
#
#   GLOBAL :counter
#     TYPE :i32
#     INITIAL 0
#   ENDGLOBAL
#
#   GLOBAL :version
#     TYPE :i32
#     INITIAL 1
#     CONSTANT
#   ENDGLOBAL
#
#   GLOBAL :errno          ; external, defined elsewhere
#     TYPE :i32
#   ENDGLOBAL
#
#   ; Usage
#   PUSH 42
#   GLOBAL :counter        ; ptr<i32>
#   STORE                  ; counter = 42
#
class Myc::Opcode::Global < Myc::Opcode
  getter name : String

  def initialize(@name)
  end
end
