class Myc::Backend::Llvm::Builder < Myc::Backend::AbstractBuilder
  getter name : String
  getter context : LLVM::Context
  getter target_machine : LLVM::TargetMachine
  getter type_translator : TypeTranslator
  getter llvm_mod : LLVM::Module

  getter string_constants = Hash(String, LLVM::Value).new
  getter func_links = Hash(String, FuncLink).new
  getter global_links = Hash(String, Value).new
  getter codegen_opt_level : LLVM::CodeGenOptLevel

  def initialize(@backend, @layout, @name, @codegen_opt_level = LLVM::CodeGenOptLevel::None)
    super(@backend, @layout)

    @context = LLVM::Context.new(LibLLVM.create_context, false)
    @target_machine = create_target_machine(@layout.target.triple)
    @type_translator = TypeTranslator.new(@context, @layout)

    @llvm_mod = @context.new_module(name)
    @llvm_mod.target = @target_machine.triple
    @llvm_mod.data_layout = @target_machine.data_layout
  end

  private def create_target_machine(triple : String)
    case triple
    when /arm64|aarch64/i then LLVM.init_aarch64
    when /arm/i           then LLVM.init_arm
    when /wasm/i          then LLVM.init_webassembly
    when /avr/i           then LLVM.init_avr
    else                       LLVM.init_x86
    end

    llvm_target = LLVM::Target.from_triple(triple)
    machine = llvm_target.create_target_machine(triple,
      cpu: "",
      features: "",
      opt_level: @codegen_opt_level,
      code_model: LLVM::CodeModel::Default,
      reloc: LLVM::RelocMode::PIC).not_nil!
    machine.enable_global_isel = false
    machine
  end

  def llvm_type(type : Type) : LLVM::Type
    type_translator.translate(type)
  end

  def verify
    Stats.measure(:verify) do
      @llvm_mod.verify
    end
  end

  def func_link(name : String, type_fn : Type::Fn) : FuncLink
    @func_links.put_if_absent(name) { FuncLink.new(name, type_fn, @llvm_mod, @type_translator) }
  end

  def global_register(mod : Mod, global : Mod::GlobalDef)
    llvm_type = llvm_type(global.type)
    var = llvm_mod.globals.add(llvm_type, global.name)

    if initial_value = global.initial_value
      if val = _constant_value?(initial_value, global.type)
        var.initializer = val
      else
        raise global.node.error("cant translate constant #{initial_value.inspect}", mod.filename)
      end
      var.linkage = LLVM::Linkage::Internal
    else
      var.initializer = llvm_type.undef
      var.linkage = LLVM::Linkage::External
    end

    var.global_constant = global.constant

    if global_links[global.name]?
      raise global.node.error("Already defined global #{global.name}: #{global.type}", mod.filename)
    end
    g = Value.new(BBVal.new(var), global.type, Value::MM::Ref, global.constant ? Value::PP::GlobalConstant.new(global.name) : Value::PP::Global.new(global.name))
    global_links[global.name] = g
  end

  def _constant_value?(value : Source::Token::ArgType, type : Type) : LLVM::Value?
    case type
    when Type::IntType
      case value
      when Int
        llvm_type(type).const_int(value)
      end
    when Type::BoolType
      case value
      when Bool
        llvm_type(type).const_int(value ? 1 : 0)
      end
    when Type::FloatType
      case value
      when Float32 then llvm_type(type).const_float(value)
      when Float64 then llvm_type(type).const_double(value)
      when Int     then llvm_type(type).const_double(value.to_f64)
      end
    when Type::StructType, Type::FlatType, Type::EnumType
      case value
      when Int
        if value == 0
          llvm_type(type).null
        end
      end
    when Type::PtrType
      case value
      when String then string_constant(value)
      when Int
        llvm_type(type).null if value == 0
      end
    end
  end

  def string_constant(str : String) : LLVM::Value
    string_constants.put_if_absent(str) { make_global_string(str) }
  end

  private def make_global_string(str)
    name = "str"
    context = llvm_mod.context
    str_const = context.const_string(str)
    str_type = str_const.type
    global = llvm_mod.globals.add(str_type, name)
    global.linkage = LLVM::Linkage::Private
    global.global_constant = true
    global.initializer = str_const
    global
  end

  def generate_ll(filename)
    Stats.measure(:llvm_generate_ll) do
      Stats.debug(:compile) { "Generate LL #{filename}" }
      File.open(filename, "w") { |file| llvm_mod.to_s(file) }
    end
  rescue ex
    puts "GenerateLL failed with #{ex.inspect}"
  end

  def generate_obj(filename)
    Stats.measure(:llvm_generate_obj) do
      Stats.debug(:compile) { "Generate Obj #{filename}" }
      target_machine.emit_obj_to_file llvm_mod, filename
    end
  rescue ex
    puts "GenerateObj failed with #{ex.inspect}"
  end

  def optimize!(mode = "O2")
    Stats.measure(:llvm_generate_obj) do
      LLVM::PassBuilderOptions.new do |options|
        LLVM.run_passes(llvm_mod, ENV["LLVM_PASSES"]? || "default<#{mode}>", target_machine, options)
      end
    end
  end

  def constant_value?(value : Source::Token::ArgType, type : Type) : Value?
    if llvm_val = _constant_value?(value, type)
      Value.new(BBVal.new(llvm_val), type, Value::MM::Val, Value::PP::Primitive.new)
    end
  end

  def find_global(name : String) : Value?
    global_links[name]?
  end

  def new_func(func_def : Mod::FuncDef) : AbstractFunc
    Func.new(self, func_def)
  end
end
