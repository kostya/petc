class Myc::Backend::Llvm::Backend < Myc::Backend::AbstractBackend
  def name
    "LLVM"
  end

  def obj(mod : Mod, output : String)
    b = build(mod, output)

    if common_options.release || ENV["LLVM_PASSES"]?
      Stats.measure("llvm_optimizer") do
        b.optimize!("O3")
      end
    end

    Stats.measure("llvm_generate_obj") do
      b.generate_obj(output)
    end
  end

  def dump(mod : Mod, output : String)
    b = build(mod, output)

    if common_options.release || ENV["LLVM_PASSES"]?
      Stats.measure("llvm_optimizer") do
        b.optimize!("O3")
      end
    end

    Stats.measure("llvm_generate_ll") do
      b.generate_ll(output)
    end
  end

  private def build(mod : Mod, output : String) : Builder
    Stats.measure("build") do
      layout = Layout.new(common_options.target || Target.from_triple(LLVM.default_target_triple))
      builder = Builder.new(self, layout, mod.name, common_options.release ? LLVM::CodeGenOptLevel::Aggressive : LLVM::CodeGenOptLevel::None)

      mod.finalize_enums(layout)

      mod.func_defs.each do |name, func_def|
        unless func_def.body
          builder.func_link(name, func_def.type_fn)
        end
      end

      mod.global_defs.each do |global|
        builder.global_register(mod, global)
      end

      mod.func_defs.each do |_, func_def|
        if func_def.body
          builder.new_func(func_def).build
        end
      end

      builder.verify unless ENV["VERIFY"]? == "0"
      builder
    end
  end
end
