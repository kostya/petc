class Myc::Mod::Typer
  STD_TYPES = begin
    h = Hash(String, Type).new

    h["void"] = Type::VoidType.new("void")
    h["bool"] = Type::BoolType.new("bool")

    h["i8"] = Type::IntType.new("i8", 1, true)
    h["u8"] = Type::IntType.new("u8", 1, false)
    h["i16"] = Type::IntType.new("i16", 2, true)
    h["u16"] = Type::IntType.new("u16", 2, false)
    h["i32"] = Type::IntType.new("i32", 4, true)
    h["u32"] = Type::IntType.new("u32", 4, false)
    h["i64"] = Type::IntType.new("i64", 8, true)
    h["u64"] = Type::IntType.new("u64", 8, false)

    h["f32"] = Type::FloatType.new("f32", 4)
    h["f64"] = Type::FloatType.new("f64", 8)

    h.each do |name, type|
      h["ptr<#{name}>"] = Type::PtrType.new("ptr<#{name}>", type)
    end

    h.rehash
    h
  end

  getter mod : Mod
  getter types_cache : Hash(String, Type)

  def initialize(@mod : Mod)
    @types_cache = Hash(String, Type).new
    @unique_id = 0_u64
  end

  {% for tp in %w{i32 u32 i64 u64 i16 u16 i8 u8 f64 f32 bool void} %}
    def {{tp.id}} : Type
      STD_TYPES[{{tp}}]
    end

    def {{tp.id}}p : Type
      STD_TYPES["ptr<{{tp.id}}>"]
	  end
  {% end %}

  def find_in_caches(name : String) : Type?
    if tp = @types_cache[name]?
      return tp
    end

    if tp = STD_TYPES[name]?
      @types_cache[name] = tp
      return tp
    end

    if tp = @mod.type_defs[name]?
      @types_cache[name] = tp.type
      return tp.type
    end
  end

  def find(id_name : String, loc : Location) : Type
    find_in_caches(id_name) || Parser.new(id_name, self, loc).get_type
  end

  def std_value_type?(v) : Type?
    case v
    when UInt64  then u64
    when Int64   then i64
    when UInt32  then u32
    when Int32   then i32
    when Int16   then i16
    when UInt16  then u16
    when Int8    then i8
    when UInt8   then u8
    when Bool    then bool
    when String  then u8p
    when Float32 then f32
    when Float64 then f64
    end
  end

  def to_ptr(type : Type, offset : UInt32 = 0) : Type
    find("ptr<#{type.id_name}>", Location.new(mod.filename, offset))
  end
end

require "./typer/*"
