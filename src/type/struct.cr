class Myc::Type::StructType < Myc::Type
  property data = Array(Type).new
  property explicit_alignment : UInt64?

  def initialize(@id_name)
    @backend_name = normalize_name(id_name)
  end

  def field_type?(index : Int32) : Type?
    data[index]?
  end

  def repr(io)
    if hidden
      io << "struct<"
      data.each_with_index do |type, index|
        io << ", " if index != 0
        type.repr(io)
      end
      io << '>'
    else
      io << self.id_name
    end
  end
end
