# CALL - Function Call
#
# Calls a function. Arguments are popped from stack in order:
# first pushed = last argument, last pushed = first argument.
# Pushes return value if function returns non-void.
# Supports variadic functions (vaargs after declared args).
#
# STACK: [argN, ..., arg1, arg0] - [retval?]
#
#   PUSH 20      ; arg1
#   PUSH 10      ; arg0
#   CALL :add    ; add(10, 20)
#
class Myc::Opcode::Call < Myc::Opcode
  getter name : String
  getter vaargs_count : Int32

  def initialize(@name, @vaargs_count = 0)
  end
end
