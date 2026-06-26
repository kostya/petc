# PRINTF - Formatted Print
#
# Calls printf(format, args...). Pops format string then N args.
# Args popped in order: last pushed = last format arg.
#
# STACK: [argN, ..., arg0, format: ptr<u8>] - []
#
#   PUSH 42
#   PUSH "Hello %d\n"
#   PRINTF 1               ; Hello 42
#
#   PUSH 5
#   PUSH 2
#   PUSH 3
#   PUSH "%d + %d = %d\n"
#   PRINTF 3               ; 3 + 2 = 5
#
class Myc::Opcode::Printf < Myc::Opcode
  getter args_count : Int32

  def initialize(@args_count)
  end
end
