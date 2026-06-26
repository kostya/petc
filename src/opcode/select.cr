# SELECT - Branchless Conditional
#
# Pops condition (Bool), true_val, false_val. Pushes selected value.
# Both values always evaluated - no branching.
#
# STACK: [false_val, true_val, Bool] - [selected]
#
#   PUSH 10
#   PUSH 20
#   PUSH true
#   SELECT                 ; 20
#
#   ; vs IF (needs LOCAL):
#   PUSH true
#   IF
#     THEN PUSH 20 LOCAL :x STORE
#     ELSE PUSH 10 LOCAL :x STORE
#   ENDIF
#   LOCAL :x               ; 20 or 10
#
class Myc::Opcode::Select < Myc::Opcode
end
