class Myc::Backend::Llvm::Func < Myc::Backend::AbstractFunc
  getter link : FuncLink

  def builder
    @builder.as(Builder)
  end

  def initialize(@builder, @func_def)
    @link = builder.func_link(func_def.name, func_def.type_fn)
    func_def.attributes.try &.each do |attr|
      case attr
      when "noinline"
        @link.llvm_function.add_attribute LLVM::Attribute::NoInline
      else
        raise Error::ErrorLoc.new("unknown attr #{attr}", Location.new(func_def.mod.filename, func_def.node.offset))
      end
    end
    super
  end

  def new_bb(name : String) : AbstractBB
    BB.new(name, @builder, self, @func_def)
  end

  def new_visitor : AbstractVisitor
    Visitor.new(@builder, self, body_bb, func_def, func_def.mod, params)
  end

  def finish(v : AbstractVisitor)
    super
    v.fake_bb.as(BB).llvm_bb.delete
  end

  private def params : Array(Value)
    res = Array(Value).new
    link.llvm_function.params.each_with_index do |param, index|
      val = BBVal.new(param)
      type = @func_def.type_fn.args[index]
      res << Value.new(val, type, Value::MM::Val, Value::PP::Param.new(index))
    end
    res
  end
end
