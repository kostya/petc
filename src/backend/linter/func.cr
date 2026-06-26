class Myc::Backend::Linter::Func < Myc::Backend::AbstractFunc
  def initialize(@builder, @func_def)
    super(@builder, @func_def)
  end

  def new_bb(name : String) : AbstractBB
    BB.new(name, @builder, self, @func_def)
  end

  def new_visitor : AbstractVisitor
    Visitor.new(@builder, self, body_bb, func_def, func_def.mod, params)
  end

  def params : Array(Value)
    @func_def.type_fn.args.map_with_index do |type, index|
      Value.new(BB::FAKE_VAL, type, Value::MM::Val, Value::PP::Param.new(index))
    end
  end

  def build : Hash(Opcode, String)
    v = new_visitor
    v.visit
    v.notes
  end
end
