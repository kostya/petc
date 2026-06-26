class Myc::Backend::QBE::Backend < Myc::Backend::AbstractBackend
  QBE = ENV["QBE"]? || File.join(File.dirname(__FILE__), "..", "..", "..", "plugins", "qbe", "qbe")

  def name
    "QBE"
  end

  def obj(mod : Mod, output : String)
    self.class.with_tempfile_path("myc", "ssa") do |tmp|
      Stats.measure("build") do
        build(mod, tmp)
      end

      self.class.with_tempfile_path("myc", "s") do |tmp2|
        Stats.measure("qbe_ams") do
          self.class.run_cmd(QBE, ["-o", tmp2, tmp])
        end
        Stats.measure("asm_obj") do
          self.class.run_cmd(CC, ["-c", tmp2, "-o", output])
        end
      end
    end
  end

  def dump(mod : Mod, output : String)
    Stats.measure("build") do
      build(mod, output)
    end
  end

  private def build(mod : Mod, output : String)
    layout = Layout.new(common_options.target || detect_native_target)
    builder = Builder.new(self, layout, mod.name)

    mod.finalize_enums(layout)

    mod.func_defs.each do |name, func_def|
      unless func_def.body
        builder.func_register(name, func_def.type_fn)
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

    builder.save(output)
  end
end
