class Myc::Source::Tokenizer
  @chars : Array(Char)
  @char_id : UInt32
  @last_char_id : Int32
  getter current_char : Char

  END_CHAR = '\0'

  def initialize(@source : String, @filename : String)
    @char_id = 0
    @chars = @source.chars
    @current_char = @chars.size > 0 ? @chars[0] : END_CHAR
    @last_char_id = @chars.size - 1
    @opcodes_hash = Hash(UInt64, Opcode::Code).new
    init_opcodes_hash
  end

  private def init_opcodes_hash
    {% for name in Opcode::Code.constants %}
      @opcodes_hash[hash_str({{name.stringify}})] = Opcode::Code::{{name.id}}
    {% end %}

    if @opcodes_hash.size != {{ Opcode::Code.constants.size }}
      raise "If you see this the universe is collapsed"
    end

    @opcodes_hash.rehash
  end

  private def hash_str(str) : UInt64
    h = 0xcbf29ce484222325_u64
    str.each_char do |ch|
      h ^= ch.ord.to_u64
      h &*= 0x100000001b3_u64
    end
    h
  end

  private def move_next
    @char_id += 1
    if @char_id > @last_char_id
      @current_char = END_CHAR
    else
      @current_char = @chars[@char_id]
    end
  end

  private def consume_chars(&)
    while true
      ch = current_char
      break if ch == END_CHAR
      yield ch
      move_next
    end
  end

  private def error(msg)
    Error::ErrorLoc.new(msg, Location.new(@filename, @char_id))
  end

  def parse : Array(Token)
    tokens = [] of Token

    while @char_id <= @last_char_id
      tkn_offset = @char_id

      if tkn = take_token
        tkn.offset = tkn_offset
        tokens << tkn
      end
    end

    tokens
  end

  private def take_token : Token?
    case cc = current_char
    when .ascii_letter?
      if ('A'..'Z').includes?(cc)
        start_char_id = @char_id
        op_hash = consume_opcode_hash
        if opcode = @opcodes_hash[op_hash]?
          Token::Opcode.new(opcode)
        else
          bad_opcode = String.build do |s|
            start_char_id.upto(@char_id - 1) do |id|
              s << @chars[id]
            end
          end
          Token::OpcodeUnknown.new(bad_opcode)
        end
      else
        case name = consume_ident
        when "true"
          Token::Arg.new(true)
        when "false"
          Token::Arg.new(false)
        else
          Token::Arg.new(name)
        end
      end
    when ' ', '\t'
      consume_chars do |ch|
        break unless ch == ' ' || ch == '\t'
      end
      nil
    when '\r'
      move_next
      if current_char == '\n'
        move_next
      end
      nil
    when '\n'
      move_next
      nil
    when '#', ';'
      consume_chars do |ch|
        break if ch == '\n'
      end
      nil
    when '"'
      Token::Arg.new consume_string('"')
    when '\''
      Token::Arg.new consume_string('\'')
    when ':'
      Token::Arg.new consume_string_until_separator
    when .ascii_number?
      value = extract_int_or_float
      unless separator?(current_char)
        raise error("expected separator after number")
      end
      Token::Arg.new(value)
    when '-'
      move_next
      if current_char.ascii_number?
        value = -extract_int_or_float

        unless separator?(current_char)
          raise error("expected separator after number")
        end

        Token::Arg.new(value)
      else
        raise error("unexpected symbol '-'")
      end
    else
      raise error("unexpected symbol #{cc.inspect}")
    end
  end

  SEPARATOR = {' ', '\t', '\n', '\r', '#', ';', END_CHAR}

  private def separator?(ch)
    SEPARATOR.includes?(ch)
  end

  private def consume_opcode_hash : UInt64
    h = 0xcbf29ce484222325_u64
    consume_chars do |ch|
      break if separator?(ch)
      h ^= ch.ord.to_u64
      h &*= 0x100000001b3_u64
    end
    h
  end

  private def consume_ident
    String.build do |io|
      consume_chars do |ch|
        if ch.ascii_letter? || ch == '_' || ch.ascii_number?
          io << ch
        else
          break
        end
      end
    end
  end

  private def consume_string(close_char : Char) : String
    move_next

    String.build do |io|
      while (current_char != close_char) && (current_char != END_CHAR)
        c = _consume_escaped_char
        io << c
      end

      if current_char == close_char
        move_next
      else
        raise error("string not ended with #{close_char.inspect}")
      end
    end
  end

  private def consume_string_until_separator : String
    move_next

    String.build do |io|
      while !separator?(current_char)
        c = _consume_escaped_char
        io << c
      end
    end
  end

  ESCAPE_MAP = {
    'n'  => '\n',
    't'  => '\t',
    'r'  => '\r',
    '\\' => '\\',
    'f'  => '\f',
    'v'  => '\v',
    'a'  => '\a',
    'b'  => '\b',
    's'  => ' ',
    'e'  => 27.chr,
    '"'  => '"',
    '\'' => '\'',
  }

  private def _consume_escaped_char
    if current_char == '\\'
      move_next
      c2 = current_char
      if ch = ESCAPE_MAP[c2]?
        move_next
        ch
      else
        raise error("undefined escape char: #{c2.ord}")
      end
    else
      ch = current_char
      move_next
      ch
    end
  end

  private def consume_number : Int64
    if take?('0')
      if take?('x')
        consume_hex_number
      else
        0_i64
      end
    else
      consume_dec_number
    end
  end

  private def consume_hex_number : Int64
    number = 0_i64

    consume_chars do |ch|
      case ch
      when .ascii_number?
        number = number * 16 + (ch.ord - '0'.ord)
      when 'a'..'f'
        number = number * 16 + (ch.ord - 'a'.ord + 10)
      when 'A'..'F'
        number = number * 16 + (ch.ord - 'A'.ord + 10)
      when '_'
      else
        break
      end
    end

    number
  rescue OverflowError
    raise error("hex number constant is too big")
  end

  private def consume_dec_number : Int64
    number = current_char.to_i64
    move_next

    consume_chars do |ch|
      case ch
      when .ascii_number?
        number = number * 10_i64 + ch.to_i64
      when '_'
      else
        break
      end
    end

    number
  rescue OverflowError
    raise error("number constant is too big")
  rescue ArgumentError
    raise error("number constant is too big")
  end

  private def extract_int_or_float : Int64 | Float64
    number = consume_number

    if current_char == '.'
      move_next

      if current_char.ascii_number?
        zeros = 0
        while current_char == '0'
          move_next
          zeros += 1
        end
        m = current_char.ascii_number? ? consume_number : 0_i64
        exp = if current_char == 'e' || current_char == 'E'
                move_next
                was_plus = take?('+')
                if take?('-')
                  if was_plus
                    raise error("unexpected +-, what is it?")
                  end
                  -consume_number
                else
                  consume_number
                end
              else
                0_i64
              end
        return "#{number}.#{"0" * zeros}#{m}e#{exp}".to_f64
      else
        raise error("expected number after .")
      end
    end

    if current_char == 'e' || current_char == 'E'
      move_next
      was_plus = take?('+')
      exp = if take?('-')
              if was_plus
                raise error("unexpected +- sequence")
              end
              -consume_number
            else
              consume_number
            end
      return "#{number}e#{exp}".to_f64
    end

    number
  end

  private def take?(ch : Char) : Char?
    c = current_char
    if c == ch
      move_next
      ch
    end
  end
end
