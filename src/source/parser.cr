module Myc::Source
  record Section,
    open_code : Opcode::Code,
    close_code : Opcode::Code,
    subsections : Set(Opcode::Code),
    have_seq : Bool = false

  TOP_SECTIONS = {
    Opcode::Code::FUNC => Section.new(
      Opcode::Code::FUNC,
      Opcode::Code::ENDFUNC,
      Set(Opcode::Code).new([Opcode::Code::ARGS, Opcode::Code::RETURN, Opcode::Code::BODY, Opcode::Code::ATTRIBUTES])),

    Opcode::Code::ENUM => Section.new(
      Opcode::Code::ENUM,
      Opcode::Code::ENDENUM,
      Set(Opcode::Code).new([Opcode::Code::VARIANT, Opcode::Code::ALIGN])),

    Opcode::Code::GLOBAL => Section.new(
      Opcode::Code::GLOBAL,
      Opcode::Code::ENDGLOBAL,
      Set(Opcode::Code).new,
      true),

    Opcode::Code::STRUCT => Section.new(
      Opcode::Code::STRUCT,
      Opcode::Code::ENDSTRUCT,
      Set(Opcode::Code).new,
      true),

    Opcode::Code::FLAT => Section.new(
      Opcode::Code::FLAT,
      Opcode::Code::ENDFLAT,
      Set(Opcode::Code).new,
      true),
  }

  LOCAL_SECTIONS = {
    Opcode::Code::IF => Section.new(
      Opcode::Code::IF,
      Opcode::Code::ENDIF,
      Set(Opcode::Code).new([Opcode::Code::THEN, Opcode::Code::ELSE])),

    Opcode::Code::LOOP => Section.new(
      Opcode::Code::LOOP,
      Opcode::Code::ENDLOOP,
      Set(Opcode::Code).new([Opcode::Code::INIT, Opcode::Code::COND, Opcode::Code::BODY, Opcode::Code::STEP])),

    Opcode::Code::SWITCH => Section.new(
      Opcode::Code::SWITCH,
      Opcode::Code::ENDSWITCH,
      Set(Opcode::Code).new([Opcode::Code::CASE, Opcode::Code::ELSE])),
  }

  CLOSE_OPCODES = begin
    h = Hash(Opcode::Code, Opcode::Code).new
    TOP_SECTIONS.each { |k, s| h[k] = s.close_code }
    LOCAL_SECTIONS.each { |k, s| h[k] = s.close_code }
    h
  end

  class Parser
    property tokens : Array(Token)
    getter current_token : Token
    getter dom : Dom

    def initialize(@filename : String, @tokens)
      @token_id = 0
      @tokens << Token::Eof.new
      @last_token_id = @tokens.size - 1
      @current_token = @tokens[0]
      @dom = Dom.new
    end

    private def error(msg)
      Error::ErrorLoc.new(msg, Location.new(@filename, current_token.offset))
    end

    def parse
      while true
        case ct = @current_token
        when Token::Opcode
          if (section = TOP_SECTIONS[ct.code]?)
            if section.have_seq
              @dom.sections << parse_body_section(ct.code, section)
              move_next
            else
              @dom.sections << parse_section(section)
            end
          else
            raise error("unknown root section #{ct.code}")
          end
        when Token::Eof
          break
        when Token::OpcodeUnknown
          raise error("unknown root section #{ct.name}")
        else
          raise error("values not allowed at top level")
        end
      end
    end

    private def parse_section(section : Section) : Node
      node = Node::Container.new(section.open_code)
      node.offset = current_token.offset
      move_next
      consume_values(node)

      while true
        case ct = current_token
        when Token::Opcode
          if ct.code == section.close_code
            move_next
            return node
          elsif section.subsections.includes?(ct.code)
            node.sections << parse_body_section(ct.code, section)
          else
            break
          end
        else
          raise error("expected section opcode")
        end
      end

      raise error("not closed section, missing #{section.close_code}")
    end

    private def parse_body_section(code : Opcode::Code, parent_section : Section) : Node
      node = Node::Sequence.new(code)
      node.offset = current_token.offset
      move_next
      consume_values(node)

      subsections = parent_section.subsections
      close_code = parent_section.close_code
      while true
        case ct = current_token
        when Token::Opcode
          if subsections.includes?(ct.code)
            return node
          elsif ct.code == close_code
            return node
          else
            if (ct.code.sequence? && ct.code != Opcode::Code::GLOBAL) || ct.code.meta? || (ct.code.container? && TOP_SECTIONS[ct.code]?)
              raise error("unexpected opcode #{ct.code}")
            else
              node.list << parse_opcode(ct.code)
            end
          end
        when Token::OpcodeUnknown
          raise error("unknown opcode #{ct.name}")
        else
          raise error("not closed section #{parent_section.open_code}")
        end
      end
    end

    private def parse_opcode(code : Opcode::Code) : Node
      if section = LOCAL_SECTIONS[code]?
        parse_section(section)
      elsif (section = TOP_SECTIONS[code]?) && (code != Opcode::Code::GLOBAL)
        raise error("top section #{code} can't be used in the local context")
      else
        parse_raw_opcode(code)
      end
    end

    private def parse_raw_opcode(code : Opcode::Code) : Node
      node = Node::Opcode.new(code)
      node.offset = current_token.offset
      move_next
      consume_values(node)
      node
    end

    private def consume_values(node : Node)
      values = node.values
      while true
        case ct = current_token
        when Token::Arg
          if values
            values << ct.v
          else
            values = [ct.v] of Token::ArgType
            node.values = values
          end
          move_next
        else
          break
        end
      end
    end

    private def move_next
      @token_id += 1
      @current_token = @tokens[@token_id]
    end
  end
end
