# LABEL - Jump Target
#
# *** NOT RECOMMENDED FOR DIRECT USE ***
# Prefer high-level constructs (IF, LOOP, SWITCH) when writing IR manually.
# GOTO/LABEL exist for compiler-generated code and inlining only.
#
# Marks a location that GOTO can jump to.
# Must be unique within the function.
#
# STACK: [] - []
#
#   GOTO :done
#   ; ...
#   LABEL :done
#   RET
#
class Myc::Opcode::Label < Myc::Opcode
  getter label : String

  def initialize(@label)
  end
end
