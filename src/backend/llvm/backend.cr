class Myc::Backend::Llvm::Backend < Myc::Backend::AbstractBackend
  def name
    "LLVM"
  end

  def new_builder : AbstractBuilder
    layout = Layout.new(common_options.target || Target.from_triple(LLVM.default_target_triple))
    Builder.new(self, layout, common_options.release ? LLVM::CodeGenOptLevel::Aggressive : LLVM::CodeGenOptLevel::None)
  end

  def obj(mod : Mod, output : String)
    b = build(mod)

    Myc.measure("llvm_generate_obj") do
      b.generate_obj(output)
    end
  end

  def dump(mod : Mod, output : String)
    b = build(mod)

    Myc.measure("llvm_generate_ll") do
      b.generate_ll(output)
    end
  end

  def build(mod : Mod) : Builder
    build_mod(mod).as(Builder).tap do |builder|
      builder.verify unless ENV["VERIFY"]? == "0"

      if common_options.release || ENV["LLVM_PASSES"]?
        Myc.measure("llvm_optimizer") do
          builder.optimize!("O3")
        end
      end
    end
  end
end
