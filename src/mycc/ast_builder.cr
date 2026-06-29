class Myc::Mycc::ASTBuilder
  getter source : Source
  getter tu : Clang::TranslationUnit
  getter mod : Mod

  def initialize(@source, @tu)
    @mod = Myc::Mod.new("main", source.filename)
    @structs = Hash(String, Array({String, Type})).new
    @current_function_name = ""
    @globals = [] of TypedAST::VarDecl
  end

  def build : TypedAST::Program
    functions = [] of TypedAST::Function

    tu.cursor.visit_children do |cursor|
      if cursor.kind.function_decl?
        functions << build_function(cursor)
      elsif cursor.kind.var_decl?
        @globals << build_var_decl(cursor)
      elsif cursor.kind.struct_decl?
        build_struct_decl(cursor)
      end
      Clang::ChildVisitResult::Continue
    end

    TypedAST::Program.new(functions, @structs.dup, @globals)
  end

  private def build_function(cursor : Clang::Cursor) : TypedAST::Function
    name = cursor.spelling
    @current_function_name = name
    params = [] of {String, Type}
    body = nil

    children(cursor).each do |child|
      case child.kind
      when .parm_decl?
        param_name = child.spelling
        param_type = get_type(child, child.type)
        params << {param_name, param_type}
      when .compound_stmt?
        body = build_stmts(child)
      end
    end

    return_type = get_type(cursor, cursor.result_type)
    TypedAST::Function.new(name, params, return_type, body, location(cursor))
  end

  private def build_struct_decl(cursor : Clang::Cursor)
    name = cursor.spelling
    return if name.empty?

    fields = [] of {String, Type}
    children(cursor).each do |child|
      if child.kind.field_decl?
        field_name = child.spelling
        field_type = get_type(child, child.type)
        fields << {field_name, field_type}
      end
    end
    @structs[name] = fields

    struct_type = Type::StructType.new(name)
    field_types = fields.map { |_, t| t }
    struct_type.data = field_types

    node = cursor_to_node(cursor)
    raise error("type #{name} already defined", cursor) if mod.type_defs[name]?
    mod.type_defs[name] = Mod::TypeDef.new(node, struct_type)
  end

  private def build_node(cursor : Clang::Cursor) : TypedAST::Node?
    case cursor.kind
    when .integer_literal?      then build_int_literal(cursor)
    when .floating_literal?     then build_float_literal(cursor)
    when .character_literal?    then build_char_literal(cursor)
    when .string_literal?       then build_string_literal(cursor)
    when .decl_ref_expr?        then build_var_ref(cursor)
    when .call_expr?            then build_call(cursor)
    when .binary_operator?      then build_binary(cursor)
    when .unary_operator?       then build_unary(cursor)
    when .c_style_cast_expr?    then build_cast(cursor)
    when .array_subscript_expr? then build_subscript(cursor)
    when .unary_expr?           then build_sizeof(cursor)
    when .init_list_expr?       then build_init_list(cursor)
    when .member_ref_expr?      then build_field(cursor)
    when .conditional_operator? then build_conditional(cursor)
    when .paren_expr?, .first_expr?
      children = children(cursor)
      children.size == 1 ? build_node(children[0]) : nil
    else
      nil
    end
  end

  private def build_stmts(cursor : Clang::Cursor) : Array(TypedAST::Stmt)
    stmts = [] of TypedAST::Stmt
    children(cursor).each do |child|
      next if child.spelling == "{" || child.spelling == "}"

      case child.kind
      when .decl_stmt?
        children(child).each do |decl_child|
          if decl_child.kind.var_decl?
            stmts << build_var_decl(decl_child)
          end
        end
      else
        if stmt = build_stmt(child)
          stmts << stmt
        else
          case child.kind
          when .return_stmt?
            stmts << build_return(child)
          when .if_stmt?
            stmts << build_if(child)
          when .while_stmt?
            stmts << build_while(child)
          when .for_stmt?
            stmts << build_for(child)
          when .call_expr?
            expr = build_call(child)
            stmts << TypedAST::ExprStmt.new(expr, location(child))
          when .binary_operator?
            if stmt = build_stmt(child)
              stmts << stmt
            end
          when .unary_operator?
            if stmt = build_stmt(child)
              stmts << stmt
            end
          when .label_stmt?
            stmts << TypedAST::Label.new(child.spelling, location(child))

            children(child).each do |label_child|
              if s = build_stmt(label_child)
                stmts << s
              end
            end
          end
        end
      end
    end
    stmts
  end

  private def build_stmt(cursor : Clang::Cursor) : TypedAST::Stmt?
    case cursor.kind
    when .call_expr?
      expr = build_call(cursor)
      TypedAST::ExprStmt.new(expr, location(cursor))
    when .return_stmt?
      build_return(cursor)
    when .if_stmt?
      build_if(cursor)
    when .while_stmt?
      build_while(cursor)
    when .do_stmt?
      build_do_while(cursor)
    when .for_stmt?
      build_for(cursor)
    when .binary_operator?
      op = cursor.spelling
      if op == "="
        children_list = children(cursor)
        left = build_node(children_list[0]).not_nil!
        right = build_node(children_list[1]).not_nil!

        if !left.type.eq?(right.type)
          right = TypedAST::Cast.new(right, left.type, location(cursor))
        end

        TypedAST::Assign.new(left, right, location(cursor))
      else
        expr = build_binary(cursor)
        TypedAST::ExprStmt.new(expr, location(cursor))
      end
    when .unary_operator?
      op = cursor.spelling
      if op.empty?
        @tu.tokenize(cursor.extent) do |token|
          if token.kind.punctuation? && {"++", "--"}.includes?(token.spelling)
            op = token.spelling
            break
          end
        end
      end

      if op == "++" || op == "--"
        expr = build_unary(cursor, is_statement: true)
        TypedAST::ExprStmt.new(expr, location(cursor))
      else
        expr = build_unary(cursor)
        TypedAST::ExprStmt.new(expr, location(cursor))
      end
    when .break_stmt?
      TypedAST::Break.new(location(cursor))
    when .continue_stmt?
      TypedAST::Continue.new(location(cursor))
    when .goto_stmt?
      label_name = ""
      children(cursor).each do |child|
        if child.kind.label_ref?
          label_name = child.spelling
        end
      end
      TypedAST::Goto.new(label_name, location(cursor))
    when .compound_stmt?
      nil
    when .compound_assign_operator?
      op = cursor.spelling
      children_list = children(cursor)
      left = build_node(children_list[0]).not_nil!
      right = build_node(children_list[1]).not_nil!

      bin_op = BINARY_MAP[op[0].to_s]? || :add

      value = TypedAST::BinaryOp.new(bin_op, left.dup, right, left.type, location(cursor))
      TypedAST::Assign.new(left, value, location(cursor))
    else
      nil
    end
  end

  private def build_return(cursor : Clang::Cursor) : TypedAST::Return
    value = nil
    children(cursor).each do |child|
      if node = build_node(child)
        value = node
      end
    end
    TypedAST::Return.new(value, location(cursor))
  end

  private def build_decl_stmt(cursor : Clang::Cursor) : Array(TypedAST::Stmt)
    stmts = [] of TypedAST::Stmt
    children(cursor).each do |child|
      if child.kind.var_decl?
        stmts << build_var_decl(child)
      end
    end
    stmts
  end

  private def build_var_decl(cursor : Clang::Cursor) : TypedAST::VarDecl
    name = cursor.spelling
    var_type = get_type(cursor, cursor.type)
    is_static = cursor.storage_class.static?

    init = nil
    children(cursor).each do |child|
      if node = build_node(child)
        init = node
      end
    end

    if init.is_a?(TypedAST::InitList)
      init = resolve_init_list_types(init, var_type)
    end

    if init && init.type != var_type
      if init.type.is_a?(Type::FlatType) && var_type.is_a?(Type::PtrType)
        init = TypedAST::AddrOf.new(init, var_type, init.location)
        init = TypedAST::Cast.new(init, var_type, init.location)
      else
        init = TypedAST::Cast.new(init, var_type, init.location)
      end
    end

    if is_static
      func_name = @current_function_name || "global"
      unique_name = "#{func_name}_#{name}"
      var = TypedAST::VarDecl.new(unique_name, var_type, init, location(cursor), is_static: true, original_name: name)
      @globals << var
      var
    else
      TypedAST::VarDecl.new(name, var_type, init, location(cursor))
    end
  end

  private def resolve_init_list_types(init_list : TypedAST::InitList, target_type : Type) : TypedAST::InitList
    elements = [] of TypedAST::Node
    field_types = target_type.is_a?(Type::StructType) ? target_type.data : [] of Type

    init_list.elements.each_with_index do |elem, idx|
      if elem.is_a?(TypedAST::InitList) && elem.type.id_name == "void"
        nested_type = field_types[idx]? || target_type
        elements << resolve_init_list_types(elem, nested_type)
      else
        elements << elem
      end
    end

    TypedAST::InitList.new(elements, target_type, init_list.location)
  end

  private def build_if(cursor : Clang::Cursor) : TypedAST::If
    children_list = children(cursor)
    condition = ensure_bool(build_node(children_list[0]).not_nil!)

    then_body = if children_list.size > 1
                  build_stmt_or_stmts(children_list[1])
                else
                  [] of TypedAST::Stmt
                end

    else_body = if children_list.size > 2
                  build_stmt_or_stmts(children_list[2])
                else
                  [] of TypedAST::Stmt
                end

    TypedAST::If.new(condition, then_body, else_body, location(cursor))
  end

  private def ensure_bool(node : TypedAST::Node) : TypedAST::Node
    return node if node.type.is_a?(Type::BoolType)

    if node.type.is_a?(Type::PtrType)
      zero = TypedAST::Cast.new(
        TypedAST::IntLiteral.new(0_i64, mod.typer.voidp, node.location),
        node.type,
        node.location
      )
      TypedAST::BinaryOp.new(:not_eq, node, zero, mod.typer.bool, node.location)
    elsif node.type.is_a?(Type::FloatType)
      zero = TypedAST::FloatLiteral.new(0.0, node.type, node.location)
      TypedAST::BinaryOp.new(:not_eq, node, zero, mod.typer.bool, node.location)
    else
      zero = TypedAST::IntLiteral.new(0_i64, node.type, node.location)
      TypedAST::BinaryOp.new(:not_eq, node, zero, mod.typer.bool, node.location)
    end
  end

  private def build_stmt_or_stmts(cursor : Clang::Cursor) : Array(TypedAST::Stmt)
    case cursor.kind
    when .compound_stmt?
      build_stmts(cursor)
    else
      if stmt = build_stmt(cursor)
        [stmt]
      else
        [] of TypedAST::Stmt
      end
    end
  end

  private def build_while(cursor : Clang::Cursor) : TypedAST::While
    children_list = children(cursor)
    condition = ensure_bool(build_node(children_list[0]).not_nil!)
    body = build_stmts(children_list[1])

    TypedAST::While.new(condition, body, location(cursor))
  end

  private def build_do_while(cursor : Clang::Cursor) : TypedAST::DoWhile
    children_list = children(cursor)

    body = if children_list.size > 0
             build_stmt_or_stmts(children_list[0])
           else
             [] of TypedAST::Stmt
           end

    condition = if children_list.size > 1
                  ensure_bool(build_node(children_list[1]).not_nil!)
                else
                  TypedAST::IntLiteral.new(1_i64, mod.typer.i32, location(cursor))
                end

    TypedAST::DoWhile.new(condition, body, location(cursor))
  end

  private def build_for(cursor : Clang::Cursor) : TypedAST::For
    children_list = children(cursor)

    init = nil
    if children_list.size > 0
      init_cursor = children_list[0]
      if init_cursor.kind.decl_stmt?
        children(init_cursor).each do |decl_child|
          if decl_child.kind.var_decl?
            init = build_var_decl(decl_child)
          end
        end
      else
        init = build_stmt(init_cursor)
      end
    end

    condition = children_list.size > 1 ? ensure_bool(build_node(children_list[1]).not_nil!) : nil
    update = children_list.size > 2 ? build_stmt(children_list[2]) : nil
    body = children_list.size > 3 ? build_stmts(children_list[3]) : [] of TypedAST::Stmt

    TypedAST::For.new(init, condition, update, body, location(cursor))
  end

  private def build_int_literal(cursor : Clang::Cursor) : TypedAST::IntLiteral
    value = extract_literal_value(cursor)
    clean = value.gsub(/[LlUu]+$/, "")
    type = get_type(cursor, cursor.type)
    TypedAST::IntLiteral.new(parse_c_int_literal(clean), type, location(cursor))
  end

  private def build_float_literal(cursor : Clang::Cursor) : TypedAST::FloatLiteral
    value = extract_literal_value(cursor)
    clean = value.gsub(/[fFlL]$/, "").to_f64
    type = get_type(cursor, cursor.type)
    TypedAST::FloatLiteral.new(clean, type, location(cursor))
  end

  private def build_char_literal(cursor : Clang::Cursor) : TypedAST::CharLiteral
    value = extract_literal_value(cursor)
    ch = if value && value.size >= 3 && value[0] == '\''
           value[1].ord
         else
           value.to_i
         end
    type = get_type(cursor, cursor.type)
    TypedAST::CharLiteral.new(ch, type, location(cursor))
  end

  private def build_string_literal(cursor : Clang::Cursor) : TypedAST::StringLiteral
    raw = cursor.spelling
    unquoted = raw[1..-2]
    value = unquoted
      .gsub("\\n", "\n")
      .gsub("\\t", "\t")
      .gsub("\\r", "\r")
      .gsub("\\\"", "\"")
      .gsub("\\\\", "\\")
    TypedAST::StringLiteral.new(value, mod.typer.u8p, location(cursor))
  end

  private def build_conditional(cursor : Clang::Cursor) : TypedAST::Node
    children_list = children(cursor)

    condition = ensure_bool(build_node(children_list[0]).not_nil!)
    then_expr = build_node(children_list[1]).not_nil!
    else_expr = build_node(children_list[2]).not_nil!

    type = then_expr.type
    TypedAST::Conditional.new(condition, then_expr, else_expr, type, location(cursor))
  end

  private def build_var_ref(cursor : Clang::Cursor) : TypedAST::VarRef
    name = cursor.spelling
    type = get_type(cursor, cursor.type)
    TypedAST::VarRef.new(name, type, location(cursor))
  end

  private def build_call(cursor : Clang::Cursor) : TypedAST::Call
    func_name = cursor.spelling
    children_list = children(cursor)

    callee = children_list.find do |c|
      if c.kind.decl_ref_expr?
        c.spelling == func_name
      elsif c.kind.member_ref_expr?
        c.spelling == func_name
      elsif c.kind.first_expr?
        children(c).any? { |inner|
          (inner.kind.decl_ref_expr? || inner.kind.member_ref_expr?) && inner.spelling == func_name
        }
      else
        false
      end
    end
    is_invoke = func_name.empty? || (callee && is_variable_callee?(callee, func_name))

    if is_invoke
      args = [] of TypedAST::Node
      if func_name.empty?
        callee_node = build_node(children_list[0]).not_nil!
        args = children_list[1..].map { |c| build_node(c).not_nil! }
      elsif callee
        callee_node = build_node(callee).not_nil!
        args = children_list.reject { |c| c == callee }
          .map { |c| build_node(c).not_nil! }
      end
      ret_type = get_type(cursor, cursor.type)
      TypedAST::Call.new("", [callee_node.not_nil!] + args, ret_type, location(cursor), is_invoke: true)
    else
      args = [] of TypedAST::Node

      children(cursor).each do |child|
        next if child.kind.decl_ref_expr? && child.spelling == func_name

        if node = build_node(child)
          next if node.is_a?(TypedAST::VarRef) && node.name == func_name
          args << node
        end
      end

      ret_type = get_type(cursor, cursor.type)
      TypedAST::Call.new(func_name, args, ret_type, location(cursor))
    end
  end

  private def build_binary(cursor : Clang::Cursor) : TypedAST::Node
    op = cursor.spelling
    if op.empty?
      @tu.tokenize(cursor.extent) do |token|
        if !token.spelling.empty? && BINARY_MAP.has_key?(token.spelling)
          op = token.spelling
          break
        end
      end
    end

    children_list = children(cursor)
    left = build_node(children_list[0]).not_nil!
    right = build_node(children_list[1]).not_nil!

    op_name = BINARY_MAP[op]? || :add

    if op == "&&" || op == "||"
      left = ensure_bool(left)
      right = ensure_bool(right)
      op_name = BINARY_MAP[op]? || :and
      result = TypedAST::BinaryOp.new(op_name, left, right, mod.typer.bool, location(cursor))

      TypedAST::Cast.new(result, mod.typer.i32, location(cursor))
    elsif op == "<" || op == ">" || op == "<=" || op == ">=" || op == "==" || op == "!="
      common = common_type(left.type, right.type)
      left = insert_cast(left, common) if left.type != common
      right = insert_cast(right, common) if right.type != common
      TypedAST::BinaryOp.new(op_name, left, right, mod.typer.bool, location(cursor))
    elsif left.type.is_a?(Type::PtrType) && right.type.is_a?(Type::IntType)
      right = insert_cast(right, mod.typer.i64) if right.type.as(Type::IntType).bytes_count < 8
      TypedAST::BinaryOp.new(op_name, left, right, left.type, location(cursor))
    elsif right.type.is_a?(Type::PtrType) && left.type.is_a?(Type::IntType)
      left = insert_cast(left, mod.typer.i64) if left.type.as(Type::IntType).bytes_count < 8
      TypedAST::BinaryOp.new(op_name, left, right, right.type, location(cursor))
    elsif left.type.is_a?(Type::FlatType) && right.type.is_a?(Type::IntType)
      elem_type = left.type.as(Type::FlatType).target_type
      ptr_type = mod.typer.to_ptr(elem_type, location(cursor).offset)
      left = TypedAST::AddrOf.new(left, ptr_type, location(cursor))
      left = TypedAST::Cast.new(left, ptr_type, location(cursor))
      right = insert_cast(right, mod.typer.i64) if right.type.as(Type::IntType).bytes_count < 8
      TypedAST::BinaryOp.new(op_name, left, right, ptr_type, location(cursor))
    else
      common = common_type(left.type, right.type)
      left = insert_cast(left, common) if left.type != common
      right = insert_cast(right, common) if right.type != common
      TypedAST::BinaryOp.new(op_name, left, right, common, location(cursor))
    end
  end

  private def build_unary(cursor : Clang::Cursor, is_statement : Bool = false) : TypedAST::Node
    op = cursor.spelling
    if op.empty?
      @tu.tokenize(cursor.extent) do |token|
        if token.kind.punctuation? && {"++", "--", "-", "!", "~", "*", "&"}.includes?(token.spelling)
          op = token.spelling
          break
        end
      end
    end

    children_list = children(cursor)
    operand = children_list.size > 0 ? build_node(children_list[0]) : nil

    case op
    when "-"
      TypedAST::UnaryOp.new(:neg, operand.not_nil!, operand.not_nil!.type, location(cursor))
    when "!"
      if operand && operand.type.is_a?(Type::PtrType)
        zero = TypedAST::Cast.new(
          TypedAST::IntLiteral.new(0_i64, mod.typer.voidp, location(cursor)),
          operand.type,
          location(cursor)
        )
        TypedAST::BinaryOp.new(:eq, operand, zero, mod.typer.bool, location(cursor))
      elsif operand && operand.type.is_a?(Type::BoolType)
        TypedAST::UnaryOp.new(:lnot, operand.not_nil!, mod.typer.bool, location(cursor))
      else
        zero = TypedAST::IntLiteral.new(0_i64, operand.not_nil!.type, location(cursor))
        TypedAST::BinaryOp.new(:eq, operand.not_nil!, zero, mod.typer.bool, location(cursor))
      end
    when "~"
      TypedAST::UnaryOp.new(:bnot, operand.not_nil!, operand.not_nil!.type, location(cursor))
    when "*"
      type = operand.not_nil!.type
      if type.is_a?(Type::PtrType)
        TypedAST::Deref.new(operand.not_nil!, type.target_type, location(cursor))
      else
        raise error("Cannot dereference non-pointer type #{type}", cursor)
      end
    when "&"
      if operand && operand.type.is_a?(Type::Fn)
        operand
      else
        ptr_type = mod.typer.to_ptr(operand.not_nil!.type, location(cursor).offset)
        TypedAST::AddrOf.new(operand.not_nil!, ptr_type, location(cursor))
      end
    when "++", "--"
      is_inc = op == "++"
      is_prefix = is_prefix_unary?(cursor)

      op_sym = case {is_inc, is_prefix}
               when {true, true}   then :prefix_inc
               when {true, false}  then :postfix_inc
               when {false, true}  then :prefix_dec
               when {false, false} then :postfix_dec
               else
                 raise "unreachable"
               end

      TypedAST::UnaryOp.new(op_sym, operand.not_nil!, operand.not_nil!.type, location(cursor), is_statement)
    else
      operand || raise error("Unknown unary operator: #{op}", cursor)
    end
  end

  private def is_prefix_unary?(cursor : Clang::Cursor) : Bool
    tokens = [] of String
    @tu.tokenize(cursor.extent) do |token|
      tokens << token.spelling
    end
    tokens.first? == "++" || tokens.first? == "--"
  end

  private def build_cast(cursor : Clang::Cursor) : TypedAST::Cast
    target_type = get_type(cursor, cursor.type)
    children_list = children(cursor)
    operand = children_list.size > 0 ? build_node(children_list.last) : nil
    TypedAST::Cast.new(operand.not_nil!, target_type, location(cursor))
  end

  private def build_subscript(cursor : Clang::Cursor) : TypedAST::Subscript
    children_list = children(cursor)
    array = build_node(children_list[0]).not_nil!
    index = build_node(children_list[1]).not_nil!

    elem_type = case type = array.type
                when Type::PtrType
                  type.target_type
                when Type::FlatType
                  type.target_type
                else
                  array.type
                end

    TypedAST::Subscript.new(array, index, elem_type, location(cursor))
  end

  private def build_sizeof(cursor : Clang::Cursor) : TypedAST::SizeOf
    children_list = children(cursor)
    if children_list.size > 0
      target_type = get_type(children_list[0], children_list[0].type)
    else
      target_type = get_type(cursor, cursor.type)
    end
    TypedAST::SizeOf.new(target_type, mod.typer.i64, location(cursor))
  end

  private def build_init_list(cursor : Clang::Cursor, target_type : Type? = nil) : TypedAST::InitList
    elements = [] of TypedAST::Node
    field_types = get_field_types(target_type)
    field_idx = 0

    children(cursor).each do |child|
      if child.kind.init_list_expr?
        nested_type = field_types[field_idx]? || mod.typer.void
        elements << build_init_list(child, nested_type)
        field_idx += 1
      else
        if node = build_node(child)
          elements << node
          field_idx += 1
        end
      end
    end

    type = target_type || mod.typer.void
    TypedAST::InitList.new(elements, type, location(cursor))
  end

  private def get_field_types(type : Type?) : Array(Type)
    if type.is_a?(Type::StructType)
      type.data
    else
      [] of Type
    end
  end

  private def build_field(cursor : Clang::Cursor) : TypedAST::FieldAccess
    field_name = cursor.spelling
    children_list = children(cursor)
    obj = build_node(children_list[0]).not_nil!

    obj_type = obj.type
    is_arrow = obj_type.is_a?(Type::PtrType)
    struct_type = is_arrow ? obj_type.as(Type::PtrType).target_type : obj_type

    field_index = 0
    field_type = struct_type

    if struct_type.is_a?(Type::StructType)
      struct_name = struct_type.id_name
      if fields = @structs[struct_name]?
        if idx = fields.index { |name, _| name == field_name }
          field_index = idx
          field_type = struct_type.data[idx]
        end
      end
    end

    TypedAST::FieldAccess.new(obj, field_name, field_index, field_type, location(cursor))
  end

  private def common_type(t1 : Type, t2 : Type) : Type
    return t1 if t1 == t2
    return t1 if t1.is_a?(Type::PtrType) && t2.is_a?(Type::IntType)
    return t2 if t2.is_a?(Type::PtrType) && t1.is_a?(Type::IntType)
    return t1 if t1.is_a?(Type::FloatType)
    return t2 if t2.is_a?(Type::FloatType)
    if t1.is_a?(Type::IntType) && t2.is_a?(Type::IntType)
      return t1.bytes_count >= t2.bytes_count ? t1 : t2
    end
    t1
  end

  private def insert_cast(node : TypedAST::Node, target_type : Type) : TypedAST::Cast
    TypedAST::Cast.new(node, target_type, node.location)
  end

  BINARY_MAP = {
    "+" => :add, "-" => :sub, "*" => :mul, "/" => :div,
    "<" => :less, ">" => :more, "<=" => :less_eq, ">=" => :more_eq,
    "==" => :eq, "!=" => :not_eq, "%" => :rem,
    "&&" => :and, "||" => :or,
    "&" => :and, "|" => :or, "^" => :xor, "<<" => :shl, ">>" => :shr,
  }

  private def location(cursor : Clang::Cursor) : Location
    offset = if loc = cursor.location
               _, _, _, o = loc.file_location
               o
             else
               0
             end
    Location.new(source.filename, offset.to_u32)
  end

  private def cursor_to_node(cursor : Clang::Cursor) : Myc::Source::Node
    node = Myc::Source::Node.new(Opcode::Code::UNDEF)
    if loc = cursor.location
      _, _, _, offset = loc.file_location
      node.offset = offset
    else
      node.offset = 0
    end
    node
  end

  private def children(cursor : Clang::Cursor) : Array(Clang::Cursor)
    res = [] of Clang::Cursor
    cursor.visit_children do |child|
      res << child
      Clang::ChildVisitResult::Continue
    end
    res
  end

  private def get_type(cursor : Clang::Cursor, type : Clang::Type, count = 0) : Type
    count += 1
    canonical = type.canonical_type

    if count >= 50
      raise error("Recursion on get_type: #{canonical.kind} #{canonical.spelling}", cursor)
    end

    case canonical.kind
    when .void?                  then mod.typer.void
    when .bool?                  then mod.typer.bool
    when .char_s?, .s_char?      then mod.typer.i8
    when .w_char?                then mod.typer.u32
    when .char_u?, .u_char?      then mod.typer.u8
    when .short?, .int?          then mod.typer.i32
    when .u_short?, .u_int?      then mod.typer.u32
    when .long?, .long_long?     then mod.typer.i64
    when .u_long?, .u_long_long? then mod.typer.u64
    when .float?                 then mod.typer.f32
    when .double?                then mod.typer.f64
    when .pointer?
      pointee = get_type(cursor, canonical.pointee_type, count)
      if pointee.is_a?(Type::Fn)
        pointee
      else
        mod.typer.to_ptr(get_type(cursor, canonical.pointee_type, count), location(cursor).offset)
      end
    when .record?
      mod.typer.find(canonical.spelling.sub("struct ", ""), location(cursor))
    when .constant_array?
      mod.typer.find("flat<#{get_type(cursor, canonical.array_element_type, count)}, #{canonical.array_size}>", location(cursor))
    when .incomplete_array?
      mod.typer.to_ptr(get_type(cursor, canonical.array_element_type, count), location(cursor).offset)
    when .elaborated?
      get_type(cursor, canonical.named_type, count)
    when .function_proto?
      ret = get_type(cursor, canonical.result_type, count)
      arg_types = canonical.arguments.map { |t| get_type(cursor, t, count) }

      id_name = String.build do |io|
        io << "fn<"
        arg_types.each_with_index do |t, i|
          io << ", " if i > 0
          io << t.id_name
        end
        io << ", "
        io << ret.id_name
        io << '>'
      end

      mod.typer.find(id_name, location(cursor))
    when .function_no_proto?
      ret = get_type(cursor, canonical.result_type, count)
      id_name = "fn<#{ret.id_name}>"
      mod.typer.find(id_name, location(cursor))
    when .typedef?
      get_type(cursor, canonical.canonical_type, count)
    else
      raise error("UNKNOWN TYPE: #{canonical.kind} #{canonical.spelling}", cursor)
    end
  end

  private def error(msg, cursor) : Myc::Error::ErrorLoc
    Myc::Error::ErrorLoc.new(msg, location(cursor))
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

  private def parse_c_int_literal(value : String) : Int64
    if value.starts_with?("0b") || value.starts_with?("0B")
      value[2..].to_i64(base: 2)
    elsif value.starts_with?("0x") || value.starts_with?("0X")
      value[2..].to_i64(base: 16)
    elsif value.starts_with?('0') && value.size > 1 && !value.includes?('.')
      value[1..].to_i64(base: 8)
    else
      value.to_i64
    end
  end

  private def is_function_pointer?(cursor : Clang::Cursor) : Bool
    type = get_type(cursor, cursor.type)
    _is_fn_type?(type)
  end

  private def _is_fn_type?(type : Type) : Bool
    if type.is_a?(Type::Fn)
      true
    elsif type.is_a?(Type::PtrType)
      _is_fn_type?(type.target_type)
    else
      false
    end
  end

  private def is_variable_callee?(cursor : Clang::Cursor, func_name : String) : Bool
    if cursor.kind.decl_ref_expr? && cursor.spelling == func_name
      return !cursor.referenced.kind.function_decl?
    elsif cursor.kind.member_ref_expr? && cursor.spelling == func_name
      return true
    elsif cursor.kind.first_expr?
      children(cursor).each do |inner|
        if inner.kind.decl_ref_expr? && inner.spelling == func_name
          return !inner.referenced.kind.function_decl?
        elsif inner.kind.member_ref_expr? && inner.spelling == func_name
          return true
        end
      end
    end
    false
  end
end
