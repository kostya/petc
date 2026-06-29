class Myc::Backend::C::BB < Myc::Backend::AbstractBB
  def initialize(@name, @builder, @func, @func_def)
    super
    @body_io = IO::Memory.new
  end

  def alloca(name : String, type : Type) : Value
    emit "#{c_type(type)} #{name};"
    wrap_ref(name, type, Value::PP::LocalUninitialized.new(name))
  end

  def load_ref(value : Value) : Value
    wrap_val(c_val(value), value.type, value.pp)
  end

  def jmp(other : AbstractBB)
    emit "goto #{other.name};"
  end

  def ret(val : Value?)
    if val
      emit "_result = #{c_val(val)};"
    end
    emit "goto ret;"
  end

  def call(name : String, type_fn : Type::Fn, args : Array(Value)) : Value?
    ret_type = type_fn.ret
    ret_c_type = c_type(ret_type)

    arg_str = args.map { |a| c_val(a) }.join(", ")

    if ret_type.eq?(func_def.mod.typer.void)
      emit "#{name}(#{arg_str});"
      nil
    else
      temp = builder.new_temp
      emit "#{ret_c_type} #{temp} = #{name}(#{arg_str});"
      wrap_val(temp, ret_type, Value::PP::CallResult.new(name))
    end
  end

  def invoke(fn : Value, type_fn : Type::Fn, args : Array(Value)) : Value?
    ret_type = type_fn.ret
    ret_c_type = c_type(ret_type)
    fn_val = c_val(fn)
    arg_str = args.map { |a| c_val(a) }.join(", ")

    fn_type_str = format_fn_type(type_fn, nil)
    casted_fn = "((#{fn_type_str})(#{fn_val}))"

    if ret_type.eq?(func_def.mod.typer.void)
      emit "#{casted_fn}(#{arg_str});"
      nil
    else
      temp = builder.new_temp
      emit "#{ret_c_type} #{temp} = #{casted_fn}(#{arg_str});"
      wrap_val(temp, ret_type, Value::PP::CallResult.new("invoke"))
    end
  end

  def fn_addr(name : String, type_fn : Type::Fn) : Value
    wrap_val(name, type_fn, Value::PP::FnAddress.new(name))
  end

  def cond(cond : Value, then_bb : AbstractBB, else_bb : AbstractBB)
    emit "if (#{c_val(cond)}) goto #{then_bb.name}; else goto #{else_bb.name};"
  end

  def next(name : String) : AbstractBB
    label = builder.new_label(name)
    bb = BB.new(label, builder, @func, @func_def)
    func.register_block(bb)
    bb
  end

  def select(cond : Value, arg_true : Value, arg_false : Value) : Value
    result_type = arg_true.type
    temp = builder.new_temp
    emit "#{c_type(result_type)} #{temp} = (#{c_val(cond)}) ? (#{c_val(arg_true)}) : (#{c_val(arg_false)});"
    wrap_val(temp, result_type, arg_true.pp)
  end

  def store(lhs : Value, rhs : Value)
    if lhs.type.needs_blit?
      src_val = if rhs.mm.val? && rhs.type.is_a?(Type::FlatType)
                  c_val(rhs)
                else
                  "&(#{c_val(rhs)})"
                end
      size = builder.layout.size_of(lhs.type)

      emit "memcpy(&#{c_val(lhs)}, #{src_val}, #{size});"
    else
      emit "#{c_val(lhs)} = #{c_val(rhs)};"
    end
  end

  def binary(op : Opcode::Binary::Op, lhs : Value, rhs : Value) : Value?
    l = c_val(lhs)
    r = c_val(rhs)

    op_str = case op
             when .add?        then "+"
             when .sub?        then "-"
             when .mul?        then "*"
             when .div?        then "/"
             when .rem?        then "%"
             when .and?        then "&"
             when .or?         then "|"
             when .xor?        then "^"
             when .shl?        then "<<"
             when .shr?, .sar? then ">>"
             when .eq?         then "=="
             when .not_eq?     then "!="
             when .less?       then "<"
             when .less_eq?    then "<="
             when .more?       then ">"
             when .more_eq?    then ">="
             else                   return nil
             end

    is_cmp = op.value >= Opcode::Binary::Op::Eq.value
    result_type = is_cmp ? typer.bool : lhs.type
    result_c_type = c_type(result_type)

    temp = builder.new_temp
    emit "#{result_c_type} #{temp} = #{l} #{op_str} #{r};"
    wrap_res(temp, result_type, lhs.pp)
  end

  def unary(op : Opcode::Unary::Op, rhs : Value) : Value?
    val = c_val(rhs)
    type = rhs.type
    c_type_str = c_type(type)
    temp = builder.new_temp

    case op
    when .lnot?
      if type.is_a?(Type::BoolType)
        emit "#{c_type_str} #{temp} = !#{val};"
      else
        emit "#{c_type_str} #{temp} = (#{val} == 0) ? 1 : 0;"
      end
    when .bnot?
      emit "#{c_type_str} #{temp} = ~#{val};"
    when .neg?
      emit "#{c_type_str} #{temp} = -(#{val});"
    else
      return nil
    end

    wrap_res(temp, type, rhs.pp)
  end

  def switch(index : Value, case_values : Array(Value), case_bbs : Array(AbstractBB), default_bb : AbstractBB)
    index_c = c_val(index)

    case_values.each_with_index do |val, i|
      prefix = i == 0 ? "if" : "else if"
      emit "#{prefix} (#{index_c} == #{c_val(val)}) goto #{case_bbs[i].name};"
    end
    emit "else goto #{default_bb.name};"
  end

  def cast?(value : Value, from_type : Type, to_type : Type) : Value?
    val = c_val(value)
    c_to = c_type(to_type)
    temp = builder.new_temp

    case {from_type, to_type}
    when {Type::IntType, Type::IntType}
      if from_type.signed && !to_type.signed && to_type.bytes_count > from_type.bytes_count
        temp_unsigned = builder.new_temp
        emit "#{c_type(from_type.to_unsigned)} #{temp_unsigned} = (unsigned)(#{val});"
        emit "#{c_to} #{temp} = (#{c_to})#{temp_unsigned};"
      else
        emit "#{c_to} #{temp} = (#{c_to})(#{val});"
      end
      wrap_res(temp, to_type, value.pp)
    when {Type::IntType, Type::FloatType}
      emit "#{c_to} #{temp} = (#{c_to})(#{val});"
      wrap_res(temp, to_type, value.pp)
    when {Type::FloatType, Type::IntType}
      emit "#{c_to} #{temp} = (#{c_to})(#{val});"
      wrap_res(temp, to_type, value.pp)
    when {Type::FloatType, Type::FloatType}
      emit "#{c_to} #{temp} = (#{c_to})(#{val});"
      wrap_res(temp, to_type, value.pp)
    when {Type::BoolType, Type::IntType}
      emit "#{c_to} #{temp} = (#{c_to})(#{val});"
      wrap_res(temp, to_type, value.pp)
    when {Type::PtrType, Type::PtrType}
      emit "#{c_to} #{temp} = (#{c_to})(#{val});"
      wrap_res(temp, to_type, value.pp)
    when {Type::IntType, Type::PtrType}
      emit "#{c_to} #{temp} = (#{c_to})(#{val});"
      wrap_res(temp, to_type, value.pp)
    when {Type::PtrType, Type::IntType}
      emit "#{c_to} #{temp} = (#{c_to})(#{val});"
      wrap_res(temp, to_type, value.pp)
    end
  end

  def to?(value : Value, from_type : Type, to_type : Type) : Value?
    val = c_val(value)
    c_to = c_type(to_type)
    temp = builder.new_temp

    case {from_type, to_type}
    when {Type::IntType, Type::IntType}
      from_size = from_type.bytes_count
      to_size = to_type.bytes_count

      if to_size > from_size
        emit "#{c_to} #{temp} = (#{c_to})(#{val});"
        wrap_res(temp, to_type, value.pp)
      elsif to_size == from_size && from_type.signed == to_type.signed
        emit "#{c_to} #{temp} = (#{c_to})(#{val});"
        wrap_res(temp, to_type, value.pp)
      end
    when {Type::IntType, Type::FloatType}
      if to_type.bytes_count >= from_type.bytes_count
        emit "#{c_to} #{temp} = (#{c_to})(#{val});"
        wrap_res(temp, to_type, value.pp)
      end
    when {Type::FloatType, Type::FloatType}
      if to_type.bytes_count >= from_type.bytes_count
        emit "#{c_to} #{temp} = (#{c_to})(#{val});"
        wrap_res(temp, to_type, value.pp)
      end
    when {Type::PtrType, Type::PtrType}
      if to_type.target_type.is_a?(Type::VoidType)
        emit "#{c_to} #{temp} = (#{c_to})(#{val});"
        wrap_res(temp, to_type, value.pp)
      end
    end
  end

  def field(value : Value, field_type : Type, offset : Int32) : Value
    case value.type
    when Type::FlatType
      val = "#{c_val(value)}[#{offset}]"
      wrap_ref(val, field_type, value.pp)
    else
      val = "#{c_val(value)}.field#{offset}"
      wrap_ref(val, field_type, value.pp)
    end
  end

  def extract_value(value : Value, field_type : Type, offset : Int32) : Value
    field(value, field_type, offset)
  end

  def deref(value : Value, target_type : Type) : Value
    val = "(*#{c_val(value)})"
    wrap_ref(val, target_type, value.pp)
  end

  def addr(value : Value, ptr_type : Type) : Value
    val = "&#{c_val(value)}"
    wrap_val(val, ptr_type, value.pp)
  end

  def offset(value : Value, target_type : Type, offset : Value) : Value
    wrap_ref("(#{c_val(value)} + #{c_val(offset)})", value.type, value.pp)
  end

  def bitcast(value : Value, to_type : Type) : Value
    new_val = "(*(#{c_type(to_type)}*)(#{c_val(value)}))"
    wrap_ref(new_val, to_type, value.pp)
  end

  def builder
    @builder.as(Builder)
  end

  def func
    @func.as(Func)
  end

  def emit(str : String)
    @body_io << "  " << str << "\n"
  end

  def copy_data(to : IO, emit_label : Bool)
    if emit_label
      to << '\n'
      to << @name
      to << ':'
      to << ';'
      to << '\n'
    end
    builder.copy_io(@body_io, to)
  end

  private def c_val(v : Value) : String
    v.bbval.as(BBVal).val
  end

  private def c_type(v : Value) : String
    c_type(v.type)
  end

  private def c_type(t : Type) : String
    builder.c_type(t)
  end

  private def wrap_val(val : String, type : Type, pp : Value::PP) : Value
    Value.new(BBVal.new(val), type, Value::MM::Val, pp)
  end

  private def wrap_ref(val : String, type : Type, pp : Value::PP) : Value
    Value.new(BBVal.new(val), type, Value::MM::Ref, pp)
  end

  private def wrap_res(val : String, type : Type, pp : Value::PP) : Value
    wrap_val(val, type, pp)
  end

  private def typer : Mod::Typer
    @func_def.mod.typer
  end

  private def format_fn_type(type : Type::Fn, name : String? = nil) : String
    ret_type = c_type(type.ret)
    args = type.args.map { |t| c_type(t) }.join(", ")
    if type.vaarg
      args += ", ..." unless args.empty?
    end

    if name
      "#{ret_type}(*#{name})(#{args})"
    else
      "#{ret_type}(*)(#{args})"
    end
  end
end
