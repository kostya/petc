# MALLOC - Heap Allocation
#
# Allocates count * sizeof(type) bytes via calloc (zero-initialized).
# Pops element count, pushes pointer.
#
# STACK: [count: Int] - [ptr<T>]
#
#   PUSH 10
#   MALLOC :i32             ; ptr<i32> to 10 ints
#   LOCAL :arr :ptr<i32>
#   STORE                   ; arr = calloc(10, 4)
#
#   PUSH 1
#   MALLOC :Point           ; ptr<Point>
#   AS :ptr<void>
#   CALL :free
#
class Myc::Opcode::Malloc < Myc::Opcode
  getter type : Type

  def initialize(@type)
  end
end
