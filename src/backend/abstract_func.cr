abstract class Myc::Backend::AbstractFunc
  getter builder : AbstractBuilder
  getter func_def : Mod::FuncDef

  getter! alloca_bb : AbstractBB?
  getter! body_bb : AbstractBB?
  getter! ret_bb : AbstractBB?
  getter result : Value?

  def initialize(@builder, @func_def)
    @alloca_bb = new_bb("alloca")
    @body_bb = new_bb("body")
    @ret_bb = new_bb("ret")

    if func_def.have_ret?
      name = "__myc_result"
      @result = res = alloca_bb.alloca(name, func_def.type_fn.ret)
      res.pp = Value::PP::Local.new(name)
    end
  end

  def build
    v = new_visitor
    v.visit
    finish(v)
  end

  private def finish(v : AbstractVisitor)
    alloca_bb.jmp(body_bb)
    v.bb.jmp(ret_bb)
    v.bb = ret_bb
    ret_bb.ret(result.try &.to_rhs(v))
  end

  abstract def new_bb(name : String) : AbstractBB
  abstract def new_visitor : AbstractVisitor
end
