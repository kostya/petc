class Myc::Mycc::Builder
  getter io : IO::Memory
  getter source : Source
  getter tu : Clang::TranslationUnit

  enum Scope
    FuncBody
    FuncArgs
    LoopBody
    SwitchBody
  end

  BINARY_MAP = {
    "+" => "add", "-" => "sub", "*" => "mul", "/" => "div",
    "<" => "less", ">" => "more", "<=" => "less_eq", ">=" => "more_eq",
    "==" => "eq", "!=" => "not_eq", "%" => "rem",
    "&&" => "and", "||" => "or",
    "&" => "and", "|" => "or", "^" => "xor", "<<" => "shl", ">>" => "lshr",
  }

  def initialize(@source, @tu)
    @io = IO::Memory.new
    @indent = 0
    @params = {} of String => Int32
    @vars = {} of String => String
    @structs = {} of String => Array({String, String})
    @stack = Deque(Scope).new
  end

  def visit(cursor : Clang::Cursor, in_statement = false)
    return if skip_system?(cursor)
    Myc.debug(:myc) { puts "VISIT: `#{cursor.inspect}`" }

    case cursor.kind
    when .function_decl?        then visit_func_def(cursor)
    when .compound_stmt?        then visit_children(cursor, in_statement: true)
    when .call_expr?            then visit_call(cursor)
    when .decl_stmt?            then visit_children(cursor)
    when .var_decl?             then visit_var_decl(cursor)
    when .binary_operator?      then visit_binary(cursor)
    when .integer_literal?      then visit_int_literal(cursor)
    when .string_literal?       then visit_string_literal(cursor)
    when .decl_ref_expr?        then visit_id(cursor)
    when .return_stmt?          then visit_return(cursor)
    when .if_stmt?              then visit_if(cursor)
    when .while_stmt?           then visit_while(cursor)
    when .for_stmt?             then visit_for(cursor)
    when .unary_operator?       then visit_unary(cursor, in_statement: in_statement)
    when .unary_expr?           then visit_builtin_expr(cursor)
    when .break_stmt?           then visit_break(cursor)
    when .continue_stmt?        then visit_continue(cursor)
    when .member_ref_expr?      then visit_field(cursor)
    when .struct_decl?          then visit_struct_decl(cursor)
    when .switch_stmt?          then visit_switch(cursor)
    when .case_stmt?            then visit_case(cursor)
    when .default_stmt?         then visit_default(cursor)
    when .floating_literal?     then visit_float_literal(cursor)
    when .character_literal?    then visit_char_literal(cursor)
    when .c_style_cast_expr?    then visit_cast(cursor)
    when .init_list_expr?       then visit_init_list_expr(cursor)
    when .array_subscript_expr? then visit_subscript(cursor)
    when .paren_expr?           then visit_children(cursor)
    else
      Myc.debug(:myc) { puts "  SKIP: #{cursor.kind}" }
      visit_children(cursor)
    end
  end

  private def collect_children(cursor : Clang::Cursor) : Array(Clang::Cursor)
    children = [] of Clang::Cursor
    cursor.visit_children do |child|
      children << child
      Clang::ChildVisitResult::Continue
    end
    children
  end

  private def visit_children(cursor : Clang::Cursor, in_statement = false)
    cursor.visit_children do |child|
      visit(child, in_statement)
      Clang::ChildVisitResult::Continue
    end
  end

  def visit_func_def(cursor : Clang::Cursor)
    clear
    func_name = cursor.spelling

    emit("FUNC :#{func_name}")
    @indent += 1

    children = collect_children(cursor)
    params = children.select(&.kind.parm_decl?)

    unless params.empty?
      emit("ARGS")
      @indent += 1
      params.each_with_index do |param, idx|
        param_name = param.spelling
        @params[param_name] = idx
        param_type = get_type(param.type)
        emit("  TYPE :#{param_type}")
      end
      @indent -= 1
    end

    ret_type = get_type(cursor.result_type)
    if ret_type != "void"
      emit("RETURN")
      @indent += 1
      emit("  TYPE :#{ret_type}")
      @indent -= 1
    end

    emit("BODY")
    @indent += 1
    @stack << Scope::FuncBody
    visit_children(cursor)
    @stack.pop
    @indent -= 1

    emit("ENDFUNC")
    @indent -= 1
  end

  def visit_var_decl(cursor : Clang::Cursor)
    var_name = cursor.spelling
    var_type = get_type(cursor.type)
    @vars[var_name] = var_type

    children = collect_children(cursor)
    init = children.find { |c| !c.kind.decl_ref_expr? }

    if init
      if init.kind.init_list_expr?
        visit(init)
        emit("CREATE :#{var_type}")
        emit("LOCAL :#{var_name} :#{var_type}")
        emit("STORE")
      else
        visit(init)
        emit("LOCAL :#{var_name} :#{var_type}")
        emit("STORE")
      end
    else
      zero = default_zero(var_type)
      emit("PUSH #{zero}")
      emit("LOCAL :#{var_name} :#{var_type}")
      emit("STORE")
    end
  end

  def visit_struct_decl(cursor : Clang::Cursor)
    struct_name = cursor.spelling
    return if struct_name.empty?

    fields = [] of {String, String}

    cursor.visit_children do |child|
      if child.kind.field_decl?
        field_name = child.spelling
        field_type = get_type(child.type)
        fields << {field_name, field_type}
      end
      Clang::ChildVisitResult::Continue
    end

    @structs[struct_name] = fields

    emit("STRUCT :#{struct_name}")
    @indent += 1
    fields.each { |_, type| emit("TYPE :#{type}") }
    @indent -= 1
    emit("ENDSTRUCT")
  end

  def visit_call(cursor : Clang::Cursor)
    func_name = cursor.spelling
    args = cursor.arguments

    case func_name
    when "printf"
      args.reverse.each { |arg| visit(arg) }
      emit("PRINTF #{args.size - 1}")
    when "malloc"
      args.reverse.each { |arg| visit(arg) }
      emit("CALL :malloc")
    when "free"
      args.reverse.each { |arg| visit(arg) }
      emit("CALL :free")
    else
      args.reverse.each { |arg| visit(arg) }
      emit("CALL :#{func_name}")
    end
  end

  def visit_binary(cursor : Clang::Cursor)
    op = cursor.spelling
    if op == "="
      visit_assignment(cursor)
      return
    end
    children = collect_children(cursor)

    if children.size >= 2
      visit(children[1])
      visit(children[0])
    end

    op_name = BINARY_MAP[op]? || op
    emit("BINARY :#{op_name}")
  end

  def visit_assignment(cursor : Clang::Cursor)
    children = collect_children(cursor)
    visit(children[1])
    visit(children[0])
    emit("STORE")
  end

  def visit_unary(cursor : Clang::Cursor, in_statement : Bool)
    op = cursor.spelling

    if op.empty?
      @tu.tokenize(cursor.extent) do |token|
        if token.kind.punctuation? && {"++", "--", "-", "!", "~", "*", "&"}.includes?(token.spelling)
          op = token.spelling
          break
        end
      end
    end

    children = collect_children(cursor)

    case op
    when "++", "--"
      child = children[0]?
      return unless child

      var_name = child.spelling
      is_increment = op == "++"
      bin_op = is_increment ? "add" : "sub"
      is_prefix = is_prefix_unary?(cursor)
      is_statement = in_statement

      if is_prefix
        emit("PUSH 1 :i32")
        emit_id(var_name)
        emit("BINARY :#{bin_op}")
        emit_id(var_name)
        emit("STORE")
        emit_id(var_name)
      else
        if is_statement
          emit("PUSH 1 :i32")
          emit_id(var_name)
          emit("BINARY :#{bin_op}")
          emit_id(var_name)
          emit("STORE")
        else
          tmp_name = "__tmp_#{@vars.size}"
          var_type = @vars[var_name]? || "i32"
          @vars[tmp_name] = var_type

          emit_id(var_name)
          emit("LOCAL :#{tmp_name} :#{var_type}")
          emit("STORE")

          emit("PUSH 1 :i32")
          emit_id(var_name)
          emit("BINARY :#{bin_op}")
          emit_id(var_name)
          emit("STORE")

          emit("LOCAL :#{tmp_name} :#{var_type}")

          @vars.delete(tmp_name)
        end
      end
    when "-"
      emit_unless_empty(children) { visit(children[0]) }
      emit("UNARY :neg")
    when "!"
      emit_unless_empty(children) { visit(children[0]) }
      emit("UNARY :lnot")
    when "~"
      emit_unless_empty(children) { visit(children[0]) }
      emit("UNARY :bnot")
    when "*"
      emit_unless_empty(children) { visit(children[0]) }
      emit("DEREF")
    when "&"
      emit_unless_empty(children) { visit(children[0]) }
      emit("ADDR")
    end
  end

  private def is_prefix_unary?(cursor : Clang::Cursor) : Bool
    tokens = [] of String
    @tu.tokenize(cursor.extent) do |token|
      tokens << token.spelling
    end
    tokens.first? == "++" || tokens.first? == "--"
  end

  private def emit_unless_empty(children : Array(Clang::Cursor), &)
    unless children.empty?
      yield
    end
  end

  def emit_id(name : String)
    if @vars.has_key?(name)
      emit("LOCAL :#{name} :#{@vars[name]}")
    elsif @params.has_key?(name)
      emit("PARAM #{@params[name]}")
    end
  end

  def visit_cast(cursor : Clang::Cursor)
    target_type = get_type(cursor.type)
    children = collect_children(cursor)

    if children.size > 0
      visit(children[0])
    end

    emit("AS :#{target_type}")
  end

  def visit_builtin_expr(cursor : Clang::Cursor)
    op = ""
    @tu.tokenize(cursor.extent) do |token|
      if token.kind.keyword?
        op = token.spelling
        break
      end
    end

    case op
    when "sizeof" then visit_sizeof(cursor)
      # when "alignof" then visit_alignof(cursor)
    else visit_children(cursor)
    end
  end

  def visit_sizeof(cursor : Clang::Cursor)
    children = collect_children(cursor)
    if children.size == 1 && children[0].kind.unexposed_expr?
      emit("PUSH 8 :i32")
    else
      type_name = get_type(cursor.type)
      emit("SIZEOF :#{type_name}")
      emit("AS :i32")
    end
  end

  def visit_field(cursor : Clang::Cursor)
    obj_name = cursor.spelling
    field_name = ""

    is_arrow = cursor.type.kind.pointer? || false

    if @vars.has_key?(obj_name)
      var_type = @vars[obj_name]
      emit("LOCAL :#{obj_name} :#{var_type}")

      if is_arrow
        emit("DEREF")
      end

      struct_name = extract_struct_name(var_type)
      if fields = @structs[struct_name]?
        if idx = fields.index { |name, _| name == field_name }
          emit("FIELD #{idx}")
        end
      end
    end
  end

  def visit_int_literal(cursor : Clang::Cursor)
    value = extract_literal_value(cursor)
    clean_value = value.gsub(/[LlUu]+$/, "")
    lit_type = get_type(cursor.type)
    decimal_value = parse_c_int_literal(clean_value)
    emit("PUSH #{decimal_value} :#{lit_type}")
  end

  private def parse_c_int_literal(value : String) : String
    if value.starts_with?("0b") || value.starts_with?("0B")
      value[2..].to_i64(base: 2).to_s
    elsif value.starts_with?("0x") || value.starts_with?("0X")
      value[2..].to_i64(base: 16).to_s
    elsif value.starts_with?('0') && value.size > 1 && !value.includes?('.')
      value[1..].to_i64(base: 8).to_s
    else
      value
    end
  end

  def visit_char_literal(cursor : Clang::Cursor)
    value = extract_literal_value(cursor)

    if value && value.size >= 3 && value[0] == '\''
      ch = value[1]
      emit("PUSH #{ch.ord} :u8")
    elsif value =~ /^\d+$/
      emit("PUSH #{value} :u8")
    end
  end

  def visit_float_literal(cursor : Clang::Cursor)
    value = extract_literal_value(cursor)
    clean_value = value.gsub(/[fFlL]$/, "")
    lit_type = get_type(cursor.type)
    emit("PUSH #{clean_value} :#{lit_type}")
  end

  private def extract_literal_value(cursor : Clang::Cursor) : String
    unless cursor.spelling.empty?
      return cursor.spelling
    end

    @tu.tokenize(cursor.extent) do |token|
      if token.kind.literal?
        return token.spelling
      end
    end

    "0"
  end

  def visit_string_literal(cursor : Clang::Cursor)
    emit("PUSH #{cursor.spelling}")
  end

  def visit_id(cursor : Clang::Cursor)
    name = cursor.spelling
    if @vars.has_key?(name)
      var_type = @vars[name]
      if var_type.starts_with?("array<")
        emit("LOCAL :#{name} :#{var_type}")

        emit("ADDR")
      else
        emit("LOCAL :#{name} :#{var_type}")
      end
    elsif @params.has_key?(name)
      emit("PARAM #{@params[name]}")
    end
  end

  def visit_return(cursor : Clang::Cursor)
    visit_children(cursor)
    emit("RET")
  end

  def visit_if(cursor : Clang::Cursor)
    children = collect_children(cursor)

    visit(children[0])
    emit("AS :bool")
    emit("IF")
    @indent += 1

    emit("THEN")
    @indent += 1
    visit(children[1])
    @indent -= 1

    if children.size > 2
      emit("ELSE")
      @indent += 1
      visit(children[2])
      @indent -= 1
    end

    @indent -= 1
    emit("ENDIF")
  end

  def visit_while(cursor : Clang::Cursor)
    children = collect_children(cursor)

    emit("LOOP")
    @indent += 1
    @stack << Scope::LoopBody

    emit("COND")
    @indent += 1
    visit(children[0])
    emit("AS :bool")
    @indent -= 1

    emit("BODY")
    @indent += 1
    visit(children[1])
    @indent -= 1

    emit("STEP")
    @stack.pop
    @indent -= 1
    emit("ENDLOOP")
  end

  def visit_for(cursor : Clang::Cursor)
    children = collect_children(cursor)
    visit(children[0]) if children.size > 0

    emit("LOOP")
    @indent += 1
    @stack << Scope::LoopBody

    if children.size > 1
      emit("COND")
      @indent += 1
      visit(children[1])
      emit("AS :bool")
      @indent -= 1
    end

    if children.size > 3
      emit("BODY")
      @indent += 1
      visit(children[3])
      @indent -= 1
    end

    emit("STEP")
    visit(children[2], in_statement: true) if children.size > 2

    @stack.pop
    @indent -= 1
    emit("ENDLOOP")
  end

  def visit_switch(cursor : Clang::Cursor)
    children = collect_children(cursor)

    visit(children[0])
    emit("SWITCH")
    @indent += 1
    @stack << Scope::SwitchBody

    visit(children[1])

    @stack.pop
    @indent -= 1
    emit("ENDSWITCH")
  end

  def visit_case(cursor : Clang::Cursor)
    children = collect_children(cursor)

    if children.size > 0
      value_text = extract_literal_value(children[0])
      emit("CASE #{value_text}")
    end

    @indent += 1
    children[1..].each { |c| visit(c) }
    @indent -= 1
  end

  def visit_default(cursor : Clang::Cursor)
    emit("ELSE")
    @indent += 1
    visit_children(cursor)
    @indent -= 1
  end

  def visit_break(cursor : Clang::Cursor)
    if @stack.includes?(Scope::SwitchBody)
      return
    end

    if @stack.includes?(Scope::LoopBody)
      emit("BREAK")
    end
  end

  def visit_continue(cursor : Clang::Cursor)
    emit("NEXT")
  end

  def visit_sizeof(cursor : Clang::Cursor)
    children = collect_children(cursor)

    if children.size > 0
      child_type = get_type(children[0].type)
    else
      child_type = get_type(cursor.type)
    end

    emit("SIZEOF :#{child_type}")
    emit("AS :i32")
  end

  def visit_subscript(cursor : Clang::Cursor)
    children = collect_children(cursor)

    visit(children[1])
    visit(children[0])
    emit("BINARY :add")
    emit("DEREF")
  end

  def visit_init_list_expr(cursor : Clang::Cursor)
    children = collect_children(cursor)
    children.reverse.each { |child| visit(child) }
  end

  def get_type(type : Clang::Type) : String
    canonical = type.canonical_type

    case canonical.kind
    when .void? then "void"
    when .bool? then "bool"
    when .char_u?, .u_char?, .char_s?, .s_char?, .w_char?
      "u8"
    when .short?, .u_short?, .int?, .u_int?
      "i32"
    when .long?, .u_long?, .long_long?, .u_long_long?
      "i64"
    when .float?  then "f32"
    when .double? then "f64"
    when .pointer?
      "ptr<#{get_type(canonical.pointee_type)}>"
    when .record?, .enum?
      canonical.spelling
    when .constant_array?
      element = get_type(canonical.array_element_type)
      size = canonical.array_size
      "array<#{element}, #{size}>"
    when .incomplete_array?
      "ptr<#{get_type(canonical.array_element_type)}>"
    when .function_proto?, .function_no_proto?
      "ptr<void>"
    when .elaborated?
      get_type(canonical.named_type)
    when .typedef?
      get_type(canonical.canonical_type)
    else
      Myc.debug(:myc) { puts "  UNKNOWN TYPE: #{canonical.kind} #{canonical.spelling}" }
      canonical.spelling
    end
  end

  private def extract_struct_name(var_type : String) : String
    var_type.sub("ptr<", "").sub(">", "")
  end

  private def default_zero(var_type : String) : String
    case var_type
    when .starts_with?("array<") then "0 :#{var_type}"
    when .starts_with?("ptr")    then "0 :ptr<void>"
    when "u8"                    then "0 :u8"
    when "i64"                   then "0 :i64"
    when "f32"                   then "0.0 :f32"
    when "f64"                   then "0.0 :f64"
    else                              "0 :i32"
    end
  end

  private def emit_unary_update(cursor, op)
    children = collect_children(cursor)
    if child = children[0]?
      name = child.spelling
      emit("PUSH 1 :i32")
      emit("LOCAL :#{name}")
      emit("BINARY :#{op}")
      emit("LOCAL :#{name}")
      emit("STORE")
    end
  end

  private def emit(line : String)
    @io << "  " * @indent << line << '\n'
  end

  private def skip_system?(cursor : Clang::Cursor) : Bool
    if location = cursor.location
      if loc_file = location.file_name
        return true unless loc_file.includes?(source.filename)
      end
    end

    return true if cursor.kind.macro_definition? && cursor.type.kind.invalid?

    false
  end

  private def clear
    @params.clear
    @vars.clear
    @stack.clear
  end

  def save(dest_io : IO)
    io.rewind
    IO.copy(io, dest_io)
  end
end
