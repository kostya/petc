class Myc::Backend::Linter::Backend < Myc::Backend::AbstractBackend
  def name
    "Linter"
  end

  def obj(mod : Mod, output : String)
    raise "not used"
  end

  def dump(mod : Mod, output : String)
    raise "not used"
  end

  property notes = Hash(Opcode, String).new

  def lint(mod : Mod)
    Stats.measure(:linter) do
      layout = Layout.new(detect_native_target)
      builder = Builder.new(self, layout)

      mod.finalize_enums(layout)

      mod.global_defs.each do |global|
        builder.global_register(mod, global)
      end

      mod.func_defs.each do |_, func_def|
        if func_def.body
          f = builder.new_func(func_def)
          notes.merge!(f.build)
        end
      end
    end
  end
end
