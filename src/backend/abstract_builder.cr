abstract class Myc::Backend::AbstractBuilder
  getter backend : AbstractBackend
  getter layout : Layout
  getter std_funcs : Hash(String, Type::Fn)
  getter inspect_funcs : Hash(Type, String)
  getter inspect_type_fns : Hash(String, Type::Fn)

  def initialize(@backend, @layout)
    @std_funcs = add_std_funcs
    @inspect_funcs = Hash(Type, String).new
    @inspect_type_fns = Hash(String, Type::Fn).new
  end

  def add_std_funcs
    void = Mod::Typer::STD_TYPES["void"]
    i32 = Mod::Typer::STD_TYPES["i32"]
    i64 = Mod::Typer::STD_TYPES["i64"]
    u64 = Mod::Typer::STD_TYPES["u64"]
    f64 = Mod::Typer::STD_TYPES["f64"]
    u8p = Mod::Typer::STD_TYPES["ptr<u8>"]
    voidp = Mod::Typer::STD_TYPES["ptr<void>"]

    h = Hash(String, Type::Fn).new

    h["printf"] = Type::Fn.new([u8p], i32, vaarg: true)
    h["fprintf"] = Type::Fn.new([voidp, u8p], i32, vaarg: true)
    h["sprintf"] = Type::Fn.new([u8p, u8p], i32, vaarg: true)

    h["malloc"] = Type::Fn.new([u64], voidp)
    h["calloc"] = Type::Fn.new([u64, u64], voidp)
    h["realloc"] = Type::Fn.new([voidp, u64], voidp)
    h["strncmp"] = Type::Fn.new([u8p, u8p, u64], i32)
    h["memcpy"] = Type::Fn.new([voidp, voidp, u64], voidp)
    h["memset"] = Type::Fn.new([voidp, i32, u64], voidp)
    h["memcmp"] = Type::Fn.new([voidp, voidp, u64], i32)
    h["free"] = Type::Fn.new([voidp], void)
    h["strlen"] = Type::Fn.new([u8p], u64)
    h["strcmp"] = Type::Fn.new([u8p, u8p], i32)
    h["strcpy"] = Type::Fn.new([u8p, u8p], u8p)
    h["rand"] = Type::Fn.new([] of Type, i32)
    h["exit"] = Type::Fn.new([i32], void)
    h["abort"] = Type::Fn.new([] of Type, void)
    h["fflush"] = Type::Fn.new([voidp], i32)
    h["putchar"] = Type::Fn.new([i32], i32)
    h["getchar"] = Type::Fn.new([] of Type, i32)
    h["puts"] = Type::Fn.new([u8p], i32)
    h["atoi"] = Type::Fn.new([u8p], i32)
    h["atof"] = Type::Fn.new([u8p], f64)
    h["abs"] = Type::Fn.new([i32], i32)

    h
  end

  abstract def constant_value?(value : Source::Token::ArgType, type : Type) : Value?
  abstract def find_global(name : String) : Value?
  abstract def new_func(func_def : Mod::FuncDef) : AbstractFunc
  abstract def func_register(name : String, type_fn : Type::Fn)

  protected def escaped_string(s : String)
    s.gsub("\\", "\\\\").gsub("\"", "\\\"").gsub("\n", "\\n")
  end
end
