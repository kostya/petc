class Myc::Mod::Typer::Parser
  abstract struct Tkn; end

  record Tkn::Name < Tkn, name : String
  record Tkn::Less < Tkn
  record Tkn::More < Tkn
  record Tkn::Comma < Tkn
  record Tkn::Number < Tkn, number : Int64
  record Tkn::Undef < Tkn

  getter typer : Typer
  getter tokens : Array(Tkn)

  def initialize(@id_name : String, @typer : Typer, @loc : Location)
    @tokens = get_tnks
    @pos = 0
  end

  private def current_token : Tkn
    if @pos < @tokens.size
      @tokens[@pos]
    else
      Tkn::Undef.new
    end
  end

  private def get_tnks : Array(Tkn)
    res = [] of Tkn
    chars = @id_name.chars
    pos = 0
    length = chars.size
    while pos < length
      case ch = chars[pos]
      when .ascii_letter?, '_'
        str = String.build do |s|
          while (pos < length) && (ch = chars[pos])
            if ch.ascii_letter? || ch.ascii_number? || ch == '_' || ch == ':'
              s << ch
              pos += 1
            else
              break
            end
          end
        end
        res << Tkn::Name.new(str)
      when .ascii_number?
        str = String.build do |s|
          while (pos < length) && (ch = chars[pos])
            if ch.ascii_number? || ch == '_'
              s << ch
              pos += 1
            else
              break
            end
          end
        end
        if number = str.to_i64?
          res << Tkn::Number.new(number)
        else
          raise error("cant number to i64 `#{str}`")
        end
      when ' ', '\t'
        pos += 1
      when '>'
        res << Tkn::More.new
        pos += 1
      when '<'
        res << Tkn::Less.new
        pos += 1
      when ','
        res << Tkn::Comma.new
        pos += 1
      else
        raise error("unexpected char `#{ch}` at #{pos} in `#{chars[pos..({chars.size - 1, pos + 10}.min)].join}`")
      end
    end

    res
  end

  def get_type : Type
    type = parse
    raise error("not all tokens processed #{@tokens[@pos..-1].inspect}") if @pos < @tokens.size
    type
  end

  private def parse : Type
    case ct = current_token
    when Tkn::Name
      case name = ct.name
      when "ptr"
        parse_ptr
      when "struct"
        parse_struct
      when "flat"
        parse_flat
      else
        if t = typer.find_in_caches(name)
          @pos += 1
          t
        else
          raise error("not found type #{name}")
        end
      end
    else
      raise error("expected name got #{ct.inspect}")
    end
  end

  private def parse_ptr : Type
    @pos += 1
    case ct = current_token
    when Tkn::Less
      @pos += 1
    else
      raise error("expected `<` for ptr, got #{ct.inspect}")
    end

    inner_type = parse

    case ct = current_token
    when Tkn::More
      @pos += 1
    else
      raise error("expected `>` for ptr, got #{ct.inspect}")
    end

    id_name = "ptr<#{inner_type.id_name}>"
    if t = typer.find_in_caches(id_name)
      t
    else
      t = Type::PtrType.new(id_name, inner_type)
      t.hidden = true
      typer.types_cache[id_name] = t
      t
    end
  end

  private def parse_flat : Type
    @pos += 1
    case ct = current_token
    when Tkn::Less
      @pos += 1
    else
      raise error("expected `<` for flat, got #{ct.inspect}")
    end

    inner_type = parse

    case ct = current_token
    when Tkn::Comma
      @pos += 1
    else
      raise error("expected `,` for flat, got #{ct.inspect}")
    end

    count = case ct = current_token
            when Tkn::Number
              @pos += 1
              ct.number
            else
              raise error("expected number for flat, got #{ct.inspect}")
            end

    case ct = current_token
    when Tkn::More
      @pos += 1
    else
      raise error("expected `>` for flat, got #{ct.inspect}")
    end

    id_name = "flat<#{inner_type.id_name}, #{count}>"
    if t = @typer.find_in_caches(id_name)
      t
    else
      t = Type::FlatType.new(id_name)
      t.hidden = true
      t.target_type = inner_type
      t.elements_count = count.to_u64
      typer.types_cache[id_name] = t
      t
    end
  end

  private def parse_struct : Type
    @pos += 1
    case ct = current_token
    when Tkn::Less
      @pos += 1
    else
      raise error("expected `<` for struct, got #{ct.inspect}")
    end

    inner_types = [] of Type
    while true
      inner_types << parse

      case ct = current_token
      when Tkn::Comma
        @pos += 1
      when Tkn::More
        break
      else
        raise error("expected `,` or '>' for struct, got #{ct.inspect}")
      end
    end

    case ct = current_token
    when Tkn::More
      @pos += 1
    else
      raise error("expected `>` for struct, got #{ct.inspect}")
    end

    id_name = "struct<#{inner_types.map(&.id_name).join(", ")}>"
    if t = @typer.find_in_caches(id_name)
      t
    else
      t = Type::StructType.new(id_name)
      t.hidden = true
      t.data = inner_types
      typer.types_cache[id_name] = t
      t
    end
  end

  def error(msg)
    Error::ErrorLoc.new(msg, @loc)
  end
end
