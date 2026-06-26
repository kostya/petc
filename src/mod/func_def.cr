class Myc::Mod::FuncDef
  property node : Source::Node
  property mod : Mod
  property name : String
  property type_fn : Type::Fn
  property body : Opcode::Seq? = nil
  property attributes : Array(String)? = nil

  def initialize(@node, @mod, @name, @type_fn, @attributes = nil)
  end

  def have_ret?
    !type_fn.ret.eq?(mod.typer.void)
  end
end
