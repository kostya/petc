class Myc::Backend::Llvm::TypeTranslator
  getter layout : Layout

  def initialize(@context : LLVM::Context, @layout)
    @cache = Hash(String, LLVM::Type).new
  end

  def translate(type : Type) : LLVM::Type
    @cache[type.id_name] ||= do_translate(type)
  end

  private def do_translate(type : Type::VoidType)
    @context.void
  end

  private def do_translate(type : Type::BoolType)
    @context.int1
  end

  private def do_translate(type : Type::IntType)
    case type.bytes_count
    when 8 then @context.int64
    when 4 then @context.int32
    when 2 then @context.int16
    when 1 then @context.int8
    else        @context.int32
    end
  end

  private def do_translate(type : Type::FloatType)
    case type.bytes_count
    when 8 then @context.double
    when 4 then @context.float
    else        @context.double
    end
  end

  private def do_translate(type : Type::PtrType)
    @context.pointer
  end

  private def do_translate(type : Type::Fn)
    @context.pointer
  end

  private def do_translate(type : Type::StructType)
    field_types = type.data.map { |t| translate(t) }
    @context.struct(field_types, type.id_name)
  end

  private def do_translate(type : Type::FlatType)
    translate(type.target_type).array(type.elements_count)
  end

  private def do_translate(type : Type::EnumType)
    tag = translate(type.index_type)
    payload = @context.int32.array(@layout.enum_payload_count(type))
    @context.struct([tag, payload], type.id_name)
  end

  private def do_translate(type : Type::EnumVariantType)
    translate(type.parent_type)
  end

  private def do_translate(type : Type)
    raise "Unknown type: #{type.class} (#{type})"
  end
end
