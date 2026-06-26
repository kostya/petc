require "colorize"

class Myc::Error < Exception
  def print(io : IO)
    io << "Unknown error #{self.inspect}"
  end
end

class Myc::Error::Cli < Exception
end

class Myc::Error::Cmd < Myc::Error
  def initialize(@message, @cmd : String, @args : Array(String))
  end

  def print(io : IO)
    io << "Cmd failed: `#{([@cmd] + @args).join(" ")}`\n  "
    io << @message.colorize(:red)
    io << "\n"

    if ENV["BACKTRACE"]? == "1"
      pp backtrace
    end
  end
end

class Myc::Error::ErrorLoc < Myc::Error
  property loc : Location

  def initialize(@message, @loc)
  end

  def print(io : IO)
    lines, line_number, line_position = loc.load_info

    code_show(io, lines, line_number, line_position)

    prefix = " " * line_position
    io << prefix
    io << @message.colorize(:red)

    io << "\n"
    io << prefix
    io << "(at ".colorize(:yellow)
    io << (loc.filename + ":" + (line_number + 1).to_s + ":" + (line_position + 1).to_s + ")").colorize(:yellow)
    io << "\n\n"

    if ENV["BACKTRACE"]? == "1"
      pp backtrace
    end
  end

  protected def code_show(io, lines, line_number, line_position)
    source_lines(lines, line_number, prev_count: 2, after_count: 0) do |line, target|
      if target
        io << line
      else
        io << line
      end
      io << "\n"
      if target
        io << " " * line_position + "^".colorize(:red).to_s << "\n"
      end
    end
  end

  protected def source_lines(lines, id, prev_count = 0, after_count = 0, &)
    prev_id = id - prev_count
    after_id = id + after_count

    prev_id = 0 if prev_id < 0
    return if prev_id >= lines.size
    after_id = lines.size - 1 if after_id >= lines.size
    return if after_id < 0

    prev_id.upto(after_id) do |index|
      yield lines[index], index == id
    end

    nil
  end
end

require "./mod"
require "./source"

class Myc::Error::ErrorVisitor < Myc::Error
  property visitor : Myc::Backend::AbstractVisitor

  def initialize(@message, @visitor)
  end

  class ErrorBreaker < Exception
  end

  class ErrorSaver < Myc::Mod::Saver
    property finish_opcode : Opcode?
    property comment : String = ""
    property target_node : Source::Node?

    protected def save_seq_list(seq : Opcode::Seq, res : Source::Node::Sequence, locals_saved)
      seq.list.each do |op|
        node = save_opcode(op, locals_saved)
        res.list << node
        if op == finish_opcode
          node.comment = comment
          self.target_node = node
        end
      end
    end
  end

  class ErrorSerialize < Myc::Source::Serialize
    property target_node : Source::Node?

    protected def serialize_node_header(node : Source::Node, indent : Int32)
      super
      if target_node == node
        raise ErrorBreaker.new
      end
    end
  end

  def print(io : IO)
    f = visitor.builder.new_func(visitor.func_def)
    v = Myc::Backend::Linter::Visitor.new(visitor.builder, f,
      f.body_bb, visitor.func_def, visitor.mod, visitor.params)
    begin
      v.visit
    rescue
    end
    saver = ErrorSaver.new(visitor.mod, v.notes)
    saver.finish_opcode = visitor.current_op

    _, line_number, line_position = Location.new(visitor.mod.filename, visitor.current_op.offset).load_info
    comment = "< #{message}".colorize(:red).to_s
    comment += "\n"
    comment += " " * Source::Serialize::ANNOTATION_COLUMN + ("(at " + (visitor.mod.filename + ":" + (line_number + 1).to_s + ":" + (line_position + 1).to_s) + ")").colorize(:yellow).to_s

    saver.comment = comment
    node = saver.save_func(visitor.func_def)

    s = String.build do |io|
      es = ErrorSerialize.new(node, io)
      es.target_node = saver.target_node
      begin
        es.serialize
      rescue ErrorBreaker
      end

      io << "    ...\n"
      io << "ENDFUNC\n"
    end

    io << s

    if ENV["BACKTRACE"]? == "1"
      pp backtrace
    end
  end
end
