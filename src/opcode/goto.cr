# GOTO - Unconditional Jump
#
# *** NOT RECOMMENDED FOR DIRECT USE ***
# Prefer high-level constructs (IF, LOOP, SWITCH) when writing IR manually.
# GOTO/LABEL exist for compiler-generated code and inlining only.
#
# Jumps to a label within the same function.
# Must target a LABEL inside the current function.
#
# STACK: [] - []
#
#   GOTO :cleanup
#   ; ...
#   LABEL :cleanup
#   RET
#
class Myc::Opcode::Goto < Myc::Opcode
  getter label : String

  def initialize(@label)
  end
end
