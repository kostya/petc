class Myc::Backend::C::Backend < Myc::Backend::AbstractBackend
  def name
    "C"
  end

  def self.version
    `#{CC} --version`
  end

  def obj(mod : Mod, output : String)
    self.class.with_tempfile_path("myc", "c") do |tmp|
      Myc.measure("build") do
        build(mod, tmp)
      end
      args = ["-c", "-fno-strict-aliasing", "-Wno-main-return-type", "-Wno-pointer-sign", "-Wno-constant-conversion", "-o", output, tmp]
      args << "-O3" if common_options.release
      if c_flgs = ENV["C_FLAGS"]?
        args += c_flgs.split(" ")
      end
      Myc.measure("c_obj") do
        self.class.run_cmd(CC, args)
      end
    end
  end

  def dump(mod : Mod, output : String)
    Myc.measure("build") do
      build(mod, output)
    end
  end

  private def build(mod : Mod, output : String)
    layout = Layout.new(common_options.target || detect_native_target)
    builder = Builder.new(self, layout, mod.name)

    mod.finalize_enums(layout)

    mod.func_defs.each do |name, func_def|
      builder.func_register(name, func_def.type_fn)
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
