require "llvm"

if LibLLVM::VERSION < "15.0.0"
  puts "ERROR: myc-llvm require LLVM >= 15, but current is #{LibLLVM::VERSION}, make sure that `llvm-config --version` >= 15, or provide correct path to llvm-config by LLVM_CONFIG env variable"
  exit 1
end

require "./*"
