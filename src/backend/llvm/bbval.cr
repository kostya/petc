class Myc::Backend::Llvm::BBVal < Myc::Backend::AbstractBBVal
  getter llvm : LLVM::Value

  def initialize(@llvm)
  end

  def inspect
    "llvm(#{@llvm.to_s})"
  end
end
