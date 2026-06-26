class Myc::Type::PtrType < Myc::Type
  getter target_type : Type

  def initialize(@id_name, @target_type)
    @backend_name = normalize_name(@id_name)
  end

  def repr(io)
    io << "ptr<"
    target_type.repr(io)
    io << '>'
  end
end
