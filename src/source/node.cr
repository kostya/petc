class Myc::Source::Node
  property code : Myc::Opcode::Code
  property values : Array(Token::ArgType)?

  property offset : UInt32 = 0
  property comment : String?

  def initialize(@code)
  end

  def error(msg : String, filename : String)
    Error::ErrorLoc.new(msg, Location.new(filename, offset))
  end
end

class Myc::Source::Node::Container < Myc::Source::Node
  property sections = Array(Node).new
end

class Myc::Source::Dom < Myc::Source::Node::Container
  def initialize
    @code = Myc::Opcode::Code::MOD
  end
end

class Myc::Source::Node::Sequence < Myc::Source::Node
  property list = Array(Node).new
end

class Myc::Source::Node::Opcode < Myc::Source::Node
end
