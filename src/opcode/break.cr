# BREAK - Exit Loop
#
# Immediately exits the innermost enclosing LOOP.
# Error if used outside a loop.
#
# STACK: [] - []
#
#   LOOP
#   COND PUSH true
#   BODY
#     BREAK            ; exit immediately
#   ENDLOOP
#
class Myc::Opcode::Break < Myc::Opcode
end
