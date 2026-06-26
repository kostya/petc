class Myc::Backend::Llvm::BB < Myc::Backend::AbstractBB
  getter llvm_bb : LLVM::BasicBlock
  getter llvm_builder : LLVM::Builder

  def initialize(@name, @builder, @func, @func_def)
    super

    @llvm_bb = @func.as(Func).link.llvm_function.basic_blocks.append @name
    @llvm_builder = @builder.as(Builder).context.new_builder
    @llvm_builder.position_at_end(@llvm_bb)
  end

  def alloca(name : String, type : Type) : Value
    wrap_ref(@llvm_builder.alloca(llvm_type(type), name), type, Value::PP::LocalUninitialized.new(name))
  end

  def load_ref(value : Value) : Value
    wrap_val(@llvm_builder.load(llvm_type(value), llvm_val(value)), value.type, value.pp)
  end

  def jmp(other : AbstractBB)
    return if @dead_end

    @llvm_builder.br(other.as(BB).llvm_bb)
    @dead_end = true
  end

  def ret(val : Value?)
    return if @dead_end

    if val
      @llvm_builder.ret(llvm_val(val))
    else
      @llvm_builder.ret
    end
    @dead_end = true
  end

  def call(name : String, type_fn : Type::Fn, args : Array(Value)) : Value?
    return if @dead_end

    link = builder.func_link(name, type_fn)
    vals = args.map { |arg| llvm_val(arg) }
    val = @llvm_builder.call(link.llvm_type, link.llvm_function, vals)
    unless type_fn.ret.eq?(func_def.mod.typer.void)
      wrap_val(val, type_fn.ret, Value::PP::CallResult.new(name))
    end
  end

  def cond(cond : Value, then_bb : AbstractBB, else_bb : AbstractBB)
    return if @dead_end

    @llvm_builder.cond(llvm_val(cond), then_bb.as(BB).llvm_bb, else_bb.as(BB).llvm_bb)
    @dead_end = true
  end

  def next(name : String) : AbstractBB
    BB.new(name, builder, @func, @func_def)
  end

  def select(cond : Value, arg_true : Value, arg_false : Value) : Value
    val = @llvm_builder.select(llvm_val(cond), llvm_val(arg_true), llvm_val(arg_false))
    wrap_val(val, arg_true.type, arg_true.pp)
  end

  def store(lhs : Value, rhs : Value)
    return if @dead_end
    @llvm_builder.store(llvm_val(rhs), llvm_val(lhs))
  end

  def binary(op : Opcode::Binary::Op, lhs : Value, rhs : Value) : Value?
    return if @dead_end

    ltype = lhs.type
    l = llvm_val(lhs)
    r = llvm_val(rhs)

    case op
    in .add?
      case ltype
      when Type::IntType
        wrap_res(@llvm_builder.add(l, r), ltype, lhs.pp)
      when Type::FloatType
        wrap_res(@llvm_builder.fadd(l, r), ltype, lhs.pp)
      end
    in .sub?
      case ltype
      when Type::IntType
        wrap_res(@llvm_builder.sub(l, r), ltype, lhs.pp)
      when Type::FloatType
        wrap_res(@llvm_builder.fsub(l, r), ltype, lhs.pp)
      end
    in .mul?
      case ltype
      when Type::IntType
        wrap_res(@llvm_builder.mul(l, r), ltype, lhs.pp)
      when Type::FloatType
        wrap_res(@llvm_builder.fmul(l, r), ltype, lhs.pp)
      end
    in .div?
      case t = ltype
      when Type::IntType
        if t.signed
          wrap_res(@llvm_builder.sdiv(l, r), ltype, lhs.pp)
        else
          wrap_res(@llvm_builder.udiv(l, r), ltype, lhs.pp)
        end
      when Type::FloatType
        wrap_res(@llvm_builder.fdiv(l, r), ltype, lhs.pp)
      end
    in .rem?
      case t = ltype
      when Type::IntType
        if t.signed
          wrap_res(@llvm_builder.srem(l, r), ltype, lhs.pp)
        else
          wrap_res(@llvm_builder.urem(l, r), ltype, lhs.pp)
        end
      end
    in .and?
      case ltype
      when Type::IntType, Type::BoolType
        wrap_res(@llvm_builder.and(l, r), ltype, lhs.pp)
      end
    in .or?
      case ltype
      when Type::IntType, Type::BoolType
        wrap_res(@llvm_builder.or(l, r), ltype, lhs.pp)
      end
    in .xor?
      case ltype
      when Type::IntType, Type::BoolType
        wrap_res(@llvm_builder.xor(l, r), ltype, lhs.pp)
      end
    in .shl?
      case ltype
      when Type::IntType, Type::BoolType
        wrap_res(@llvm_builder.shl(l, r), ltype, lhs.pp)
      end
    in .l_shr?
      case ltype
      when Type::IntType, Type::BoolType
        wrap_res(@llvm_builder.lshr(l, r), ltype, lhs.pp)
      end
    in .a_shr?
      case ltype
      when Type::IntType, Type::BoolType
        wrap_res(@llvm_builder.ashr(l, r), ltype, lhs.pp)
      end
    in .eq?
      case ltype
      when Type::IntType, Type::BoolType
        wrap_res(@llvm_builder.icmp(LLVM::IntPredicate::EQ, l, r), typer.bool, lhs.pp)
      when Type::PtrType
        wrap_res(@llvm_builder.icmp(LLVM::IntPredicate::EQ, l, r), typer.bool, lhs.pp)
      when Type::FloatType
        wrap_res(@llvm_builder.fcmp(LLVM::RealPredicate::OEQ, l, r), typer.bool, lhs.pp)
      end
    in .not_eq?
      case ltype
      when Type::IntType, Type::BoolType
        wrap_res(@llvm_builder.icmp(LLVM::IntPredicate::NE, l, r), typer.bool, lhs.pp)
      when Type::PtrType
        wrap_res(@llvm_builder.icmp(LLVM::IntPredicate::NE, l, r), typer.bool, lhs.pp)
      when Type::FloatType
        wrap_res(@llvm_builder.fcmp(LLVM::RealPredicate::ONE, l, r), typer.bool, lhs.pp)
      end
    in .less?
      case t = ltype
      when Type::IntType
        pred = t.signed ? LLVM::IntPredicate::SLT : LLVM::IntPredicate::ULT
        wrap_res(@llvm_builder.icmp(pred, l, r), typer.bool, lhs.pp)
      when Type::FloatType
        wrap_res(@llvm_builder.fcmp(LLVM::RealPredicate::OLT, l, r), typer.bool, lhs.pp)
      end
    in .less_eq?
      case t = ltype
      when Type::IntType
        pred = t.signed ? LLVM::IntPredicate::SLE : LLVM::IntPredicate::ULE
        wrap_res(@llvm_builder.icmp(pred, l, r), typer.bool, lhs.pp)
      when Type::FloatType
        wrap_res(@llvm_builder.fcmp(LLVM::RealPredicate::OLE, l, r), typer.bool, lhs.pp)
      end
    in .more?
      case t = ltype
      when Type::IntType
        pred = t.signed ? LLVM::IntPredicate::SGT : LLVM::IntPredicate::UGT
        wrap_res(@llvm_builder.icmp(pred, l, r), typer.bool, lhs.pp)
      when Type::FloatType
        wrap_res(@llvm_builder.fcmp(LLVM::RealPredicate::OGT, l, r), typer.bool, lhs.pp)
      end
    in .more_eq?
      case t = ltype
      when Type::IntType
        pred = t.signed ? LLVM::IntPredicate::SGE : LLVM::IntPredicate::UGE
        wrap_res(@llvm_builder.icmp(pred, l, r), typer.bool, lhs.pp)
      when Type::FloatType
        wrap_res(@llvm_builder.fcmp(LLVM::RealPredicate::OGE, l, r), typer.bool, lhs.pp)
      end
    end
  end

  def unary(op : Opcode::Unary::Op, rhs : Value) : Value?
    return if @dead_end

    v = llvm_val(rhs)
    t = rhs.type

    case op
    in .lnot?
      case rhs.type
      when Type::IntType, Type::BoolType
        is_zero = @llvm_builder.icmp(LLVM::IntPredicate::EQ, v, builder.context.int32.const_int(0))
        wrap_res(@llvm_builder.zext(is_zero, llvm_type(rhs.type)), t, rhs.pp)
      end
    in .bnot?
      case rhs.type
      when Type::IntType
        wrap_res(@llvm_builder.not(v), t, rhs.pp)
      end
    in .neg?
      case rhs.type
      when Type::IntType
        wrap_res(@llvm_builder.neg(v), t, rhs.pp)
      when Type::FloatType
        wrap_res(@llvm_builder.fneg(v), t, rhs.pp)
      end
    end
  end

  def switch(index : Value, case_values : Array(Value), case_bbs : Array(AbstractBB), default_bb : AbstractBB)
    return if @dead_end

    case_map = {} of LLVM::Value => LLVM::BasicBlock
    case_values.each_with_index do |val, i|
      case_map[llvm_val(val)] = case_bbs[i].as(BB).llvm_bb
    end
    @llvm_builder.switch(llvm_val(index), default_bb.as(BB).llvm_bb, case_map)
    @dead_end = true
  end

  def cast?(value : Value, from_type : Type, to_type : Type) : Value?
    v = llvm_val(value)
    tt = llvm_type(to_type)

    case {from_type, to_type}
    when {Type::IntType, Type::IntType}
      from_size = from_type.bytes_count
      to_size = to_type.bytes_count

      val = if to_size == from_size
              v
            elsif to_size > from_size
              if from_type.signed && to_type.signed
                @llvm_builder.sext(v, tt)
              else
                @llvm_builder.zext(v, tt)
              end
            else
              @llvm_builder.trunc(v, tt)
            end
      wrap_res(val, to_type, value.pp)
    when {Type::IntType, Type::FloatType}
      val = if from_type.signed
              @llvm_builder.si2fp(v, tt)
            else
              @llvm_builder.ui2fp(v, tt)
            end
      wrap_res(val, to_type, value.pp)
    when {Type::FloatType, Type::IntType}
      val = if to_type.signed
              @llvm_builder.fp2si(v, tt)
            else
              @llvm_builder.fp2ui(v, tt)
            end
      wrap_res(val, to_type, value.pp)
    when {Type::FloatType, Type::FloatType}
      val = if to_type.bytes_count > from_type.bytes_count
              @llvm_builder.fpext(v, tt)
            else
              @llvm_builder.fptrunc(v, tt)
            end
      wrap_res(val, to_type, value.pp)
    when {Type::BoolType, Type::IntType}
      val = @llvm_builder.zext(v, tt)
      wrap_res(val, to_type, value.pp)
    when {Type::IntType, Type::BoolType}
      cmp = @llvm_builder.icmp(LLVM::IntPredicate::NE, v, builder.context.int32.const_int(0))
      val = @llvm_builder.zext(cmp, tt)
      wrap_res(val, to_type, value.pp)
    when {Type::FloatType, Type::BoolType}
      cmp = @llvm_builder.fcmp(LLVM::RealPredicate::ONE, v, builder.context.double.const_float(0))
      val = @llvm_builder.zext(cmp, tt)
      wrap_res(val, to_type, value.pp)
    when {Type::PtrType, Type::PtrType}
      wrap_res(v, to_type, value.pp)
    when {Type::IntType, Type::PtrType}
      val = @llvm_builder.int2ptr(v, tt)
      wrap_res(val, to_type, value.pp)
    when {Type::PtrType, Type::IntType}
      val = @llvm_builder.ptr2int(v, tt)
      wrap_res(val, to_type, value.pp)
    end
  end

  def to?(value : Value, from_type : Type, to_type : Type) : Value?
    v = llvm_val(value)
    tt = llvm_type(to_type)

    case {from_type, to_type}
    when {Type::IntType, Type::IntType}
      from_size = from_type.bytes_count
      to_size = to_type.bytes_count

      if to_size >= from_size
        val = if from_type.signed
                @llvm_builder.sext(v, tt)
              else
                @llvm_builder.zext(v, tt)
              end
        wrap_res(val, to_type, value.pp)
      end
    when {Type::IntType, Type::FloatType}
      val = if from_type.signed
              @llvm_builder.si2fp(v, tt)
            else
              @llvm_builder.ui2fp(v, tt)
            end
      wrap_res(val, to_type, value.pp)
    when {Type::FloatType, Type::FloatType}
      if to_type.bytes_count >= from_type.bytes_count
        val = @llvm_builder.fpext(v, tt)
        wrap_res(val, to_type, value.pp)
      end
    when {Type::PtrType, Type::PtrType}
      if to_type.target_type.is_a?(Type::VoidType)
        wrap_res(v, to_type, value.pp)
      end
    end
  end

  def field(value : Value, field_type : Type, offset : Int32) : Value
    gep = @llvm_builder.inbounds_gep(llvm_type(value.type), llvm_val(value), builder.context.int32.const_int(0), builder.context.int32.const_int(offset))
    wrap_ref(gep, field_type, value.pp)
  end

  def extract_value(value : Value, field_type : Type, offset : Int32) : Value
    val = @llvm_builder.extract_value(llvm_val(value), offset.to_u32)
    wrap_val(val, field_type, value.pp)
  end

  def deref(value : Value, target_type : Type) : Value
    wrap_ref(llvm_val(value), target_type, value.pp)
  end

  def addr(value : Value, ptr_type : Type) : Value
    wrap_val(llvm_val(value), ptr_type, value.pp)
  end

  def offset(value : Value, target_type : Type, offset : Value) : Value
    gep = @llvm_builder.inbounds_gep(llvm_type(target_type), llvm_val(value), llvm_val(offset))
    wrap_val(gep, value.type, value.pp)
  end

  def bitcast(value : Value, to_type : Type) : Value
    wrap_ref(llvm_val(value), to_type, value.pp)
  end

  # ------------------------- Helpers ---------------------------------------

  private def builder
    @builder.as(Builder)
  end

  private def llvm_val(value : Value) : LLVM::Value
    value.bbval.as(BBVal).llvm
  end

  private def llvm_type(value : Value) : LLVM::Type
    llvm_type(value.type)
  end

  private def llvm_type(t : Type) : LLVM::Type
    builder.llvm_type(t)
  end

  private def wrap_val(llvm : LLVM::Value, type : Type, pp : Value::PP) : Value
    Value.new(BBVal.new(llvm), type, Value::MM::Val, pp)
  end

  private def wrap_ref(llvm : LLVM::Value, type : Type, pp : Value::PP) : Value
    Value.new(BBVal.new(llvm), type, Value::MM::Ref, pp)
  end

  private def wrap_res(llvm : LLVM::Value, type : Type, pp : Value::PP) : Value
    wrap_val(llvm, type, pp)
  end

  private def typer : Mod::Typer
    @func_def.mod.typer
  end
end
