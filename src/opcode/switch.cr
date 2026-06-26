# SWITCH - Multi-way Branch
#
# Pops an Int index and executes matching CASE branch.
# CASE values are compile-time constants. ELSE branch is optional.
# All branches must leave stack balanced.
#
# STACK: [Int] - []
#
#   LOCAL :opt :Option
#   FIELD 0                  ; tag
#   SWITCH
#     CASE 0
#       PUSH "None"
#       PRINTF 0
#     CASE 1
#       PUSH "Some"
#       PRINTF 0
#     ELSE
#       PUSH "Unknown"
#       PRINTF 0
#   ENDSWITCH
#
class Myc::Opcode::Switch < Myc::Opcode
  getter cases_seq : Array(Seq)
  getter values : Array(Int64)
  property else_seq : Seq

  def initialize(@cases_seq, @values, @else_seq)
  end
end
