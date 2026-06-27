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

  def new_builder : AbstractBuilder
    Builder.new(self, Layout.new(detect_native_target))
  end
end
