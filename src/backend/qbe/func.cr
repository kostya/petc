class Myc::Backend::QBE::Func < Myc::Backend::AbstractFunc
  getter temp_counter : Int32
  getter blocks : Array(BB)
  getter body_io : IO::Memory

  def initialize(@builder : Builder, @func_def : Mod::FuncDef)
    super(@builder, @func_def)
    @temp_counter = 0
    @blocks = Array(BB).new
    @body_io = IO::Memory.new
  end

  def new_bb(name : String) : AbstractBB
    BB.new(name, @builder, self, @func_def)
  end

  def new_visitor : AbstractVisitor
    Visitor.new(@builder, self, body_bb, func_def, func_def.mod, params)
  end

  def builder
    @builder.as(Builder)
  end

  def params : Array(Value)
    @func_def.type_fn.args.map_with_index do |type, index|
      Value.new(BBVal.new("%arg#{index}"), type, Value::MM::Val, Value::PP::Param.new(index))
    end
  end

  def emit(s : String)
    @body_io << s
  end

  def build
    @func_def.attributes.try &.each do |attr|
      case attr
      when "noinline"
      else
        raise Error::ErrorLoc.new("unknown attr #{attr}", Location.new(func_def.mod.filename, func_def.node.offset))
      end
    end

    ret_type = builder.qbe_type(@func_def.type_fn.ret)
    args = @func_def.type_fn.args.map_with_index { |t, i| "#{builder.qbe_type(t)} %arg#{i}" }

    emit "export function #{ret_type} $#{@func_def.name}(#{args.join(", ")}) {\n"
    emit "@start\n"

    v = new_visitor
    v.visit

    @alloca_bb.as(BB).copy_data(body_io, false)

    emit "  jmp @body\n"

    unless v.bb.dead_end
      v.bb.as(BB).emit "jmp @ret"
    end

    @body_bb.as(BB).copy_data(body_io, true)
    @blocks.each &.copy_data(body_io, true)

    emit "@ret\n"
    if @func_def.have_ret?
      if (r = result) && r.type.needs_blit?
        emit "  ret %__myc_result\n"
      else
        ret_type = @func_def.type_fn.ret
        qbe_ret_type = builder.qbe_type(ret_type)

        if ret_type.is_a?(Type::IntType) && ret_type.bytes_count < 4
          load_op = ret_type.signed ? "loadsb" : "loadub"
          emit "  %ret_val =w #{load_op} %__myc_result\n"
        elsif ret_type.is_a?(Type::BoolType)
          emit "  %ret_val =w loadub %__myc_result\n"
        else
          emit "  %ret_val =#{qbe_ret_type} load#{qbe_ret_type} %__myc_result\n"
        end

        emit "  ret %ret_val\n"
      end
    else
      emit "  ret\n"
    end

    emit "}\n\n"
  end

  def new_temp : String
    @temp_counter += 1
    "%t#{@temp_counter}"
  end

  def register_block(bb : BB)
    @blocks << bb
  end
end
