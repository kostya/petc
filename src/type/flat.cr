class Myc::Type::FlatType < Myc::Type
  property! target_type : Type?
  property elements_count : UInt64 = 0
  property explicit_alignment : UInt64?

  def initialize(@id_name)
    @backend_name = normalize_name(id_name)
  end

  def field_type?(index : Int32) : Type?
    if index >= 0 && index < elements_count
      target_type
    end
  end

  def repr(io)
    io << "flat<"
    target_type.repr(io)
    io << ", "
    io << elements_count
    io << '>'
  end
end
