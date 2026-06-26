class Myc::Mod
  getter name : String
  getter filename : String

  getter type_defs = Hash(String, TypeDef).new
  getter global_defs = Array(GlobalDef).new
  getter func_defs = Hash(String, FuncDef).new

  def initialize(@name, @filename)
    @name = @name.gsub(/[^a-zA-Z0-9_]/, "_")
  end

  @typer : Typer?

  def typer
    @typer ||= Typer.new(self)
  end

  def validate!
    Validate.new(self).validate!
  end

  def finalize_enums(layout : Backend::Layout)
    @type_defs.each do |_, type_def|
      case type = type_def.type
      when Type::EnumType
        type.generate_payload_type(self, layout)
      end
    end
  end
end

require "./mod/*"
