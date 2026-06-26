# LOOP - Structured Loop
#
# INIT (once) - COND - BODY - STEP - COND ...
# COND must push Bool.
# BREAK exits, NEXT jumps to STEP.
#
# STACK: balanced within each section
#
#   ; for i = 0; i < 10; i++
#   LOOP
#     INIT
#       PUSH 0
#       LOCAL :i :i32
#       STORE              ; i = 0
#     COND
#       PUSH 10
#       LOCAL :i
#       BINARY :less       ; i < 10
#     BODY
#       LOCAL :i
#       PUSH "got %d\n"
#       PRINTF 1
#     STEP
#       PUSH 1
#       LOCAL :i
#       BINARY :add
#       LOCAL :i
#       STORE              ; i = i + 1
#   ENDLOOP
#
#   ; while true
#   LOOP COND PUSH true BODY BREAK ENDLOOP
#
class Myc::Opcode::Loop < Myc::Opcode
  property init_seq : Seq
  property cond_seq : Seq
  property body_seq : Seq
  property step_seq : Seq

  def initialize(@init_seq, @cond_seq, @body_seq, @step_seq)
  end
end
