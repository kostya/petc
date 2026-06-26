abstract class Myc::Type
  property hidden : Bool = false

  getter id_name : String
  getter backend_name : String

  def initialize(@id_name)
    @backend_name = normalize_name(id_name)
  end

  def to_s(io)
    repr(io)
  end

  def repr(io)
    io << self.id_name
  end

  def field_type?(index : Int32) : Type?
  end

  def needs_blit? : Bool
    case self
    when StructType, FlatType, EnumType, EnumVariantType then true
    else                                                      false
    end
  end

  def eq?(other : Type)
    self == other
  end

  protected def normalize_name(name : String) : String
    name.gsub(/[^a-zA-Z0-9_]/, "_")
  end
end

require "./type/*"
