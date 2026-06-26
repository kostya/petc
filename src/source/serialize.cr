class Myc::Source::Serialize
  ANNOTATION_COLUMN = 20

  getter root : Node
  getter io : IO

  def initialize(@root, @io)
  end

  def serialize
    if @root.code == Opcode::Code::MOD
      @root.as(Node::Container).sections.each do |s|
        serialize_node(s, 0)
        io << '\n'
      end
    else
      serialize_node(@root, 0)
    end
  end

  protected def serialize_node(node : Node, indent : Int32)
    serialize_node_header(node, indent)
    serialize_node_body(node, indent + 1)
    serialize_node_footer(node, indent)
  end

  protected def serialize_node_header(node : Node, indent : Int32)
    line = String.build do |s|
      s << "  " * indent
      s << node.code.to_s

      node.values.try &.each_with_index do |value, index|
        s << " "
        format_value(value, s)
      end
    end

    io << line

    if c = node.comment
      padding = ANNOTATION_COLUMN - line.size
      padding = 1 if padding < 1
      io << " " * padding
      io << c
    end

    io << "\n"
  end

  protected def serialize_node_body(node : Node::Container, indent : Int32)
    node.sections.each { |s| serialize_node(s, indent) }
  end

  protected def serialize_node_body(node : Node::Sequence, indent : Int32)
    node.list.each { |op| serialize_node(op, indent) }
  end

  protected def serialize_node_body(node : Node, indent : Int32)
  end

  protected def serialize_node_footer(node : Node::Opcode, indent : Int32)
  end

  protected def serialize_node_footer(node : Node, indent : Int32)
    if close_code = CLOSE_OPCODES[node.code]?
      io << "  " * indent << close_code.to_s << "\n"
    end
  end

  private def format_value(v : Token::ArgType, io : IO)
    case v
    when String
      if v.empty? || Tokenizer::SEPARATOR.any? { |sep| v.includes?(sep) }
        v.inspect(io)
      else
        io << ':'
        io << v
      end
    else
      io << v
    end
  end
end
