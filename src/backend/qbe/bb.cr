class Myc::Backend::QBE::BB < Myc::Backend::AbstractBB
  def initialize(@name, @builder, @func, @func_def)
    super
    @temp_counter = 0
    @body_io = IO::Memory.new
  end

  def alloca(name : String, type : Type) : Value
    name2 = "%" + name
    size = @builder.layout.size_of(type)
    emit "#{name2} =l alloc8 #{size}"
    wrap_ref(name2, type, Value::PP::LocalUninitialized.new(name))
  end

  def load_ref(value : Value) : Value
    if value.type.needs_blit?
      return wrap_val(qbe_val(value), value.type, value.pp)
    end

    qbe_type = qbe_type(value)
    load_op = case type = value.type
              when Type::IntType
                case type.bytes_count
                when 1 then type.signed ? "loadsb" : "loadub"
                when 2 then type.signed ? "loadsh" : "loaduh"
                else        "load#{qbe_type}"
                end
              when Type::BoolType
                "loadsb"
              else
                "load#{qbe_type}"
              end

    result_type = qbe_type
    temp = new_temp
    emit "#{temp} =#{result_type} #{load_op} #{qbe_val(value)}"
    wrap_val(temp, value.type, value.pp)
  end

  def jmp(other : AbstractBB)
    return if @dead_end
    emit "jmp @#{other.name}"
    @dead_end = true
  end

  def ret(val : Value?)
    return if @dead_end
    if val
      emit "ret #{qbe_val(val)}"
    else
      emit "ret"
    end
    @dead_end = true
  end

  def call(name : String, type_fn : Type::Fn, args : Array(Value)) : Value?
    return if @dead_end

    ret_type = type_fn.ret

    arg_str = String.build do |s|
      args.each_with_index do |arg, index|
        s << ", " if index != 0
        s << "..., " if type_fn.vaarg && (index == type_fn.args.size)
        s << qbe_type(arg)
        s << ' '
        s << qbe_val(arg)
      end
    end

    if ret_type.eq?(func_def.mod.typer.void)
      emit "call $#{name}(#{arg_str})"
      nil
    else
      t = new_temp
      emit "#{t} =#{qbe_type(ret_type)} call $#{name}(#{arg_str})"
      wrap_val(t, ret_type, Value::PP::CallResult.new(name))
    end
  end

  def cond(cond : Value, then_bb : AbstractBB, else_bb : AbstractBB)
    return if @dead_end
    emit "jnz #{qbe_val(cond)}, @#{then_bb.name}, @#{else_bb.name}"
    @dead_end = true
  end

  def next(name : String) : AbstractBB
    label = builder.new_label(name)
    bb = BB.new(label, builder, @func, @func_def)
    func.register_block(bb)
    bb
  end

  def select(cond : Value, arg_true : Value, arg_false : Value) : Value
    cond_val = qbe_val(cond)
    true_val = qbe_val(arg_true)
    false_val = qbe_val(arg_false)
    result_type = qbe_type(arg_true.type)
    t = new_temp

    emit "#{t} =#{result_type} copy #{false_val}"

    true_label = builder.new_label("select_true")
    end_label = builder.new_label("select_end")
    emit "jnz #{cond_val}, @#{true_label}, @#{end_label}"

    emit_label true_label
    emit "#{t} =#{result_type} copy #{true_val}"
    emit "jmp @#{end_label}"

    emit_label end_label

    wrap_val(t, arg_true.type, arg_true.pp)
  end

  def store(lhs : Value, rhs : Value)
    return if @dead_end
    if lhs.type.needs_blit?
      emit "blit #{qbe_val(rhs)}, #{qbe_val(lhs)}, #{builder.layout.size_of(lhs.type)}"
    else
      qbe_type = qbe_type(lhs.type)
      store_op = case type = lhs.type
                 when Type::IntType
                   case type.bytes_count
                   when 1 then "storeb"
                   when 2 then "storeh"
                   else        "store#{qbe_type}"
                   end
                 when Type::BoolType
                   "storeb"
                 else
                   "store#{qbe_type}"
                 end
      emit "#{store_op} #{qbe_val(rhs)}, #{qbe_val(lhs)}"
    end
  end

  def binary(op : Opcode::Binary::Op, lhs : Value, rhs : Value) : Value?
    return if @dead_end

    l = qbe_val(lhs)
    r = qbe_val(rhs)
    t = new_temp
    ltype = lhs.type
    qbe_type = qbe_type(ltype)

    case op
    when .add? then emit "#{t} =#{qbe_type} add #{l}, #{r}"
    when .sub? then emit "#{t} =#{qbe_type} sub #{l}, #{r}"
    when .mul? then emit "#{t} =#{qbe_type} mul #{l}, #{r}"
    when .div?
      op_name = case ltype
                when Type::IntType
                  ltype.signed ? "div" : "udiv"
                when Type::FloatType
                  "div"
                else
                  return
                end
      emit "#{t} =#{qbe_type} #{op_name} #{l}, #{r}"
    when .rem?
      case ltype
      when Type::IntType
        op_name = ltype.signed ? "rem" : "urem"
        emit "#{t} =#{qbe_type} #{op_name} #{l}, #{r}"
      else
        return
      end
    when .and?   then emit "#{t} =#{qbe_type} and #{l}, #{r}"
    when .or?    then emit "#{t} =#{qbe_type} or #{l}, #{r}"
    when .xor?   then emit "#{t} =#{qbe_type} xor #{l}, #{r}"
    when .shl?   then emit "#{t} =#{qbe_type} shl #{l}, #{r}"
    when .l_shr? then emit "#{t} =#{qbe_type} shr #{l}, #{r}"
    when .a_shr? then emit "#{t} =#{qbe_type} sar #{l}, #{r}"
    when .eq?
      emit "#{t} =w ceq#{qbe_type} #{l}, #{r}"
      return wrap_res(t, typer.bool, lhs.pp)
    when .not_eq?
      emit "#{t} =w cne#{qbe_type} #{l}, #{r}"
      return wrap_res(t, typer.bool, lhs.pp)
    when .less?
      case ltype
      when Type::IntType
        pred = ltype.signed ? "cslt" : "cult"
        emit "#{t} =w #{pred}#{qbe_type} #{l}, #{r}"
      else
        emit "#{t} =w clt#{qbe_type} #{l}, #{r}"
      end
      return wrap_res(t, typer.bool, lhs.pp)
    when .less_eq?
      case ltype
      when Type::IntType
        pred = ltype.signed ? "csle" : "cule"
        emit "#{t} =w #{pred}#{qbe_type} #{l}, #{r}"
      else
        emit "#{t} =w cle#{qbe_type} #{l}, #{r}"
      end
      return wrap_res(t, typer.bool, lhs.pp)
    when .more?
      case ltype
      when Type::IntType
        pred = ltype.signed ? "csgt" : "cugt"
        emit "#{t} =w #{pred}#{qbe_type} #{l}, #{r}"
      else
        emit "#{t} =w cgt#{qbe_type} #{l}, #{r}"
      end
      return wrap_res(t, typer.bool, lhs.pp)
    when .more_eq?
      case ltype
      when Type::IntType
        pred = ltype.signed ? "csge" : "cuge"
        emit "#{t} =w #{pred}#{qbe_type} #{l}, #{r}"
      else
        emit "#{t} =w cge#{qbe_type} #{l}, #{r}"
      end
      return wrap_res(t, typer.bool, lhs.pp)
    else
      return nil
    end

    wrap_res(t, ltype, lhs.pp)
  end

  def unary(op : Opcode::Unary::Op, rhs : Value) : Value?
    return if @dead_end

    val = qbe_val(rhs)
    type = rhs.type
    qbe_type = qbe_type(type)
    t = new_temp

    case op
    when .lnot?
      case type
      when Type::IntType, Type::BoolType
        emit "#{t} =w ceqw #{val}, 0"
      end
    when .bnot?
      case type
      when Type::IntType
        emit "#{t} =w xor #{val}, -1"
      end
    when .neg?
      emit "#{t} =#{qbe_type} neg #{val}"
    else
      return nil
    end

    wrap_res(t, type, rhs.pp)
  end

  def switch(index : Value, case_values : Array(Value), case_bbs : Array(AbstractBB), default_bb : AbstractBB)
    return if @dead_end
    index_qbe = qbe_val(index)

    case_values.each_with_index do |val, i|
      cmp = new_temp
      next_label = builder.new_label("switch_next")
      emit "#{cmp} =w ceqw #{index_qbe}, #{qbe_val(val)}"
      emit "jnz #{cmp}, @#{case_bbs[i].name}, @#{next_label}"
      emit_label(next_label)
    end

    jmp(default_bb)
  end

  def cast?(value : Value, from_type : Type, to_type : Type) : Value?
    from_qbe = qbe_type(from_type)
    to_qbe = qbe_type(to_type)
    val = qbe_val(value)
    t = new_temp

    case {from_type, to_type}
    when {Type::IntType, Type::IntType}
      from_size = from_type.bytes_count
      to_size = to_type.bytes_count

      if to_size == from_size
        wrap_res(val, to_type, value.pp)
      elsif to_size > from_size
        if from_type.signed && to_type.signed
          ext = case from_size
                when 4 then "extsw"
                when 2 then "extsh"
                else        "extsb"
                end
          to_qbe_type = from_size == 4 ? "l" : "w"
          emit "#{t} =#{to_qbe_type} #{ext} #{val}"
        else
          ext = case from_size
                when 4 then "extuw"
                when 2 then "extuh"
                else        "extub"
                end
          to_qbe_type = from_size == 4 ? "l" : "w"
          emit "#{t} =#{to_qbe_type} #{ext} #{val}"
        end

        wrap_res(t, to_type, value.pp)
      else
        emit "#{t} =#{to_qbe} copy #{val}"
        wrap_res(t, to_type, value.pp)
      end
    when {Type::IntType, Type::FloatType}
      conv = if from_type.bytes_count == 8
               from_type.signed ? "sltof" : "ultof"
             else
               from_type.signed ? "swtof" : "uwtof"
             end
      emit "#{t} =#{to_qbe} #{conv} #{val}"
      wrap_res(t, to_type, value.pp)
    when {Type::FloatType, Type::IntType}
      conv = if from_type.bytes_count == 8
               to_type.signed ? "dtosi" : "dtoui"
             else
               to_type.signed ? "stosi" : "stoui"
             end
      emit "#{t} =#{to_qbe} #{conv} #{val}"
      wrap_res(t, to_type, value.pp)
    when {Type::FloatType, Type::FloatType}
      if to_type.bytes_count > from_type.bytes_count
        emit "#{t} =#{to_qbe} exts #{val}"
      else
        emit "#{t} =#{to_qbe} truncd #{val}"
      end
      wrap_res(t, to_type, value.pp)
    when {Type::BoolType, Type::IntType}
      if val == "0" || val == "1"
        emit "#{t} =#{to_qbe} copy #{val}"
      else
        temp_bool = new_temp
        emit "#{temp_bool} =w copy #{val}"
        emit "#{t} =#{to_qbe} extuw #{temp_bool}"
      end
      wrap_res(t, to_type, value.pp)
    when {Type::IntType, Type::BoolType}
      qbe_t = qbe_type(from_type)
      emit "#{t} =w cne#{qbe_t} #{val}, 0"
      wrap_res(t, to_type, value.pp)
    when {Type::FloatType, Type::BoolType}
      qbe_t = qbe_type(from_type)
      emit "#{t} =w cne#{qbe_t} #{val}, 0"
      wrap_res(t, to_type, value.pp)
    when {Type::PtrType, Type::PtrType}
      wrap_res(val, to_type, value.pp)
    when {Type::IntType, Type::PtrType}
      emit "#{t} =#{to_qbe} copy #{val}"
      wrap_res(t, to_type, value.pp)
    when {Type::PtrType, Type::IntType}
      emit "#{t} =#{to_qbe} copy #{val}"
      wrap_res(t, to_type, value.pp)
    end
  end

  def to?(value : Value, from_type : Type, to_type : Type) : Value?
    from_qbe = qbe_type(from_type)
    to_qbe = qbe_type(to_type)
    val = qbe_val(value)
    t = new_temp

    case {from_type, to_type}
    when {Type::IntType, Type::IntType}
      from_size = from_type.bytes_count
      to_size = to_type.bytes_count

      if to_size >= from_size
        if to_size == from_size
          wrap_res(val, to_type, value.pp)
        else
          if from_type.signed
            ext = case from_size
                  when 4 then "extsw"
                  when 2 then "extsh"
                  else        "extsb"
                  end
            emit "#{t} =#{to_qbe} #{ext} #{val}"
          else
            ext = case from_size
                  when 4 then "extuw"
                  when 2 then "extuh"
                  else        "extub"
                  end
            emit "#{t} =#{to_qbe} #{ext} #{val}"
          end
          wrap_res(t, to_type, value.pp)
        end
      end
    when {Type::IntType, Type::FloatType}
      conv = if from_type.bytes_count == 8
               from_type.signed ? "sltof" : "ultof"
             else
               from_type.signed ? "swtof" : "uwtof"
             end
      emit "#{t} =#{to_qbe} #{conv} #{val}"
      wrap_res(t, to_type, value.pp)
    when {Type::FloatType, Type::FloatType}
      if to_type.bytes_count >= from_type.bytes_count
        if to_type.bytes_count > from_type.bytes_count
          emit "#{t} =#{to_qbe} exts #{val}"
        else
          wrap_res(val, to_type, value.pp)
        end
        wrap_res(t, to_type, value.pp)
      end
    when {Type::BoolType, Type::IntType}
      if val == "0" || val == "1"
        emit "#{t} =#{to_qbe} copy #{val}"
      else
        temp_bool = new_temp
        emit "#{temp_bool} =w copy #{val}"
        emit "#{t} =#{to_qbe} extuw #{temp_bool}"
      end
      wrap_res(t, to_type, value.pp)
    when {Type::PtrType, Type::PtrType}
      if to_type.target_type.is_a?(Type::VoidType)
        wrap_res(val, to_type, value.pp)
      end
    end
  end

  def field(value : Value, field_type : Type, offset : Int32) : Value
    byte_offset = builder.layout.field_offset(value.type, offset.to_u64)
    if byte_offset == 0
      wrap_ref(qbe_val(value), field_type, value.pp)
    else
      field_ptr = new_temp
      emit "#{field_ptr} =l add #{qbe_val(value)}, #{byte_offset}"
      wrap_ref(field_ptr, field_type, value.pp)
    end
  end

  def extract_value(value : Value, field_type : Type, offset : Int32) : Value
    field(value, field_type, offset)
  end

  def deref(value : Value, target_type : Type) : Value
    wrap_ref(qbe_val(value), target_type, value.pp)
  end

  def addr(value : Value, ptr_type : Type) : Value
    wrap_val(qbe_val(value), ptr_type, value.pp)
  end

  def offset(value : Value, target_type : Type, offset : Value) : Value
    ptr_val = qbe_val(value)
    idx = qbe_val(offset)
    elem_size = @builder.layout.size_of(target_type)

    idx_l = if offset.pp.is_a?(Value::PP::Primitive)
              idx
            else
              new_temp.tap { |l| emit "#{l} =l extsw #{idx}" }
            end

    addr = if elem_size == 1
             tmp = new_temp
             emit "#{tmp} =l add #{ptr_val}, #{idx_l}"
             tmp
           elsif elem_size.popcount == 1
             shift = elem_size.trailing_zeros_count
             shifted = new_temp
             emit "#{shifted} =l shl #{idx_l}, #{shift}"
             tmp = new_temp
             emit "#{tmp} =l add #{ptr_val}, #{shifted}"
             tmp
           else
             bytes = new_temp
             emit "#{bytes} =l mul #{idx_l}, #{elem_size}"
             tmp = new_temp
             emit "#{tmp} =l add #{ptr_val}, #{bytes}"
             tmp
           end

    wrap_val(addr, value.type, value.pp)
  end

  def bitcast(value : Value, to_type : Type) : Value
    wrap_ref(qbe_val(value), to_type, value.pp)
  end

  # ------------------------- Helpers ---------------------------------------

  def builder
    @builder.as(Builder)
  end

  def emit(str : String)
    return if @dead_end
    @body_io << "  " << str << '\n'
  end

  private def emit_label(name : String, io = @body_io)
    io << '@'
    io << name
    io << '\n'
  end

  def copy_data(to : IO, _emit_label : Bool)
    emit_label(@name, to) if _emit_label
    builder.copy_io(@body_io, to)
  end

  private def qbe_type(v : Value) : String
    qbe_type(v.type)
  end

  private def qbe_type(t : Type) : String
    builder.qbe_type(t)
  end

  private def qbe_val(v : Value) : String
    v.bbval.as(BBVal).val
  end

  def func
    @func.as(Func)
  end

  private def new_temp : String
    func.new_temp
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
end
