class Myc::Mycc::CodeGenerator
  getter io : IO
  getter typer : Mod::Typer

  class VarInfo
    getter type : Type
    getter is_static : Bool
    getter unique_name : String?

    def initialize(@type, @is_static = false, @unique_name = nil)
    end
  end

  def initialize(@typer)
    @indent = 0
    @io = IO::Memory.new
    @vars = Hash(String, VarInfo).new
    @params = Hash(String, Int32).new
    @globals = Hash(String, TypedAST::VarDecl).new
  end

  def generate(program : TypedAST::Program) : IO
    program.structs.each do |name, fields|
      emit("STRUCT :#{name}")
      @indent += 1
      fields.each do |_, field_type|
        emit("TYPE #{type_s(field_type)}")
      end
      @indent -= 1
      emit("ENDSTRUCT")
    end

    program.globals.each do |var|
      emit("GLOBAL :#{var.name}")
      @indent += 1
      emit("TYPE #{type_s(var.var_type)}")
      if var.init
      end
      @indent -= 1

      if init = var.init
        case init
        when TypedAST::IntLiteral
          emit("INITIAL #{init.value}")
        when TypedAST::FloatLiteral
          emit("INITIAL #{init.value}")
        when TypedAST::StringLiteral
          emit("INITIAL #{init.value}")
        end
      end
      emit("ENDGLOBAL")

      @globals[var.original_name] = var
    end

    program.functions.each { |f| generate_function(f) }
    io.rewind
    io
  end

  private def emit(str : String)
    @io << "  " * @indent << str << '\n'
  end

  def generate_function(func : TypedAST::Function)
    @vars.clear
    @params.clear
    func.params.each_with_index { |(name, type), idx| @params[name] = idx }

    emit("FUNC :#{func.name}")
    @indent += 1

    unless func.params.empty?
      emit("ARGS")
      @indent += 1
      func.params.each { |_, type| emit("  TYPE #{type_s(type)}") }
      @indent -= 1
    end

    if func.return_type.id_name != "void"
      emit("RETURN")
      @indent += 1
      emit("  TYPE #{type_s(func.return_type)}")
      @indent -= 1
    end

    if body = func.body
      emit("BODY")
      @indent += 1
      body.each { |stmt| generate_stmt(stmt) }
      @indent -= 1
    end

    emit("ENDFUNC")
    @indent -= 1
  end

  def generate_stmt(stmt : TypedAST::ExprStmt)
    generate_expr(stmt.expr)

    case expr = stmt.expr
    when TypedAST::Call
      if !returns_void?(expr) && expr.func_name != "printf"
        emit("STACK :drop")
      end
    end
  end

  def generate_stmt(stmt : TypedAST::Return)
    if v = stmt.value
      generate_expr(v)
    end
    emit("RET")
  end

  def generate_stmt(stmt : TypedAST::VarDecl)
    if stmt.is_static
    else
      @vars[stmt.name] = VarInfo.new(stmt.var_type)
      if init = stmt.init
        generate_expr(init)
        emit("LOCAL :#{stmt.name} #{type_s(stmt.var_type)}")
        emit("STORE")
      end
    end
  end

  def generate_stmt(stmt : TypedAST::If)
    generate_expr(stmt.condition)
    emit("IF")
    @indent += 1

    emit("THEN")
    @indent += 1
    stmt.then_body.each { |s| generate_stmt(s) }
    @indent -= 1

    unless stmt.else_body.empty?
      emit("ELSE")
      @indent += 1
      stmt.else_body.each { |s| generate_stmt(s) }
      @indent -= 1
    end

    @indent -= 1
    emit("ENDIF")
  end

  def generate_stmt(stmt : TypedAST::While)
    emit("LOOP")
    @indent += 1

    emit("COND")
    @indent += 1
    generate_expr(stmt.condition)
    @indent -= 1

    emit("BODY")
    @indent += 1
    stmt.body.each { |s| generate_stmt(s) }
    @indent -= 1

    emit("STEP")
    @indent -= 1
    emit("ENDLOOP")
  end

  def generate_stmt(stmt : TypedAST::For)
    if init = stmt.init
      generate_stmt(init)
    end

    emit("LOOP")
    @indent += 1

    if cond = stmt.condition
      emit("COND")
      @indent += 1
      generate_expr(cond)
      @indent -= 1
    end

    emit("BODY")
    @indent += 1
    stmt.body.each { |s| generate_stmt(s) }
    @indent -= 1

    emit("STEP")
    if update = stmt.update
      generate_stmt(update)
    end

    @indent -= 1
    emit("ENDLOOP")
  end

  def generate_stmt(stmt : TypedAST::Break)
    emit("BREAK")
  end

  def generate_stmt(stmt : TypedAST::Continue)
    emit("NEXT")
  end

  def generate_stmt(stmt : TypedAST::Assign)
    generate_expr(stmt.right)
    generate_expr(stmt.left)
    emit("STORE")
  end

  def generate_expr(expr : TypedAST::IntLiteral)
    if expr.type.eq?(typer.i32)
      emit("PUSH #{expr.value}")
    else
      emit("PUSH #{expr.value} #{type_s(expr.type)}")
    end
  end

  def generate_expr(expr : TypedAST::FloatLiteral)
    emit("PUSH #{expr.value} #{type_s(expr.type)}")
  end

  def generate_expr(expr : TypedAST::CharLiteral)
    emit("PUSH #{expr.value} :u8")
  end

  def generate_expr(expr : TypedAST::StringLiteral)
    emit("PUSH #{expr.value.inspect}")
  end

  def generate_expr(expr : TypedAST::VarRef)
    name = expr.name
    if @vars.has_key?(name)
      emit("LOCAL :#{name} #{type_s(expr.type)}")
    elsif param = @params[name]?
      emit("PARAM #{param}")
    elsif g = @globals[name]?
      emit("GLOBAL :#{g.name}")
    end
  end

  def generate_expr(expr : TypedAST::BinaryOp)
    case expr.op
    when :store
    else
      generate_expr(expr.right)
      generate_expr(expr.left)
      emit("BINARY :#{expr.op}")
    end
  end

  def generate_expr(expr : TypedAST::UnaryOp)
    case expr.op
    when :neg
      generate_expr(expr.operand)
      emit("UNARY :neg")
    when :lnot
      generate_expr(expr.operand)
      emit("UNARY :lnot")
    when :bnot
      generate_expr(expr.operand)
      emit("UNARY :bnot")
    when :postfix_inc, :postfix_dec
      if expr.is_statement
        emit("PUSH 1 :i32")
        generate_expr(expr.operand)
        bin_op = expr.op == :postfix_inc ? "add" : "sub"
        emit("BINARY :#{bin_op}")
        generate_expr(expr.operand)
        emit("STORE")
      else
        tmp_name = "__tmp_#{@vars.size}"
        @vars[tmp_name] = VarInfo.new(expr.type)
        generate_expr(expr.operand)
        emit("LOCAL :#{tmp_name} #{type_s(expr.type)}")
        emit("STORE")

        emit("PUSH 1 :i32")
        generate_expr(expr.operand)
        bin_op = expr.op == :postfix_inc ? "add" : "sub"
        emit("BINARY :#{bin_op}")
        generate_expr(expr.operand)
        emit("STORE")

        emit("LOCAL :#{tmp_name} #{type_s(expr.type)}")
        @vars.delete(tmp_name)
      end
    when :prefix_inc, :prefix_dec
      emit("PUSH 1 :i32")
      generate_expr(expr.operand)
      bin_op = expr.op == :prefix_inc ? "add" : "sub"
      emit("BINARY :#{bin_op}")
      generate_expr(expr.operand)
      emit("STORE")
      generate_expr(expr.operand)
    end
  end

  def generate_expr(expr : TypedAST::Call)
    expr.args.reverse.each { |arg| generate_expr(arg) }
    if expr.func_name == "printf"
      emit("PRINTF #{expr.args.size - 1}")
    else
      emit("CALL :#{expr.func_name}")
    end
  end

  def generate_expr(expr : TypedAST::Cast)
    generate_expr(expr.operand)
    emit("AS #{type_s(expr.type)}")
  end

  def generate_expr(expr : TypedAST::Subscript)
    generate_expr(expr.index)
    generate_expr(expr.array)

    case type = expr.array.type
    when Type::FlatType
      emit("ADDR")
      elem_type = type.target_type
      emit("AS \"ptr<#{elem_type.id_name}>\"")
    end

    emit("BINARY :add")
    emit("DEREF")
  end

  def generate_expr(expr : TypedAST::FieldAccess)
    generate_expr(expr.obj)
    if expr.obj.type.is_a?(Type::PtrType)
      emit("DEREF")
    end
    emit("FIELD #{expr.field_index}")
  end

  def generate_expr(expr : TypedAST::AddrOf)
    generate_expr(expr.operand)
    emit("ADDR")
  end

  def generate_expr(expr : TypedAST::Deref)
    generate_expr(expr.operand)
    emit("DEREF")
  end

  def generate_expr(expr : TypedAST::SizeOf)
    emit("SIZEOF #{type_s(expr.target_type)}")
    emit("AS :i32")
  end

  def generate_expr(expr : TypedAST::InitList)
    expr.elements.reverse.each { |e| generate_expr(e) }
    emit("CREATE #{type_s(expr.type)}")
  end

  private def returns_void?(call : TypedAST::Call) : Bool
    call.type.id_name == "void"
  end

  private def type_s(type : Type) : String
    if type.needs_blit? || type.is_a?(Type::PtrType)
      "\"#{type.id_name}\""
    else
      ":#{type.id_name}"
    end
  end
end
