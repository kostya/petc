class Myc::Backend::QBE::BBVal < Myc::Backend::AbstractBBVal
  getter val : String

  def initialize(@val)
  end

  def to_s
    "qbeval(#{@val})"
  end
end
