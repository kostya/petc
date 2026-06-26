# Seq - Sequence Container (Internal)
#
# Ordered list of opcodes. Used for function bodies, branches, loop sections.
# Not an opcode itself - created automatically by the parser.
#
class Myc::Opcode::Seq < Myc::Opcode
  getter list = Array(Opcode).new
  property stack_balance = 0

  def <<(op : Opcode)
    @list << op
  end

  def <<(ops : Array(Opcode))
    @list += ops
  end
end
