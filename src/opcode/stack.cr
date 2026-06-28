# STACK - Stack Manipulation
#
# Reorders values on the stack without changing them.
# First pushed = bottom, last pushed = top.
#
# STACK effects:
#
#   :swap2    [a, b] - [b, a]
#   :dup      [a] - [a, a]
#   :drop     [a] - []         (or :drop N - pop N values)
#   :over     [a, b] - [a, b, a]
#   :rot      [a, b, c] - [b, c, a]
#   :nrot     [a, b, c] - [c, a, b]
#   :dup2     [a, b] - [a, b, a, b]
#   :drop2    [a, b] - []
#
#   PUSH 10
#   PUSH 20
#   STACK :swap2           ; 10, 20
#
#   PUSH 42
#   STACK :dup             ; 42, 42
#   INSPECT                ; prints 42, stack: [42]
#
class Myc::Opcode::Stack < Myc::Opcode
  enum Shift
    Swap2
    Dup
    Drop
    Over
    Rot
    Nrot
    Dup2
    Drop2
  end

  getter shift : Shift
  getter val : Int64?

  def initialize(@shift, @val = nil)
  end
end
