class Myc::Backend::C::Builder < Myc::Backend::AbstractBuilder
  getter name : String
  @type_translator : TypeTranslator?
  getter func_links : Hash(String, Type::Fn)
  getter global_links : Hash(String, Value)

  def initialize(@backend, @layout, @name)
    super(@backend, @layout)
    @func_links = Hash(String, Type::Fn).new
    @global_links = Hash(String, Value).new
    @temp_counter = 0
    @label_counter = 0
    @funcs = Array(Func).new
    @data_forward_io = IO::Memory.new
    @data_io = IO::Memory.new
  end

  def type_translator
    @type_translator ||= TypeTranslator.new(self)
  end

  def new_temp(pref = "t") : String
    @temp_counter += 1
    "#{pref}#{@temp_counter}"
  end

  def new_label(prefix : String) : String
    @label_counter += 1
    "#{prefix}_#{@label_counter}"
  end

  def c_type(type : Type) : String
    type_translator.translate(type)
  end

  def func_register(name : String, type_fn : Type::Fn)
    @data_io << func_head_str(name, type_fn) << "; \n"
    @func_links[name] = type_fn
  end

  def global_register(mod : Mod, global : Mod::GlobalDef)
    g = Value.new(BBVal.new("#{global.name}"), global.type, Value::MM::Ref, global.constant ? Value::PP::GlobalConstant.new(global.name) : Value::PP::Global.new(global.name))
    @global_links[global.name] = g

    init_val = if val = global.initial_value
                 constant_value?(val, global.type).try(&.bbval.as(BBVal).val)
               end

    @data_io << "const " if global.constant
    @data_io << c_type(global.type)
    @data_io << ' '
    @data_io << global.name
    if init_val
      @data_io << " = "
      init_val.to_s(@data_io)
    end
    @data_io << ";\n"
  end

  def constant_value?(value : Source::Token::ArgType, type : Type) : Value?
    val = case value
          when String
            escaped = value
              .gsub("\\", "\\\\")
              .gsub("\"", "\\\"")
              .gsub("\n", "\\n")
            "\"#{escaped}\""
          when Bool
            value ? "1" : "0"
          when Int, Int64
            case type
            when Type::PtrType
              if value == 0
                "NULL"
              else
                return nil
              end
            when Type::StructType, Type::FlatType, Type::EnumType
              if value == 0
                "{0}"
              else
                return nil
              end
            else
              value.to_s
            end
          when Float32, Float64
            value.to_s
          else
            return nil
          end

    Value.new(BBVal.new(val), type, Value::MM::Val, Value::PP::Primitive.new)
  end

  def find_global(name : String) : Value?
    @global_links[name]?
  end

  def save(filename : String)
    inspect_type_fns.each do |name, type_fn|
      func_register(name, type_fn)
    end

    File.open(filename, "w") do |f|
      f << "#include <stdio.h>\n"
      f << "#include <stdlib.h>\n"
      f << "#include <string.h>\n"
      f << "#include <stdint.h>\n"
      f << "#include <inttypes.h>\n\n"

      copy_io(@data_forward_io, f)
      copy_io(@data_io, f)

      @funcs.each do |fb|
        copy_io(fb.body_io, f)
      end
    end
  end

  def new_func(func_def : Mod::FuncDef) : AbstractFunc
    f = Func.new(self, func_def)
    @funcs << f
    f
  end

  def copy_io(from : IO, to : IO)
    from.rewind
    IO.copy(from, to)
  end

  def forward_declare(name)
    @data_forward_io << "typedef struct #{name} #{name};\n"
  end

  def forward_declare_array(name, elem_type, count)
    @data_forward_io << "typedef #{elem_type} #{name}[#{count}];\n"
  end

  def define_struct(name, fields)
    @data_io << "typedef struct #{name} { #{fields} } #{name};\n"
  end

  def define_enum(name, tag_type, payload_str)
    @data_io << "typedef struct #{name} { #{tag_type} field0; #{payload_str} } #{name};\n"
  end

  def define_alias(alias_name, struct_name)
    @data_io << "typedef struct #{struct_name} #{alias_name};\n"
  end

  def func_head_str(name : String, type_fn : Type::Fn) : String
    String.build do |s|
      s << c_type(type_fn.ret)
      s << ' '
      s << name
      s << '('

      type_fn.args.each_with_index do |t, i|
        s << ", " if i != 0
        s << c_type(t)
        s << ' '
        s << "arg"
        s << i
      end

      if type_fn.vaarg
        s << ", ..." unless type_fn.args.empty?
        s << "..." if type_fn.args.empty?
      end
      s << ')'
    end
  end
end
