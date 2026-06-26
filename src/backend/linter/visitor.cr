class Myc::Backend::Linter::Visitor < Myc::Backend::AbstractVisitor
  property notes = Hash(Opcode, String).new

  def visit_child(child : Opcode)
    Stats.debug(:visitor) { "visit #{child.inspect}" }
    @current_op = child
    visit(child)
    notes[child] = debug_stack
  end
end
