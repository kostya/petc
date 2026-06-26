require "./cli"
require "../backend/c/all"

class Myc::Cli::C < Myc::Cli
  private def backend_version
    ", C backend, `#{Backend::C::Backend::CC}` version: `#{Backend::C::Backend.version}`"
  end

  def cli_name
    "myc-c"
  end

  def dump_ext
    ".c"
  end
end

cli = Myc::Cli::C.new
cli.parse
backend = Myc::Backend::C::Backend.new(cli.data)
cli.catch_errors do
  backend.run
end
