class Myc::Backend::Linter::BB < Myc::Backend::AbstractBB
  FAKE_VAL = BBVal.new

  def alloca(name : String, type : Type) : Value
    wrap_ref(FAKE_VAL, type, Value::PP::LocalUninitialized.new(name))
  end

  def load_ref(value : Value) : Value
    wrap_val(FAKE_VAL, value.type, value.pp)
  end

  def jmp(other : AbstractBB)
  end

  def ret(val : Value?)
  end

  def call(name : String, type_fn : Type::Fn, args : Array(Value)) : Value?
    unless type_fn.ret.eq?(func_def.mod.typer.void)
      wrap_val(FAKE_VAL, type_fn.ret, Value::PP::CallResult.new(name))
    end
  end

  def invoke(fn : Value, type_fn : Type::Fn, args : Array(Value)) : Value?
    unless type_fn.ret.eq?(func_def.mod.typer.void)
      wrap_val(FAKE_VAL, type_fn.ret, Value::PP::CallResult.new("inkoke"))
    end
  end

  def fn_addr(name : String, type_fn : Type::Fn) : Value
    wrap_val(FAKE_VAL, type_fn, Value::PP::FnAddress.new(name))
  end

  def cond(cond : Value, then_bb : AbstractBB, else_bb : AbstractBB)
  end

  def next(name : String) : AbstractBB
    BB.new(name, builder, @func, @func_def)
  end

  def select(cond : Value, arg_true : Value, arg_false : Value) : Value
    wrap_val(FAKE_VAL, arg_true.type, arg_true.pp)
  end

  def store(lhs : Value, rhs : Value)
  end

  def binary(op : Opcode::Binary::Op, lhs : Value, rhs : Value) : Value?
    wrap_res(FAKE_VAL, op.value >= Opcode::Binary::Op::Eq.value ? func_def.mod.typer.bool : lhs.type, lhs.pp)
  end

  def unary(op : Opcode::Unary::Op, rhs : Value) : Value?
    wrap_res(FAKE_VAL, rhs.type, rhs.pp)
  end

  def switch(index : Value, case_values : Array(Value), case_bbs : Array(AbstractBB), default_bb : AbstractBB)
  end

  def cast?(value : Value, from_type : Type, to_type : Type) : Value?
    case {from_type, to_type}
    when {Type::IntType, Type::IntType}
      wrap_res(FAKE_VAL, to_type, value.pp)
    when {Type::IntType, Type::FloatType}
      wrap_res(FAKE_VAL, to_type, value.pp)
    when {Type::FloatType, Type::IntType}
      wrap_res(FAKE_VAL, to_type, value.pp)
    when {Type::FloatType, Type::FloatType}
      wrap_res(FAKE_VAL, to_type, value.pp)
    when {Type::BoolType, Type::IntType}
      wrap_res(FAKE_VAL, to_type, value.pp)
    when {Type::PtrType, Type::PtrType}
      wrap_res(FAKE_VAL, to_type, value.pp)
    when {Type::IntType, Type::PtrType}
      wrap_res(FAKE_VAL, to_type, value.pp)
    when {Type::PtrType, Type::IntType}
      wrap_res(FAKE_VAL, to_type, value.pp)
    end
  end

  def to?(value : Value, from_type : Type, to_type : Type) : Value?
    case {from_type, to_type}
    when {Type::IntType, Type::IntType}
      from_size = from_type.bytes_count
      to_size = to_type.bytes_count

      if to_size > from_size
        wrap_res(FAKE_VAL, to_type, value.pp)
      elsif to_size == from_size && from_type.signed == to_type.signed
        wrap_res(FAKE_VAL, to_type, value.pp)
      end
    when {Type::IntType, Type::FloatType}
      if to_type.bytes_count >= from_type.bytes_count
        wrap_res(FAKE_VAL, to_type, value.pp)
      end
    when {Type::FloatType, Type::FloatType}
      if to_type.bytes_count >= from_type.bytes_count
        wrap_res(FAKE_VAL, to_type, value.pp)
      end
    when {Type::PtrType, Type::PtrType}
      if to_type.target_type.is_a?(Type::VoidType)
        wrap_res(FAKE_VAL, to_type, value.pp)
      end
    end
  end

  def field(value : Value, field_type : Type, offset : Int32) : Value
    wrap_ref(FAKE_VAL, field_type, value.pp)
  end

  def extract_value(value : Value, field_type : Type, offset : Int32) : Value
    field(value, field_type, offset)
  end

  def deref(value : Value, target_type : Type) : Value
    wrap_ref(FAKE_VAL, target_type, value.pp)
  end

  def addr(value : Value, ptr_type : Type) : Value
    wrap_val(FAKE_VAL, ptr_type, value.pp)
  end

  def offset(value : Value, target_type : Type, offset : Value) : Value
    wrap_ref(FAKE_VAL, value.type, value.pp)
  end

  def bitcast(value : Value, to_type : Type) : Value
    wrap_ref(FAKE_VAL, to_type, value.pp)
  end

  private def wrap_val(val, type : Type, pp : Value::PP) : Value
    Value.new(val, type, Value::MM::Val, pp)
  end

  private def wrap_ref(val, type : Type, pp : Value::PP) : Value
    Value.new(val, type, Value::MM::Ref, pp)
  end

  private def wrap_res(val, type : Type, pp : Value::PP) : Value
    wrap_val(val, type, pp)
  end
end
