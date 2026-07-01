abstract class Myc::Backend::AbstractVisitor
  getter stack : Deque(Value)
  getter loop_finish_stack : Deque(AbstractBB)
  getter loop_step_stack : Deque(AbstractBB)

  getter func_def : Mod::FuncDef
  getter mod : Mod
  getter builder : AbstractBuilder
  getter func : AbstractFunc
  property bb : AbstractBB
  getter params : Array(Value)

  getter current_op : Opcode
  getter locals : Hash(String, Value)
  getter fake_bb : AbstractBB

  def initialize(@builder, @func, @bb, @func_def, @mod, @params)
    @stack = Deque(Value).new
    @loop_finish_stack = Deque(AbstractBB).new
    @loop_step_stack = Deque(AbstractBB).new
    @locals = Hash(String, Value).new
    @current_op = @func_def.body.not_nil!
    @unique_id = 0_u64
    @was_ret = false
    @pending_labels = Hash(String, AbstractBB).new
    @labels = Hash(String, AbstractBB).new
    @fake_bb = @bb.class.new("__myc_fake_bb__", @builder, @func, @func_def)
  end

  def visit
    visit(@current_op)

    if func_def.have_ret? && !@was_ret
      raise error("FUNC :#{func_def.name} expected ret #{func_def.type_fn.ret}, but no RET was found")
    end

    self
  end

  def error(msg)
    Error::ErrorVisitor.new(msg, self)
  end

  private def <<(v : Value)
    @stack << v
  end

  private def pop : Value
    raise error("empty stack") if @stack.empty?
    @stack.pop
  end

  private def last : Value
    raise error("empty stack") if @stack.empty?
    @stack.last
  end

  private def pop_rhs : Value
    pop.to_rhs(self)
  end

  private def pop_lhs : Value
    pop.to_lhs(self)
  end

  private def pop_many_rhs(count)
    res = [] of Value
    count.times { res << pop_rhs }
    res
  end

  private def find_func_type_fn(name : String) : Type::Fn?
    @mod.func_defs[name]?.try(&.type_fn) || @builder.std_funcs[name]? || @builder.inspect_type_fns[name]?
  end

  def visit(op : Opcode::Printf)
    visit Opcode::Call.new("printf", op.args_count)
    visit Opcode::Stack.new(:drop)
  end

  def visit(op : Opcode::Push)
    type = op.type

    unless type
      case val = op.value
      when Int
        if val >= Int32::MIN && val <= Int32::MAX
          type = mod.typer.i32
        end
      end
    end

    unless type
      type = mod.typer.std_value_type?(op.value)
    end

    raise error("type for value #{op.value.inspect} not found") unless type

    case val = op.value
    when String
      if val.starts_with?('M')
        case val
        when "MYC_BACKEND"
          val = @builder.backend.name
        when "MYC_FLAGS"
          val = @builder.backend.debug_flags
        end
      end
    end

    if val = builder.constant_value?(val, type)
      self << val
    else
      raise error("cant push value: #{op.value.class.inspect} #{op.value.inspect}")
    end
  end

  def visit(op : Opcode::Seq)
    old_stack = @stack
    @stack = Deque(Value).new

    op.list.each { |child| visit_child(child) }

    if @stack.size != op.stack_balance
      raise error("stack balance: expected #{op.stack_balance}, got #{@stack.size}: [#{debug_stack}]")
    end

    @stack.each { |v| old_stack << v }
    @stack = old_stack
  end

  protected def visit_child(child : Opcode)
    Myc.debug(:visitor) { "visit #{child.inspect}" }
    @current_op = child
    visit(child)
  end

  def visit(op : Opcode::If)
    cond = pop_rhs
    raise error("IF expect bool value on stack, but got #{cond.type}") unless cond.type.eq?(mod.typer.bool)

    if op.else_seq.list.any?
      then_bb = @bb.next("then")
      else_bb = @bb.next("else")
      endif_bb = @bb.next("endif")
      @bb.cond(cond, then_bb, else_bb)

      @bb = then_bb
      visit(op.then_seq)
      @bb.jmp(endif_bb)

      @bb = else_bb
      visit(op.else_seq)
      @bb.jmp(endif_bb)

      @bb = endif_bb
    else
      then_bb = @bb.next("then")
      endif_bb = @bb.next("endif")
      @bb.cond(cond, then_bb, endif_bb)

      @bb = then_bb
      visit(op.then_seq)
      @bb.jmp(endif_bb)

      @bb = endif_bb
    end
  end

  def visit(op : Opcode::Inspect)
    depth = if op.internal
              pop_rhs
            end

    arg = last

    f = if fname = builder.inspect_funcs[arg.type]?
          fname
        else
          fname = "__myc_inspect_#{mod.name}_#{arg.type.backend_name}"
          builder.inspect_funcs[arg.type] = fname
          generate_inspect_func(arg.type, fname)
          fname
        end

    case _pp = arg.pp
    when Value::PP::LocalUninitialized
      raise error("cant read from uninitialized local `#{_pp.name}`")
    end

    visit Opcode::Addr.new
    visit Opcode::As.new(mod.typer.voidp)

    if depth
      @stack << depth
      visit Opcode::Push.new(1_i64, mod.typer.i32)
      visit Opcode::Binary.new(:add)
    else
      visit Opcode::Push.new(0_i64, mod.typer.i32)
    end
    visit Opcode::Stack.new(:swap2)
    visit Opcode::Call.new(f)
  end

  private def generate_inspect_func(type : Type, func_name : String)
    type_fn = Type::Fn.new([mod.typer.voidp, mod.typer.i32], mod.typer.void)
    @builder.inspect_type_fns[func_name] = type_fn
    fdef = Mod::FuncDef.new(@func_def.node, @mod, func_name, type_fn)
    fdef.attributes = %w{noinline}
    fdef.body = Opcode::Seq.new
    body = fdef.body.not_nil!

    body << Opcode::Push.new(5_i64, mod.typer.i32)
    body << Opcode::Param.new(1)
    body << Opcode::Binary.new(:more)

    then_seq = Opcode::Seq.new
    then_seq << Opcode::Push.new("...")
    then_seq << Opcode::Printf.new(0)
    then_seq << Opcode::Ret.new

    body << Opcode::If.new(then_seq, Opcode::Seq.new)

    arg = [
      Opcode::Param.new(0),
      Opcode::As.new(mod.typer.to_ptr(type, current_op.offset)),
      Opcode::Deref.new,
    ] of Opcode

    case type
    when Type::IntType
      body << arg
      body << Opcode::Push.new(builder.layout.int_format(type))
      body << Opcode::Printf.new(1)
    when Type::FloatType
      body << arg
      body << Opcode::Push.new(builder.layout.float_format(type))
      body << Opcode::Printf.new(1)
    when Type::BoolType
      body << Opcode::Push.new("false")
      body << Opcode::Push.new("true")
      body << arg
      body << Opcode::Select.new
      body << Opcode::Push.new("%s")
      body << Opcode::Printf.new(1)
    when Type::VoidType
      body << Opcode::Push.new("void")
      body << Opcode::Printf.new(0)
    when Type::PtrType
      target_type = type.target_type
      if target_type.eq?(mod.typer.u8)
        body << arg
        body << Opcode::Push.new("\"%s\"")
        body << Opcode::Printf.new(1)
      else
        case target_type
        when Type::StructType, Type::FlatType, Type::PtrType, Type::EnumType, Type::EnumVariantType
          then_seq = Opcode::Seq.new
          else_seq = Opcode::Seq.new

          body << Opcode::Push.new("ptr<#{target_type}>(")
          body << Opcode::Printf.new(0)

          then_seq << arg
          then_seq << Opcode::As.new(type)
          then_seq << Opcode::Deref.new
          then_seq << Opcode::Param.new(1)
          then_seq << Opcode::Inspect.new(internal: true)

          ptr_int_type = builder.layout.ptr_as_int_type(mod.typer)
          else_seq << arg
          else_seq << Opcode::As.new(ptr_int_type)
          else_seq << Opcode::Push.new(builder.layout.int_hex_format(ptr_int_type))
          else_seq << Opcode::Printf.new(1)

          body << Opcode::Param.new(0)
          body << Opcode::As.new(mod.typer.to_ptr(type, current_op.offset))
          body << Opcode::Deref.new
          body << Opcode::As.new(ptr_int_type)
          body << Opcode::Push.new(0_i64, ptr_int_type)
          body << Opcode::Binary.new(:not_eq)
          body << Opcode::If.new(then_seq, else_seq)

          body << Opcode::Push.new(")")
          body << Opcode::Printf.new(0)
        else
          ptr_int_type = builder.layout.ptr_as_int_type(mod.typer)
          body << arg
          body << Opcode::As.new(ptr_int_type)
          body << Opcode::Push.new("ptr<#{target_type}>(#{builder.layout.int_hex_format(ptr_int_type)})")
          body << Opcode::Printf.new(1)
        end
      end
    when Type::StructType
      body << Opcode::Push.new("#{type.id_name}(")
      body << Opcode::Printf.new(0)

      type.data.each_with_index do |subtype, index|
        if index != 0
          body << Opcode::Push.new(", ")
          body << Opcode::Printf.new(0)
        end

        body << arg
        body << Opcode::Field.new(index)
        body << Opcode::Param.new(1)
        body << Opcode::Inspect.new(internal: true)
      end

      body << Opcode::Push.new(")")
      body << Opcode::Printf.new(0)
    when Type::EnumVariantType
      body << Opcode::Push.new("#{type.id_name}(")
      body << Opcode::Printf.new(0)

      type.value_types.each_with_index do |subtype, index|
        if index != 0
          body << Opcode::Push.new(", ")
          body << Opcode::Printf.new(0)
        end
        body << arg
        body << Opcode::Field.new(index + 1)
        body << Opcode::Param.new(1)
        body << Opcode::Inspect.new(internal: true)
      end

      body << Opcode::Push.new(")")
      body << Opcode::Printf.new(0)
    when Type::FlatType
      body << Opcode::Push.new("#{type.id_name}(")
      body << Opcode::Printf.new(0)

      type.elements_count.times do |index|
        if index != 0
          body << Opcode::Push.new(", ")
          body << Opcode::Printf.new(0)
        end
        body << arg
        body << Opcode::Field.new(index.to_i32)
        body << Opcode::Param.new(1)
        body << Opcode::Inspect.new(internal: true)
      end

      body << Opcode::Push.new(")")
      body << Opcode::Printf.new(0)
    when Type::EnumType
      cases_seq = Array(Opcode::Seq).new
      tags_list = Array(Int64).new

      type.data.each do |_, child_type|
        seq = Opcode::Seq.new
        seq << arg
        seq << Opcode::As.new(child_type)
        seq << Opcode::Param.new(1)
        seq << Opcode::Inspect.new(internal: true)

        cases_seq << seq
        tags_list << child_type.position
      end

      else_seq = Opcode::Seq.new
      else_seq << arg
      else_seq << Opcode::Field.new(0)
      else_seq << Opcode::Push.new("#{type}::Undef(%d)")
      else_seq << Opcode::Printf.new(1)

      body << arg
      body << Opcode::Field.new(0)

      body << Opcode::Switch.new(cases_seq, tags_list, else_seq)
    else
      raise error("undefined for type: #{type}")
    end

    body << Opcode::Param.new(1)
    body << Opcode::Push.new(0_i64, mod.typer.i32)
    body << Opcode::Binary.new(:eq)
    then_seq = Opcode::Seq.new
    then_seq << Opcode::Push.new("\n")
    then_seq << Opcode::Printf.new(0)
    body << Opcode::If.new(then_seq, Opcode::Seq.new)

    @builder.new_func(fdef).build
  end

  def visit(op : Opcode::Binary)
    lhs = pop_rhs
    rhs = pop_rhs
    ltype = lhs.type
    rtype = rhs.type

    case ltype
    when Type::PtrType
      case rtype
      when Type::IntType
        if op.op.add? || op.op.sub?
          @stack << rhs
          visit Opcode::To.new(mod.typer.u64)
          visit Opcode::Unary.new(:neg) if op.op.sub?
          rhs = pop_rhs
          self << lhs.offset(self, rhs)
          return
        end
      when Type::PtrType
        if ltype.target_type.eq?(rtype.target_type) && op.op.sub?
          @stack << rhs
          visit Opcode::As.new(mod.typer.i64)
          @stack << lhs
          visit Opcode::As.new(mod.typer.i64)
          lhs = pop_rhs
          rhs = pop_rhs
          if res = @bb.binary(Opcode::Binary::Op::Sub, lhs, rhs)
            self << res
            visit Opcode::SizeOf.new(ltype.target_type)
            visit Opcode::As.new(mod.typer.i64)
            visit Opcode::Stack.new(:swap2)
            visit Opcode::Binary.new(:div)
            return
          end
        end
      end
    end

    unless ltype.eq?(rtype)
      if rhs2 = @bb.to?(rhs, rtype, ltype)
        rhs = rhs2
      else
        raise error("incompatible types #{ltype} #{op.op} #{rtype}")
      end
    end

    case ltype
    when Type::StructType, Type::FlatType, Type::EnumType
      raise error("undefined #{ltype} #{op.op} #{rtype}")
    end

    if result = @bb.binary(op.op, lhs, rhs)
      self << result
    else
      raise error("undefined #{ltype} #{op.op} #{rtype}")
    end
  end

  def visit(op : Opcode::Loop)
    init_bb = @bb.next("init")
    cond_bb = @bb.next("cond")
    body_bb = @bb.next("body")
    step_bb = @bb.next("step")
    finish_bb = @bb.next("endloop")

    loop_finish_stack << finish_bb
    loop_step_stack << step_bb

    @bb.jmp(init_bb)
    @bb = init_bb
    visit(op.init_seq)
    @bb.jmp(cond_bb)

    @bb = cond_bb
    visit(op.cond_seq)
    cond = pop_rhs
    raise error("COND must push bool, but found #{cond.type}") unless cond.type.eq?(mod.typer.bool)
    @bb.cond(cond, body_bb, finish_bb)

    @bb = body_bb
    visit(op.body_seq)
    @bb.jmp(step_bb)

    @bb = step_bb
    visit(op.step_seq)
    @bb.jmp(cond_bb)

    loop_finish_stack.pop
    loop_step_stack.pop

    @bb = finish_bb
  end

  def visit(op : Opcode::Local)
    local = @locals.put_if_absent(op.name) do
      if type = op.type
        @func.alloca_bb.alloca(op.name, type)
      else
        raise error("first usage of local variable #{op.name}, should specify type")
      end
    end

    if (type = op.type) && !local.type.eq?(type)
      raise error("local variable #{op.name} was created with another type #{local.type}, current #{type}")
    end

    self << local
  end

  def visit(op : Opcode::Store)
    lhs = pop_lhs
    rhs = pop_rhs

    unless lhs.type.eq?(rhs.type)
      if rhs2 = @bb.to?(rhs, rhs.type, lhs.type)
        rhs = rhs2
      else
        raise error("incompatible types, trying #{lhs.type} = #{rhs.type}")
      end
    end

    raise error("Global is constant") if lhs.pp.is_a?(Value::PP::GlobalConstant)

    lhs.store(self, rhs)
  end

  def visit(op : Opcode::Break)
    if finish_bb = loop_finish_stack.last?
      @bb.jmp(finish_bb)
      @bb = fake_bb
    else
      raise error("loop not found")
    end
  end

  def visit(op : Opcode::Next)
    if step_bb = loop_step_stack.last?
      @bb.jmp(step_bb)
      @bb = fake_bb
    else
      raise error("loop not found")
    end
  end

  def visit(op : Opcode::Param)
    params_count = @params.size

    if op.index >= params_count || op.index < 0
      raise error("incorrect index: #{op.index}, should be in 0...#{params_count - 1}")
    end

    self << @params[op.index]
  end

  def visit(op : Opcode::Call)
    type_fn = find_func_type_fn(op.name)
    raise error("func #{op.name} not found") unless type_fn

    types = type_fn.args
    args = types.size.times.map do |index|
      arg = pop_rhs
      if arg.type.eq?(types[index])
        arg
      else
        if arg2 = @bb.to?(arg, arg.type, types[index])
          arg2
        else
          raise error("bad arg #{index} type, expected: #{types[index]}, got: #{arg.type}, type_fn: #{type_fn.id_name}")
        end
      end
    end.to_a

    if type_fn.vaarg
      op.vaargs_count.times do
        case t = last.type
        when Type::IntType
          if t.bytes_count < 4
            visit Opcode::To.new(mod.typer.i32)
          end
        when Type::FloatType
          if t.bytes_count == 4
            visit Opcode::To.new(mod.typer.f64)
          end
        end
        args << pop_rhs
      end
    else
      if op.vaargs_count > 0
        raise error("function #{op.name} have no vaargs, but passes #{op.vaargs_count}")
      end
    end

    if value = @bb.call(op.name, type_fn, args)
      self << value
    end
  end

  def visit(op : Opcode::Invoke)
    fn_ptr = pop_rhs

    case type_fn = fn_ptr.type
    when Type::Fn
    else
      raise error("INVOKE expected fn type, got #{type_fn}")
    end

    types = type_fn.args
    args = types.size.times.map do |index|
      arg = pop_rhs
      if arg.type.eq?(types[index])
        arg
      else
        if arg2 = @bb.to?(arg, arg.type, types[index])
          arg2
        else
          raise error("bad arg #{index} type, expected: #{types[index]}, got: #{arg.type}, type_fn: #{type_fn.id_name}")
        end
      end
    end.to_a

    if type_fn.vaarg
      op.vaargs_count.times do
        case t = last.type
        when Type::FloatType
          if t.bytes_count == 4
            visit Opcode::To.new(mod.typer.f64)
          end
        end
        args << pop_rhs
      end
    else
      if op.vaargs_count > 0
        raise error("function pointer has no vaargs, but passes #{op.vaargs_count}")
      end
    end

    case _pp = fn_ptr.pp
    when Value::PP::FnAddress
      if value = @bb.call(_pp.name, type_fn, args)
        self << value
      end
    else
      if value = @bb.invoke(fn_ptr, type_fn, args)
        self << value
      end
    end
  end

  def visit(op : Opcode::Ret)
    if res = @func.result
      @was_ret = true
      value = pop_rhs
      unless res.type.eq?(value.type)
        if value2 = @bb.to?(value, value.type, res.type)
          value = value2
        else
          raise error("type mismatch: expected #{res.type}, got #{value.type}")
        end
      end
      res.store(self, value)
    end

    @bb.jmp(@func.ret_bb)
    @bb = fake_bb
  end

  def visit(op : Opcode::Malloc)
    visit Opcode::As.new(mod.typer.u64)
    visit Opcode::SizeOf.new(op.type)
    visit Opcode::Stack.new(:swap2)
    visit Opcode::Call.new("calloc")
    visit Opcode::As.new(mod.typer.to_ptr(op.type, op.offset))
  end

  def visit(op : Opcode::SizeOf)
    if type = op.type
      visit Opcode::Push.new(builder.layout.size_of(type).to_i64, mod.typer.u64)
    else
      value = pop
      visit Opcode::Push.new(builder.layout.size_of(value.type).to_i64, mod.typer.u64)
    end
  end

  def visit(op : Opcode::Stack)
    case op.shift
    in .swap2?
      raise error("Stack underflow: need 2 values") if stack.size < 2
      a = stack.pop
      b = stack.pop
      stack << a
      stack << b
    in .dup?
      raise error("Stack underflow: need 1 value") if stack.size < 1
      stack << stack.last
    in .drop?
      raise error("Stack underflow: need 1 value") if stack.size < 1
      if amount = op.val
        amount.times { stack.pop }
      else
        stack.pop
      end
    in .over?
      raise error("Stack underflow: need 2 values") if stack.size < 2
      a = stack.pop
      b = stack.last
      stack << a
      stack << b
    in .rot?
      raise error("Stack underflow: need 3 values") if stack.size < 3
      a = stack.pop
      b = stack.pop
      c = stack.pop
      stack << a
      stack << c
      stack << b
    in .nrot?
      raise error("Stack underflow: need 3 values") if stack.size < 3
      a = stack.pop
      b = stack.pop
      c = stack.pop
      stack << b
      stack << a
      stack << c
    in .dup2?
      raise error("Stack underflow: need 2 values") if stack.size < 2
      a = stack.pop
      b = stack.pop
      stack << b
      stack << a
      stack << b
      stack << a
    in .drop2?
      raise error("Stack underflow: need 2 values") if stack.size < 2
      stack.pop
      stack.pop
    end
  end

  def visit(op : Opcode::As)
    value = pop
    from_type = value.type
    to_type = op.type

    if from_type.eq?(to_type)
      self << value
      return
    end

    case {from_type, to_type}
    when {Type::EnumType, Type::EnumVariantType}
      if from_type.eq?(to_type.parent_type)
        self << value.unsafe_new_with_type(to_type)
        return
      else
        raise error("incompatible types #{from_type} #{to_type}")
      end
    when {Type::EnumVariantType, Type::EnumType}
      if to_type.eq?(from_type.parent_type)
        self << value.unsafe_new_with_type(to_type)
        return
      else
        raise error("incompatible types #{from_type} #{to_type}")
      end
    end

    if to_type.is_a?(Type::FlatType) || from_type.is_a?(Type::FlatType)
      from_size = builder.layout.size_of(from_type)
      to_size = builder.layout.size_of(to_type)
      if from_size >= to_size
        self << value._to_ref(self).bitcast_flat(self, to_type)
        return
      else
        raise error("#{from_type}(#{from_size}) < #{to_type}(#{to_size})")
      end
    end

    if result = @bb.cast?(value.to_rhs(self), from_type, to_type)
      self << result
    else
      raise error("unknown transform from #{from_type} to #{to_type}")
    end
  end

  def visit(op : Opcode::To)
    value = pop
    from_type = value.type
    to_type = op.type

    if from_type.eq?(to_type)
      self << value
      return
    end

    if result = @bb.to?(value.to_rhs(self), from_type, to_type)
      self << result
    else
      raise error("unknown safe transform from #{from_type} to #{to_type}, use AS if you sure")
    end
  end

  def visit(op : Opcode::Switch)
    index = pop_rhs

    unless index.type.is_a?(Type::IntType)
      raise error("index should be int type, not #{index.type}")
    end

    case_values = op.values.map do |value|
      if val = builder.constant_value?(value, index.type)
        val
      else
        raise error("cant create constant for #{value}, type: #{index.type}")
      end
    end

    case_bbs = op.cases_seq.map { @bb.next("switch_case") }
    default_bb = @bb.next("switch_default")
    end_bb = @bb.next("switch_end")

    @bb.switch(index, case_values, case_bbs, default_bb)

    case_bbs.each_with_index do |case_bb, i|
      @bb = case_bb
      visit(op.cases_seq[i])
      @bb.jmp(end_bb)
    end

    @bb = default_bb
    visit(op.else_seq)
    @bb.jmp(end_bb)

    @bb = end_bb
  end

  def visit(op : Opcode::Unary)
    value = pop_rhs
    result = @bb.unary(op.op, value)

    unless result
      raise error("unknown unary for #{value.type}")
    end

    self << result
  end

  def visit(op : Opcode::Global)
    if global = @builder.find_global(op.name)
      self << global
    else
      raise error("global not found #{op.name}")
    end
  end

  def visit(op : Opcode::Select)
    cond = pop_rhs
    arg_true = pop_rhs
    arg_false = pop_rhs

    unless cond.type.eq?(mod.typer.bool)
      raise error("cond exected bool type, but got #{cond.type}")
    end

    unless arg_false.type.eq?(arg_true.type)
      raise error("different values types #{arg_false.type} and #{arg_true.type}")
    end

    self << @bb.select(cond, arg_true, arg_false)
  end

  def visit(op : Opcode::Deref)
    self << pop.deref(self)
  end

  def visit(op : Opcode::Addr)
    if fn = op.func_name
      if func_def = mod.func_defs[fn]?
        self << @bb.fn_addr(fn, func_def.type_fn)
      else
        raise error("`#{fn}` not found")
      end
    else
      self << pop._to_ref(self).addr(self)
    end
  end

  def visit(op : Opcode::Field)
    raise error("invalid index #{op.index}") if op.index < 0

    value = pop

    case type = value.type
    when Type::EnumVariantType
      if op.index >= 1 && op.index <= type.value_types.size
        value = value.field(self, 1)
        @stack << value
        if ct = type.composite_value_type
          visit Opcode::As.new(ct)
          visit Opcode::Field.new(op.index - 1)
        else
          raise error("no composite type for #{type}, bug")
        end
        return
      end
    end

    self << value.field(self, op.index)
  end

  def visit(op : Opcode::Create)
    case type = op.type
    when Type::StructType
      local_name = next_unique("__myc_create_struct")

      type.data.size.times do |index|
        visit Opcode::Local.new(local_name, type)
        visit Opcode::Field.new(index)
        visit Opcode::Store.new
      end

      visit Opcode::Local.new(local_name, type)

      if local = @locals[local_name]?
        local.pp = Value::PP::Local.new(local_name)
      end
    when Type::FlatType
      local_name = next_unique("__myc_create_flat")

      type.elements_count.times do |index|
        visit Opcode::Local.new(local_name, type)
        visit Opcode::Field.new(index.to_i32)
        visit Opcode::Store.new
      end

      visit Opcode::Local.new(local_name, type)

      if local = @locals[local_name]?
        local.pp = Value::PP::Local.new(local_name)
      end
    when Type::EnumType
      raise error("Cant create enum directly, just create variant and cast with AS")
    when Type::EnumVariantType
      local_name = next_unique("__myc_create_enum")

      visit Opcode::Push.new(type.position.to_i64, mod.typer.i32)
      visit Opcode::Local.new(local_name, type)
      visit Opcode::Field.new(0)
      visit Opcode::Store.new

      type.value_types.size.times do |index|
        visit Opcode::Local.new(local_name)
        visit Opcode::Field.new(index + 1)
        visit Opcode::Store.new
      end
      visit Opcode::Local.new(local_name)
    else
      raise error("CREATE only for composite types, not for #{type}")
    end
  end

  def visit(op : Opcode::Label)
    raise error("label already defined `#{op.label}`") if @labels[op.label]?
    new_bb = @pending_labels.delete(op.label) || @bb.next(op.label)
    @labels[op.label] = new_bb
    @bb.jmp(new_bb)
    @bb = new_bb
  end

  def visit(op : Opcode::Goto)
    goto_bb = @labels[op.label]? || @pending_labels[op.label]? || (@pending_labels[op.label] = @bb.next(op.label))
    @bb.jmp(goto_bb)
    @bb = fake_bb
  end

  def visit(op : Opcode)
    raise error("fallback method, should not be called #{op.inspect}")
  end

  private def debug_stack : String
    String.build do |s|
      index = 0
      @stack.reverse_each do |value|
        s << ", " if index != 0
        s << value.mm.short_name
        s << '('
        s << value.type.to_s
        s << ':'
        s << value.pp.short_name
        s << ")"
        index += 1

        if (index > 4)
          s << ", ..."
          break
        end
      end
    end
  end

  def next_unique(tag : String) : String
    @unique_id += 1
    "#{tag}_#{@unique_id}"
  end
end
