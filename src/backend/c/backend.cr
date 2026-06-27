class Myc::Backend::C::Backend < Myc::Backend::AbstractBackend
  def name
    "C"
  end

  def self.version
    `#{CC} --version`
  end

  def new_builder : AbstractBuilder
    layout = Layout.new(common_options.target || detect_native_target)
    Builder.new(self, layout)
  end

  def obj(mod : Mod, output : String)
    self.class.with_tempfile_path("myc", "c") do |tmp|
      build(mod, tmp)
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
    build(mod, output)
  end

  def build(mod : Mod, output : String) : Builder
    build_mod(mod).as(Builder).tap do |builder|
      builder.save(output)
    end
  end
end
