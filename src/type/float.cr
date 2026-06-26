class Myc::Type::FloatType < Myc::Type
  getter bytes_count : UInt64

  def initialize(@id_name, @bytes_count)
    @backend_name = normalize_name(@id_name)
  end
end
