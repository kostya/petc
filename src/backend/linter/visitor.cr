class Myc::Backend::Linter::Visitor < Myc::Backend::AbstractVisitor
  def visit_child(child : Opcode)
    Myc.debug(:visitor) { "visit #{child.inspect}" }
    @current_op = child
    visit(child)
    builder.as(Builder).notes[child] = debug_stack
  end
end
