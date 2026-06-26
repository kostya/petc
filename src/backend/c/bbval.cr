class Myc::Backend::C::BBVal < Myc::Backend::AbstractBBVal
  getter val : String

  def initialize(@val)
  end

  def inspect
    "cval(#{@val})"
  end
end
