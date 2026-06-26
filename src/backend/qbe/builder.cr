class Myc::Backend::QBE::Builder < Myc::Backend::AbstractBuilder
  getter name : String
  getter func_links : Hash(String, Type::Fn)
  getter global_links : Hash(String, Value)
  getter string_constants : Hash(String, String)
  getter data_io : IO::Memory
  @type_translator : TypeTranslator?

  def initialize(@backend, @layout, @name)
    super(@backend, @layout)

    @data_io = IO::Memory.new
    @str_counter = 0
    @label_counter = 0
    @string_constants = Hash(String, String).new
    @func_links = Hash(String, Type::Fn).new
    @global_links = Hash(String, Value).new
    @funcs = Array(Func).new
  end

  def type_translator
    @type_translator ||= TypeTranslator.new(self)
  end

  def func_register(name : String, type_fn : Type::Fn) : Type::Fn
    @func_links[name] = type_fn
  end

  def global_register(mod : Mod, global : Mod::GlobalDef)
    g = Value.new(BBVal.new("$#{global.name}"), global.type, Value::MM::Ref, global.constant ? Value::PP::GlobalConstant.new(global.name) : Value::PP::Global.new(global.name))
    @global_links[global.name] = g

    if global.type.needs_blit?
      fields = flatten_data_fields(global.type).join(", ")
      @data_io << "data $#{global.name} = { #{fields} }\n"
    else
      init_val = if val = global.initial_value
                   constant_value?(val, global.type).try(&.bbval.as(BBVal).val) || 0
                 else
                   0
                 end
      @data_io << "data $#{global.name} = { #{qbe_type(global.type)} #{init_val} }\n"
    end
  end

  def constant_value?(value : Source::Token::ArgType, type : Type) : Value?
    if val = case value
             when Int
               case type
               when Type::PtrType
                 if value == 0
                   "0"
                 end
               else
                 value.to_s
               end
             when Bool
               value ? "1" : "0"
             when Float32, Float64
               case type
               when Type::FloatType
                 if type.bytes_count == 4
                   sprintf("s_%a", value.to_f32)
                 else
                   sprintf("d_%a", value.to_f64)
                 end
               end
             when String
               string_constant(value)
             end
      Value.new(BBVal.new(val), type, Value::MM::Val, Value::PP::Primitive.new)
    end
  end

  def find_global(name : String) : Value?
    @global_links[name]?
  end

  def emit_type(str : String)
    @data_io << str
  end

  def qbe_type(type : Type) : String
    type_translator.translate(type)
  end

  def string_constant(str : String) : String
    @string_constants.put_if_absent(str) do
      name = "str_#{@str_counter}"
      @str_counter += 1
      escaped = str
        .gsub("\\", "\\\\") # \ → \\
        .gsub("\"", "\\\"")
        .gsub("\n", "\\n")
      @data_io << "data $#{name} = { b \"#{escaped}\", b 0 }\n"
      "$#{name}"
    end
  end

  def new_label(prefix : String) : String
    @label_counter += 1
    "#{prefix}_#{@label_counter}"
  end

  def copy_io(from : IO, to : IO)
    from.rewind
    IO.copy(from, to)
  end

  def new_func(func_def : Mod::FuncDef) : AbstractFunc
    f = Func.new(self, func_def)
    @funcs << f
    f
  end

  def save(filename : String)
    File.open(filename, "w") do |f|
      copy_io(@data_io, f)

      @funcs.each do |fb|
        copy_io(fb.body_io, f)
      end
    end
  end

  private def flatten_data_fields(type : Type) : Array(String)
    case type
    when Type::StructType
      type.data.flat_map { |t| flatten_data_fields(t) }
    when Type::FlatType
      type.elements_count.times.to_a.flat_map { flatten_data_fields(type.target_type) }
    when Type::EnumType
      fields = flatten_data_fields(type.index_type)
      payload_count = @layout.enum_payload_count(type)
      if payload_count > 0
        fields + payload_count.times.to_a.map { "w 0" }
      else
        fields
      end
    when Type::IntType
      ["#{qbe_type(type)} 0"]
    when Type::FloatType
      ["#{qbe_type(type)} 0"]
    when Type::BoolType
      ["w 0"]
    when Type::PtrType, Type::Fn
      ["l 0"]
    else
      raise "unexpected type in global data: #{type.class}"
    end
  end
end
