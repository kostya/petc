require "./cli"
require "../backend/qbe/all"

class Myc::Cli::QBE < Myc::Cli
  private def backend_version
    ", QBE backend version: `master 8ff06515526c97628b47d8223b73d5376287a9b4`"
  end

  def cli_name
    "myc-qbe"
  end

  def dump_ext
    ".ssa"
  end
end

cli = Myc::Cli::QBE.new
cli.parse
backend = Myc::Backend::QBE::Backend.new(cli.data)
cli.catch_errors do
  backend.run
end
