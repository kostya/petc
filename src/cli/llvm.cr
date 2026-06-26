require "./cli"
require "../backend/llvm/all"

class Myc::Cli::Llvm < Myc::Cli
  private def backend_version
    ", LLVM backend version: `#{LibLLVM::VERSION}`"
  end

  def cli_name
    "myc-llvm"
  end

  def dump_ext
    ".ll"
  end
end

cli = Myc::Cli::Llvm.new
cli.parse
backend = Myc::Backend::Llvm::Backend.new(cli.data)
cli.catch_errors do
  backend.run
end
