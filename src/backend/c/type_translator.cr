struct Myc::Backend::C::TypeTranslator
  getter builder : Builder

  def initialize(@builder)
    @cache = Hash(String, String).new
  end

  def translate(type : Type) : String
    if cached = @cache[type.id_name]?
      return cached
    end

    if res = do_simple_translate(type)
      @cache[type.id_name] = res
      return res
    end

    case type
    when Type::StructType
      @builder.forward_declare(type.backend_name)
    when Type::EnumType
      @builder.forward_declare(type.backend_name)
    when Type::FlatType
      @builder.forward_declare_array(type.backend_name, translate(type.target_type), type.elements_count)
    end

    @cache[type.id_name] = type.backend_name
    do_complex_translate(type)
    type.backend_name
  end

  private def do_simple_translate(type : Type::VoidType)
    "void"
  end

  private def do_simple_translate(type : Type::BoolType)
    "int"
  end

  private def do_simple_translate(type : Type::IntType)
    prefix = type.signed ? "" : "u"
    case type.bytes_count
    when 8 then "#{prefix}int64_t"
    when 4 then "#{prefix}int32_t"
    when 2 then "#{prefix}int16_t"
    when 1 then "#{prefix}int8_t"
    else        "#{prefix}int32_t"
    end
  end

  private def do_simple_translate(type : Type::FloatType)
    case type.bytes_count
    when 8 then "double"
    when 4 then "float"
    else        "double"
    end
  end

  private def do_simple_translate(type : Type::Fn)
    translate(type.ret) + "(*)"
  end

  private def do_simple_translate(type : Type::PtrType)
    translate(type.target_type) + "*"
  end

  private def do_simple_translate(type : Type)
    nil
  end

  private def do_complex_translate(type : Type::StructType)
    fields = type.data.map_with_index { |t, i| "#{translate(t)} field#{i};" }.join(" ")
    @builder.define_struct(type.backend_name, fields)
  end

  private def do_complex_translate(type : Type::FlatType)
  end

  private def do_complex_translate(type : Type::EnumType)
    payload_count = @builder.layout.enum_payload_count(type)
    payload_str = payload_count > 0 ? "int32_t field1[#{payload_count}];" : ""
    @builder.define_enum(type.backend_name, translate(type.index_type), payload_str)

    type.data.each do |_, variant|
      variant_name = variant.backend_name
      @builder.define_alias(variant_name, type.backend_name)
    end
  end

  private def do_complex_translate(type : Type::EnumVariantType)
    translate(type.parent_type)
  end

  private def do_complex_translate(type : Type)
    raise "Unknown type: #{type.class} (#{type})"
  end
end
