# SIZEOF - Size of Type
#
# Pushes the size in bytes of the given type onto the stack.
# Works with any type including primitives, pointers, and structs.
# If no type argument is given, pops a value from the stack and
# pushes its size instead.
#
# With type argument:
#   STACK: [] - [Int]
#
#   SIZEOF :i32       ; pushes 4
#   SIZEOF :f64       ; pushes 8
#   SIZEOF :u8        ; pushes 1
#   SIZEOF :ptr<i32>  ; pushes 8 (pointer size)
#   SIZEOF :Point     ; pushes size of struct Point
#
# Without type argument (dynamic):
#   STACK: [value] - [Int]
#
#   PUSH 42 :i32
#   SIZEOF            ; pops 42, pushes 4 (size of i32)
#
#   LOCAL :p :ptr<u8>
#   SIZEOF            ; pops ptr, pushes 8 (pointer size)
#
# Example with malloc:
#   PUSH 5 :i32
#   SIZEOF :i32
#   BINARY :mul       ; 5 * sizeof(i32) = 20
#   CALL :malloc      ; allocate 20 bytes
#   AS :ptr<i32>      ; cast void* to int*
#
class Myc::Opcode::SizeOf < Myc::Opcode
  getter type : Type?

  def initialize(@type = nil)
  end
end
