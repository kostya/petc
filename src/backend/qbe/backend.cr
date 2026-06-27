class Myc::Backend::QBE::Backend < Myc::Backend::AbstractBackend
  QBE = ENV["QBE"]? || File.join(File.dirname(__FILE__), "..", "..", "..", "plugins", "qbe", "qbe")

  def name
    "QBE"
  end

  def new_builder : AbstractBuilder
    layout = Layout.new(common_options.target || detect_native_target)
    Builder.new(self, layout)
  end

  def obj(mod : Mod, output : String)
    self.class.with_tempfile_path("myc", "ssa") do |tmp|
      build(mod, tmp)

      self.class.with_tempfile_path("myc", "s") do |tmp2|
        Myc.measure("qbe_ams") do
          self.class.run_cmd(QBE, ["-o", tmp2, tmp])
        end
        Myc.measure("asm_obj") do
          self.class.run_cmd(CC, ["-c", tmp2, "-o", output])
        end
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
