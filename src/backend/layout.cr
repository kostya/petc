class Myc::Backend::Layout
  getter target : Target

  def initialize(@target)
    @size_cache = Hash(Type, UInt64).new
    @alignment_cache = Hash(Type, UInt64).new
  end

  def size_of(type : Type) : UInt64
    @size_cache[type] ||= _size_of(type)
  end

  def alignment_of(type : Type) : UInt64
    @alignment_cache[type] ||= _alignment_of(type)
  end

  private def _size_of(type : Type) : UInt64
    case type
    when Type::IntType         then type.bytes_count
    when Type::FloatType       then type.bytes_count
    when Type::PtrType         then @target.pointer_size
    when Type::BoolType        then 1_u64
    when Type::VoidType        then 0_u64
    when Type::StructType      then compute_struct_size(type)
    when Type::FlatType        then type.elements_count * size_of(type.target_type)
    when Type::EnumType        then compute_enum_size(type)
    when Type::EnumVariantType then compute_enum_size(type.parent_type)
    when Type::Fn              then @target.pointer_size
    else                            raise "unexpected type #{type.inspect}"
    end
  end

  private def _alignment_of(type : Type) : UInt64
    case type
    when Type::IntType         then type.bytes_count
    when Type::FloatType       then type.bytes_count
    when Type::PtrType         then @target.pointer_alignment
    when Type::BoolType        then 1_u64
    when Type::StructType      then compute_struct_alignment(type)
    when Type::FlatType        then alignment_of(type.target_type)
    when Type::EnumType        then compute_enum_alignment(type)
    when Type::EnumVariantType then compute_enum_alignment(type.parent_type)
    when Type::Fn              then @target.pointer_alignment
    else                            raise "unexpected type #{type.inspect}"
    end
  end

  private def compute_struct_size(type : Type::StructType) : UInt64
    offset = 0_u64
    max_align = 1_u64
    type.data.each do |field_type|
      align = alignment_of(field_type)
      max_align = align if align > max_align
      offset = align_to(offset, align)
      offset += size_of(field_type)
    end
    align_to(offset, max_align)
  end

  private def compute_struct_alignment(type : Type::StructType) : UInt64
    if ea = type.explicit_alignment
      return ea
    end

    if type.data.any?
      return type.data.max_of { |t| alignment_of(t) }
    end

    1_u64
  end

  def field_offset(type : Type::StructType, index : UInt64) : UInt64
    offset = 0_u64
    return offset if index == 0
    0.upto(index - 1) do |i|
      field = type.data[i]
      offset = align_to(offset, alignment_of(field))
      offset += size_of(field)
    end
    align_to(offset, alignment_of(type.data[index]))
  end

  def field_offset(type : Type::FlatType, index : UInt64) : UInt64
    size_of(type.target_type) * index
  end

  def field_offset(type : Type::EnumType, index : UInt64) : UInt64
    case index
    when 0
      0_u64
    when 1
      tag_size = size_of(type.index_type)
      tag_align = alignment_of(type.index_type)
      align_to(tag_size, tag_align)
    else
      raise "enum #{type.id_name} has no field #{index}"
    end
  end

  def field_offset(type : Type::EnumVariantType, index : UInt64) : UInt64
    if index == 0
      0_u64
    else
      tag_size = size_of(type.parent_type.index_type)
      tag_align = alignment_of(type.parent_type.index_type)
      align_to(tag_size, tag_align) + field_offset(type.composite_value_type.not_nil!, index - 1)
    end
  end

  def field_offset(type : Type, index : UInt64) : UInt64
    raise "undefined field_offset for #{type}"
  end

  private def align_to(offset : UInt64, alignment : UInt64) : UInt64
    (offset + alignment - 1) // alignment * alignment
  end

  private def compute_enum_size(type : Type::EnumType) : UInt64
    tag_size = size_of(type.index_type)
    tag_align = alignment_of(type.index_type)

    max_payload = if type.data.any?
                    type.data.max_of do |_, variant|
                      if cvt = variant.composite_value_type
                        size_of(cvt)
                      else
                        0_u64
                      end
                    end
                  else
                    0_u64
                  end

    align_to(tag_size, tag_align) + max_payload
  end

  private def compute_enum_alignment(type : Type::EnumType) : UInt64
    if ea = type.explicit_alignment
      return ea
    end

    tag_align = alignment_of(type.index_type)

    max_payload = if type.data.any?
                    type.data.max_of do |_, variant|
                      if cvt = variant.composite_value_type
                        size_of(cvt)
                      else
                        0_u64
                      end
                    end
                  else
                    0_u64
                  end

    {tag_align, max_payload > 0 ? 4_u64 : 1_u64}.max
  end

  def enum_payload_count(type : Type::EnumType) : UInt64
    payload_size = size_of(type) - size_of(type.index_type)
    payload_size > 0 ? (payload_size + 3) // 4 : 0_u64
  end

  def ptr_as_int_type(typer : Mod::Typer) : Type::IntType
    target.pointer_size == 8 ? typer.u64.as(Type::IntType) : typer.u32.as(Type::IntType)
  end

  def int_format(type : Type::IntType) : String
    if type.signed
      case type.bytes_count
      when 8
        target.arch.arm64? ? "%lli" : "%li"
      when 4 then "%d"
      when 2 then "%hi"
      else        "%hhi"
      end
    else
      case type.bytes_count
      when 8
        target.arch.arm64? ? "%llu" : "%lu"
      when 4 then "%u"
      when 2 then "%hu"
      else        "%hhu"
      end
    end
  end

  def int_hex_format(type : Type::IntType) : String
    case type.bytes_count
    when 8
      target.arch.arm64? ? "0x%llx" : "0x%lx"
    when 4 then "0x%x"
    when 2 then "0x%hx"
    else        "0x%hhx"
    end
  end

  def float_format(type : Type::FloatType) : String
    "%.7f"
  end
end
