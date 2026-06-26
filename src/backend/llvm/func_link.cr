class Myc::Backend::Llvm::FuncLink
  getter name : String
  getter type_fn : Type::Fn
  getter llvm_type : LLVM::Type
  getter llvm_function : LLVM::Function

  def initialize(@name, @type_fn, @llvm_mod : LLVM::Module, type_translator : TypeTranslator)
    llvm_arg_types = @type_fn.args.map { |t| type_translator.translate(t) }
    llvm_ret_type = type_translator.translate(@type_fn.ret)
    @llvm_type = LLVM::Type.function(llvm_arg_types, llvm_ret_type, @type_fn.vaarg)
    @llvm_function = LLVM::Function.new LibLLVM.add_function(llvm_mod, @name, @llvm_type)
    @llvm_function.linkage = LLVM::Linkage::External
  end
end
