struct Myc::Backend::QBE::TypeTranslator
  getter builder : Builder

  def initialize(@builder)
    @cache = Hash(String, String).new
  end

  def translate(type : Type) : String
    @cache[type.id_name] ||= do_translate(type)
  end

  private def do_translate(type : Type::VoidType)
    ""
  end

  private def do_translate(type : Type::BoolType)
    "w"
  end

  private def do_translate(type : Type::IntType)
    case type.bytes_count
    when 8 then "l"
    else        "w"
    end
  end

  private def do_translate(type : Type::FloatType)
    case type.bytes_count
    when 8 then "d"
    else        "s"
    end
  end

  private def do_translate(type : Type::PtrType)
    "l"
  end

  private def do_translate(type : Type::Fn)
    "l"
  end

  private def do_translate(type : Type::StructType)
    name = ":" + type.backend_name
    fields = type.data.map { |t| translate(t) }.join(", ")
    @builder.emit_type("type #{name} = { #{fields} }\n")
    name
  end

  private def do_translate(type : Type::FlatType)
    name = ":" + type.backend_name
    elem_type = translate(type.target_type)
    @builder.emit_type("type #{name} = { #{elem_type} #{type.elements_count} }\n")
    name
  end

  private def do_translate(type : Type::EnumType)
    name = ":" + type.backend_name
    tag_type = translate(type.index_type)
    payload_count = @builder.layout.enum_payload_count(type)
    if payload_count > 0
      @builder.emit_type("type #{name} = { #{tag_type}, w #{payload_count} }\n")
    else
      @builder.emit_type("type #{name} = { #{tag_type} }\n")
    end
    name
  end

  private def do_translate(type : Type::EnumVariantType)
    translate(type.parent_type)
  end

  private def do_translate(type : Type)
    raise "Unknown type: #{type.class} (#{type})"
  end
end
