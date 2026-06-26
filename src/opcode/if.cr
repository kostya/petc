# IF - Conditional Branch
#
# Pops a Bool condition. Executes THEN if true, ELSE if false.
# Both branches must leave stack balanced.
#
# STACK: [Bool] - []
#
#   PUSH 5
#   PUSH 10
#   BINARY :less     ; 10 < 5? - false
#   IF
#     THEN
#       PUSH "yes"
#       PRINTF 0
#     ELSE
#       PUSH "no"
#       PRINTF 0
#   ENDIF
#
class Myc::Opcode::If < Myc::Opcode
  property then_seq : Seq
  property else_seq : Seq

  def initialize(@then_seq, @else_seq)
  end
end
