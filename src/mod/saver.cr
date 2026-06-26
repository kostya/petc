class Myc::Mod::Saver
  def initialize(@mod : Mod, @notes = Hash(Opcode, String).new)
  end

  def save : Source::Dom
    dom = Source::Dom.new

    @mod.type_defs.each_value do |type|
      case type = type.type
      when Type::StructType
        dom.sections << save_struct(type)
      when Type::EnumType
        dom.sections << save_enum(type)
      when Type::FlatType
        dom.sections << save_flat(type)
      end
    end

    @mod.global_defs.each do |global|
      dom.sections << save_global(global)
    end

    @mod.func_defs.each do |_, f|
      unless f.body
        dom.sections << save_func(f)
      end
    end

    @mod.func_defs.each do |_, f|
      if f.body
        dom.sections << save_func(f)
      end
    end

    dom
  end

  private macro opcode(code, *values)
    %node = Source::Node::Opcode.new({{code}})
    {% unless values.empty? %}
      %node.values = [{{values.splat}}] of Source::Token::ArgType
    {% end %}
    %node
  end

  private macro container(code, *values)
    %node = Source::Node::Container.new({{code}})
    {% unless values.empty? %}
      %node.values = [{{values.splat}}] of Source::Token::ArgType
    {% end %}
    %node
  end

  private macro sequence(code, *values)
    %node = Source::Node::Sequence.new({{code}})
    {% unless values.empty? %}
      %node.values = [{{values.splat}}] of Source::Token::ArgType
    {% end %}
    %node
  end

  private def save_type(type : Type)
    opcode(Opcode::Code::TYPE, type.id_name)
  end

  private def save_struct(type : Type::StructType)
    node = sequence(Opcode::Code::STRUCT, type.id_name)

    if ea = type.explicit_alignment
      node.list << opcode(Opcode::Code::ALIGN, ea.to_i64)
    end

    type.data.each { |t| node.list << save_type(t) }
    node
  end

  private def save_enum(type : Type::EnumType)
    node = container(Opcode::Code::ENUM, type.id_name)

    if ea = type.explicit_alignment
      node.sections << opcode(Opcode::Code::ALIGN, ea.to_i64)
    end

    type.data.each do |_, variant_type|
      v_node = sequence(Opcode::Code::VARIANT, variant_type.original_name)

      variant_type.value_types.each do |child_type|
        v_node.list << save_type(child_type)
      end

      node.sections << v_node
    end

    node
  end

  private def save_flat(type : Type::FlatType)
    node = sequence(Opcode::Code::FLAT, type.id_name)
    if ea = type.explicit_alignment
      node.list << opcode(Opcode::Code::ALIGN, ea.to_i64)
    end
    node.list << save_type(type.target_type)
    node.list << opcode(Opcode::Code::COUNT, type.elements_count.to_i64)
    node
  end

  private def save_global(global)
    g_node = sequence(Opcode::Code::GLOBAL, global.name)
    g_node.list << save_type(global.type)

    if init = global.initial_value
      init_node = opcode(Opcode::Code::INITIAL, init)
      g_node.list << init_node
    end

    if global.constant
      g_node.list << opcode(Opcode::Code::CONSTANT)
    end

    g_node
  end

  def save_func(func_def : Mod::FuncDef)
    node = container(Opcode::Code::FUNC, func_def.name)

    locals_saved = Set(String).new

    if func_def.type_fn.args.any?
      args_node = sequence(Opcode::Code::ARGS)
      func_def.type_fn.args.each { |t| args_node.list << save_type(t) }
      node.sections << args_node
    end

    if (ret = func_def.type_fn.ret) && !ret.eq?(func_def.mod.typer.void)
      ret_node = sequence(Opcode::Code::RETURN)
      ret_node.list << save_type(ret)
      node.sections << ret_node
    end

    if attrs = func_def.attributes
      attrs_node = sequence(Opcode::Code::ATTRIBUTES)
      attrs.each { |attr| attrs_node.list << opcode(Opcode::Code::ATTR, attr) }
      node.sections << attrs_node
    end

    if body = func_def.body
      body_node = sequence(Opcode::Code::BODY)
      node.sections << body_node
      save_seq_list(body, body_node, locals_saved)
    end

    node
  end

  private def save_opcode(op : Opcode, locals_saved : Set(String))
    node = case op
           when Opcode::As      then opcode(Opcode::Code::AS, op.type.id_name)
           when Opcode::To      then opcode(Opcode::Code::TO, op.type.id_name)
           when Opcode::Binary  then opcode(Opcode::Code::BINARY, op.op.to_s.underscore)
           when Opcode::Break   then opcode(Opcode::Code::BREAK)
           when Opcode::Call    then op.vaargs_count > 0 ? opcode(Opcode::Code::CALL, op.name, op.vaargs_count.to_i64) : opcode(Opcode::Code::CALL, op.name)
           when Opcode::Field   then opcode(Opcode::Code::FIELD, op.index.to_i64)
           when Opcode::Global  then opcode(Opcode::Code::GLOBAL, op.name)
           when Opcode::If      then save_if(op, locals_saved)
           when Opcode::Inspect then opcode(Opcode::Code::INSPECT)
           when Opcode::Local
             if locals_saved.includes?(op.name)
               opcode(Opcode::Code::LOCAL, op.name)
             else
               locals_saved << op.name
               if op.type
                 opcode(Opcode::Code::LOCAL, op.name, op.type.not_nil!.id_name)
               else
                 opcode(Opcode::Code::LOCAL, op.name)
               end
             end
           when Opcode::Loop   then save_loop(op, locals_saved)
           when Opcode::Malloc then opcode(Opcode::Code::MALLOC, op.type.id_name)
           when Opcode::SizeOf then op.type ? opcode(Opcode::Code::SIZEOF, op.type.not_nil!.id_name) : opcode(Opcode::Code::SIZEOF)
           when Opcode::Next   then opcode(Opcode::Code::NEXT)
           when Opcode::Param  then opcode(Opcode::Code::PARAM, op.index.to_i64)
           when Opcode::Printf then opcode(Opcode::Code::PRINTF, op.args_count.to_i64)
           when Opcode::Deref  then opcode(Opcode::Code::DEREF)
           when Opcode::Push   then op.type ? opcode(Opcode::Code::PUSH, op.value, op.type.not_nil!.id_name) : opcode(Opcode::Code::PUSH, op.value)
           when Opcode::Ret    then opcode(Opcode::Code::RET)
           when Opcode::Store  then opcode(Opcode::Code::STORE)
           when Opcode::Switch then save_switch(op, locals_saved)
           when Opcode::Unary  then opcode(Opcode::Code::UNARY, op.op.to_s.underscore)
           when Opcode::Stack  then op.val ? opcode(Opcode::Code::STACK, op.shift.to_s.underscore, op.val.not_nil!) : opcode(Opcode::Code::STACK, op.shift.to_s.underscore)
           when Opcode::Select then opcode(Opcode::Code::SELECT)
           when Opcode::Create then opcode(Opcode::Code::CREATE, op.type.id_name)
           when Opcode::Addr   then opcode(Opcode::Code::ADDR)
           else                     raise "unknown opcode #{op.class}"
           end

    if note = @notes[op]?
      node.comment = "; [#{note}]"
    end

    node
  end

  protected def save_seq_list(seq : Opcode::Seq, res : Source::Node::Sequence, locals_saved)
    seq.list.each { |op| res.list << save_opcode(op, locals_saved).as(Source::Node) }
  end

  private def save_if(op : Opcode::If, locals_saved)
    node = container(Opcode::Code::IF)

    then_node = sequence(Opcode::Code::THEN)
    node.sections << then_node
    save_seq_list(op.then_seq, then_node, locals_saved)

    if op.else_seq && op.else_seq.list.any?
      else_node = sequence(Opcode::Code::ELSE)
      node.sections << else_node
      save_seq_list(op.else_seq, else_node, locals_saved)
    end

    node
  end

  private def save_loop(op : Opcode::Loop, locals_saved)
    node = container(Opcode::Code::LOOP)

    if op.init_seq && op.init_seq.list.any?
      init_node = sequence(Opcode::Code::INIT)
      node.sections << init_node
      save_seq_list(op.init_seq, init_node, locals_saved)
    end

    if op.cond_seq && op.cond_seq.list.any?
      cond_node = sequence(Opcode::Code::COND)
      node.sections << cond_node
      save_seq_list(op.cond_seq, cond_node, locals_saved)
    end

    body_node = sequence(Opcode::Code::BODY)
    node.sections << body_node
    save_seq_list(op.body_seq, body_node, locals_saved)

    if op.step_seq && op.step_seq.list.any?
      step_node = sequence(Opcode::Code::STEP)
      node.sections << step_node
      save_seq_list(op.step_seq, step_node, locals_saved)
    end

    node
  end

  private def save_switch(op : Opcode::Switch, locals_saved)
    node = container(Opcode::Code::SWITCH)

    op.cases_seq.each_with_index do |case_seq, index|
      case_node = sequence(Opcode::Code::CASE)
      case_node.values = [op.values[index]] of Source::Token::ArgType
      node.sections << case_node
      save_seq_list(case_seq, case_node, locals_saved)
    end

    if op.else_seq && op.else_seq.list.any?
      else_node = sequence(Opcode::Code::ELSE)
      node.sections << else_node
      save_seq_list(op.else_seq, else_node, locals_saved)
    end

    node
  end
end
