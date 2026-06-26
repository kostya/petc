require "./cli"

class Myc::Cli::Test < Myc::Cli
  private def backend_version
    ", Test backend"
  end

  def cli_name
    "myc-test"
  end

  def dump_ext
    ".txt"
  end
end

class Myc::Backend::Test < Myc::Backend::AbstractBackend
  def name
    "Test"
  end

  def obj(mod : Myc::Mod, output : String)
    puts "skip obj #{output}"
  end

  def dump(mod : Myc::Mod, output : String)
    puts "skip dump #{output}"
  end
end

cli = Myc::Cli::Test.new
cli.parse
backend = Myc::Backend::Test.new(cli.data)
cli.catch_errors do
  backend.run
end
