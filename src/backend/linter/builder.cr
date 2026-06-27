class Myc::Backend::Linter::Builder < Myc::Backend::AbstractBuilder
  @global_links = Hash(String, Value).new
  property notes = Hash(Opcode, String).new

  def global_register(mod : Mod, global : Mod::GlobalDef)
    @global_links[global.name] = Value.new(BB::FAKE_VAL, global.type, Value::MM::Ref, global.constant ? Value::PP::GlobalConstant.new(global.name) : Value::PP::Global.new(global.name))
  end

  def constant_value?(value : Source::Token::ArgType, type : Type) : Value?
    case value
    when Int
      if value == 0
        Value.new(BB::FAKE_VAL, type, Value::MM::Val, Value::PP::Primitive.new)
      else
        case type
        when Type::PtrType, Type::StructType, Type::FlatType, Type::EnumType
          nil
        else
          Value.new(BB::FAKE_VAL, type, Value::MM::Val, Value::PP::Primitive.new)
        end
      end
    else
      Value.new(BB::FAKE_VAL, type, Value::MM::Val, Value::PP::Primitive.new)
    end
  end

  def func_register(name : String, type_fn : Type::Fn)
  end

  def find_global(name : String) : Value?
    @global_links[name]?
  end

  def new_func(func_def : Mod::FuncDef) : AbstractFunc
    Func.new(self, func_def)
  end
end
