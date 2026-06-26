class Myc::Type::EnumType < Myc::Type
  property index_type : Type
  property data = Hash(String, EnumVariantType).new
  property payload_type : FlatType?
  property explicit_alignment : UInt64?

  def initialize(@id_name, @index_type)
    @backend_name = normalize_name(id_name)
  end

  def field_type?(index : Int32) : Type?
    case index
    when 0
      index_type
    when 1
      payload_type
    end
  end

  def generate_payload_type(mod : Mod, layout : Backend::Layout)
    t = Type::FlatType.new(self.id_name + "::__payload__")
    t.target_type = mod.typer.i32
    t.elements_count = layout.enum_payload_count(self)
    t.hidden = true
    @payload_type = t
  end
end

class Myc::Type::EnumVariantType < Myc::Type
  property original_name : String
  property parent_type : EnumType
  property position : Int32
  property value_types = Array(Type).new
  property composite_value_type : Type?

  def initialize(@id_name, @original_name, @parent_type, @position)
    @backend_name = normalize_name(id_name)
  end

  def field_type?(index : Int32) : Type?
    case index
    when 0
      parent_type.index_type
    when 1
      parent_type.payload_type
    end
  end
end
