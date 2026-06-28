module Myc::Mycc::TypedAST
  abstract class Node
    getter type : Type
    getter location : Location

    def initialize(@type, @location)
    end

    def inspect(io : IO)
      io << self.class.name.sub("Myc::Mycc::TypedAST::", "")
      io << '('
      io << type.id_name
      io << ", "
      inspect_fields(io)
      io << ')'
    end

    private def inspect_fields(io : IO)
    end
  end

  class IntLiteral < Node
    getter value : Int64

    def initialize(@value, @type, @location); end

    private def inspect_fields(io : IO)
      io << value
    end
  end

  class FloatLiteral < Node
    getter value : Float64

    def initialize(@value, @type, @location); end

    private def inspect_fields(io : IO)
      io << value
    end
  end

  class CharLiteral < Node
    getter value : Int32

    def initialize(@value, @type, @location); end

    private def inspect_fields(io : IO)
      value.chr.inspect(io)
    end
  end

  class StringLiteral < Node
    getter value : String

    def initialize(@value, @type, @location); end

    private def inspect_fields(io : IO)
      @value.inspect(io)
    end
  end

  class VarRef < Node
    getter name : String

    def initialize(@name, @type, @location); end

    private def inspect_fields(io : IO)
      io << name
    end
  end

  class BinaryOp < Node
    getter op : Symbol
    getter left : Node
    getter right : Node

    def initialize(@op, @left, @right, @type, @location); end

    private def inspect_fields(io : IO)
      left.inspect(io)
      io << ", "
      op.inspect(io)
      io << ", "
      right.inspect(io)
    end
  end

  class UnaryOp < Node
    getter op : Symbol
    getter operand : Node
    getter is_statement : Bool

    def initialize(@op, @operand, @type, @location, @is_statement = false); end

    private def inspect_fields(io : IO)
      io << "#{op}, "
      operand.inspect(io)
      io << ", "
      is_statement.inspect(io)
    end
  end

  class Call < Node
    getter func_name : String
    getter args : Array(Node)

    def initialize(@func_name, @args, @type, @location); end

    private def inspect_fields(io : IO)
      func_name.inspect(io)
      io << ", "
      args.each_with_index do |arg, index|
        io << ", " if index != 0
        arg.inspect(io)
      end
    end
  end

  class Cast < Node
    getter operand : Node

    def initialize(@operand, @type, @location); end

    private def inspect_fields(io : IO)
      operand.inspect(io)
    end
  end

  class Subscript < Node
    getter array : Node
    getter index : Node

    def initialize(@array, @index, @type, @location); end

    private def inspect_fields(io : IO)
      array.inspect(io)
      io << ", "
      index.inspect(io)
    end
  end

  class FieldAccess < Node
    getter obj : Node
    getter field_name : String
    getter field_index : Int32

    def initialize(@obj, @field_name, @field_index, @type, @location); end

    private def inspect_fields(io : IO)
      obj.inspect(io)
      io << ", "
      field_name.inspect(io)
      io << ", "
      field_index.inspect(io)
    end
  end

  class AddrOf < Node
    getter operand : Node

    def initialize(@operand, @type, @location); end

    private def inspect_fields(io : IO)
      operand.inspect(io)
    end
  end

  class Deref < Node
    getter operand : Node

    def initialize(@operand, @type, @location); end

    private def inspect_fields(io : IO)
      operand.inspect(io)
    end
  end

  class SizeOf < Node
    getter target_type : Type

    def initialize(@target_type, @type, @location); end

    private def inspect_fields(io : IO)
      io << target_type.id_name
    end
  end

  class InitList < Node
    getter elements : Array(Node)

    def initialize(@elements, @type, @location); end

    private def inspect_fields(io : IO)
      elements.each_with_index do |el, index|
        io << ", " if index != 0
        el.inspect(io)
      end
    end
  end

  abstract class Stmt
    getter location : Location

    def initialize(@location); end

    def inspect(io : IO)
      io << self.class.name.sub("Myc::Mycc::TypedAST::", "")
      io << "("
      inspect_fields(io)
      io << ")"
    end

    private def inspect_fields(io : IO); end

    protected def inspect_array_stmt(io, arr : Array(Stmt))
      io << "["
      arr.each_with_index do |el, index|
        io << ", " if index != 0
        el.inspect(io)
      end
      io << "]"
    end
  end

  class VarDecl < Stmt
    getter name : String
    getter var_type : Type
    getter init : Node?
    getter is_static : Bool
    getter original_name : String

    def initialize(@name, @var_type, @init, @location, @is_static = false, @original_name = name)
    end

    private def inspect_fields(io : IO)
      name.inspect(io)
      io << ", "
      io << var_type.id_name
      if is_static
        io << ", "
        io << "static(#{original_name})"
      end
      if i = init
        io << ", "
        i.inspect(io)
      end
    end
  end

  class Assign < Stmt
    getter left : Node
    getter right : Node

    def initialize(@left, @right, @location); end

    private def inspect_fields(io : IO)
      left.inspect(io)
      io << ", "
      right.inspect(io)
    end
  end

  class ExprStmt < Stmt
    getter expr : Node

    def initialize(@expr, @location); end

    private def inspect_fields(io : IO)
      expr.inspect(io)
    end
  end

  class Return < Stmt
    getter value : Node?

    def initialize(@value, @location); end

    private def inspect_fields(io : IO)
      if v = value
        v.inspect(io)
      end
    end
  end

  class If < Stmt
    getter condition : Node
    getter then_body : Array(Stmt)
    getter else_body : Array(Stmt)

    def initialize(@condition, @then_body, @else_body, @location); end

    private def inspect_fields(io : IO)
      condition.inspect(io)
      io << ", "
      inspect_array_stmt(io, then_body)
      io << ", "
      inspect_array_stmt(io, else_body)
    end
  end

  class While < Stmt
    getter condition : Node
    getter body : Array(Stmt)

    def initialize(@condition, @body, @location); end

    private def inspect_fields(io : IO)
      condition.inspect(io)
      io << ", "
      inspect_array_stmt(io, body)
    end
  end

  class For < Stmt
    getter init : Stmt?
    getter condition : Node?
    getter update : Stmt?
    getter body : Array(Stmt)

    def initialize(@init, @condition, @update, @body, @location); end

    private def inspect_fields(io : IO)
      if i = init
        i.inspect(io)
        io << ", "
      end

      if c = condition
        c.inspect(io)
        io << ", "
      end

      if u = update
        u.inspect(io)
        io << ", "
      end

      inspect_array_stmt(io, body)
    end
  end

  class Break < Stmt
    def initialize(@location); end
  end

  class Continue < Stmt
    def initialize(@location); end
  end

  class Function
    getter name : String
    getter params : Array({String, Type})
    getter return_type : Type
    getter body : Array(Stmt)?
    getter location : Location

    def initialize(@name, @params, @return_type, @body, @location); end

    def inspect(io : IO)
      io << "Function " << name << "("
      params.each_with_index do |(pname, ptype), i|
        io << ", " if i > 0
        io << pname << " : " << ptype.id_name
      end
      io << ") -> " << return_type.id_name
      io << " @" << location.offset
    end
  end

  class Program
    getter functions : Array(Function)
    getter structs : Hash(String, Array({String, Type}))
    getter globals : Array(VarDecl)

    def initialize(@functions, @structs, @globals); end

    def inspect(io : IO)
      io << "Program\n"
      structs.each do |name, fields|
        io << "  struct " << name << "\n"
        fields.each do |fname, ftype|
          io << "    " << fname << " : " << ftype.id_name << "\n"
        end
      end
      globals.each do |var|
        io << "  global  "
        var.inspect(io)
        io << "\n"
      end
      functions.each do |func|
        io << "  "
        func.inspect(io)
        io << "\n"
        if body = func.body
          print_stmts(io, body, "    ")
        end
      end
    end

    private def print_stmts(io : IO, stmts : Array(Stmt), indent : String)
      stmts.each do |stmt|
        io << indent
        stmt.inspect(io)
        io << "\n"
        case stmt
        when If
          io << indent << "  then:\n"
          print_stmts(io, stmt.then_body, indent + "    ")
          if !stmt.else_body.empty?
            io << indent << "  else:\n"
            print_stmts(io, stmt.else_body, indent + "    ")
          end
        when While
          io << indent << "  body:\n"
          print_stmts(io, stmt.body, indent + "    ")
        when For
          io << indent << "  body:\n"
          print_stmts(io, stmt.body, indent + "    ")
        end
      end
    end
  end
end
