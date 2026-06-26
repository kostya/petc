class Myc::Type::Fn < Myc::Type
  getter args : Array(Type)
  getter ret : Type
  getter vaarg : Bool

  def initialize(@args, @ret, @vaarg = false)
    @id_name = "fn"
    @backend_name = "fn"
  end

  def inspect(io)
    io << "("
    args.each_with_index do |type, index|
      io << "," if index != 0
      type.inspect(io)
    end
    if vaarg
      io << ", ..."
    end
    io << ")"
    io << " -> "
    ret.inspect(io)
  end
end
