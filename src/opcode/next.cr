# NEXT - Continue Loop
#
# Jumps to STEP (or COND if no STEP) of the innermost LOOP.
# Must be inside a LOOP BODY.
#
# STACK: [] - []
#
#   LOOP
#   COND PUSH true
#   BODY
#     NEXT                  ; skip rest, go to STEP
#   STEP
#     ; ...
#   ENDLOOP
#
class Myc::Opcode::Next < Myc::Opcode
end
