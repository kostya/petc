require "spec"
require "../src/myc"

ENV["MYC_SPEC"] = "1"

class Myc::Backend::AbstractBackend
  def spec_run
    _run
  end
end

def tokenize(src)
  Myc::Source::Tokenizer.new(src, "/tmp/1").parse
end

def parse(src)
  tokens = Myc::Source::Tokenizer.new(src, "/tmp/1").parse
  parser = Myc::Source::Parser.new("/tmp/1", tokens)
  parser.parse

  dom = parser.dom

  String.build { |s| Myc::Source::Serialize.new(dom, s).serialize }.strip
end

def validate(src)
  tokens = Myc::Source::Tokenizer.new(src, "/tmp/1").parse
  parser = Myc::Source::Parser.new("/tmp/1", tokens)
  parser.parse

  dom = parser.dom

  l = Myc::Mod::Loader.new(dom, "/tmp/1")
  l.mod.validate!
  l.load

  s = Myc::Mod::Saver.new(l.mod)
  dom2 = s.save

  String.build { |s| Myc::Source::Serialize.new(dom2, s).serialize }.strip
end

def typer
  mod = Myc::Mod.new("1", "/tmp/1")
  mod.typer
end

def spec_find_type(name : String) : Myc::Type
  typer.find(name, Myc::Location.new("/tmp/1", 0))
end

abstract struct Myc::Source::Token
  def inspect(io)
    case t = self
    when Opcode
      io << "O:#{t.code.to_s}:#{offset}"
    when Arg
      io << "V:#{t.v.inspect}:#{offset}"
    when OpcodeUnknown
      io << "OU:#{t.name}:#{offset}"
    else
      raise "unexpected #{t.class}"
    end
  end
end

Spec.after_suite do
  Myc::Stats.print_timers
end

class SpecRun
  def self.all(path = __FILE__)
    dir = File.dirname(path)
    category = File.basename(dir)

    src_files = Dir.glob(File.join(dir, "*.myc")).sort
    src_err_files = Dir.glob(File.join(dir, "*.err.myc")).sort
    all_test_files = (src_files + src_err_files).uniq.sort

    all_backends = get_all_backends
    all_backends.each do |backend_end|
      get_all_release_modes.each do |release|
        backend_class = get_backend(backend_end) rescue nil
        next unless backend_class

        all_test_files.each do |test_file|
          basename = File.basename(test_file)
          name = File.basename(test_file, ".err.myc")
          name = File.basename(name, ".myc")
          is_error_test = test_file.ends_with?(".err.myc")

          expected_file = File.join(File.dirname(test_file), "#{name}.txt")

          relative_path = "spec" + test_file.sub(File.dirname(__FILE__), "")
          if basename.starts_with?("p-")
            pending("[#{backend_end}#{" --release" if release}] #{relative_path}")
            next
          end

          unless File.exists?(expected_file)
            puts "No expected file for #{expected_file}"
            next
          end

          test_name = "[#{backend_end}#{" --release" if release}] [#{relative_path}] (crystal src/cli/#{backend_end.downcase}.cr #{relative_path} d)"

          it(test_name, path, 0) do
            p relative_path if ENV["FILENAME"]? == "1"
            expected = File.read(expected_file).strip

            if is_error_test
              ex = expect_raises(Myc::Error, "") do
                run(test_file, backend_class, release)
              end
              s = String.build { |io| ex.print(io) }
              s.gsub(/\e\[[\d;]*m/, "").should contain(expected)
            else
              result = run(test_file, backend_class, release)

              if result != expected
                puts ""
                puts "─" * 60
                puts "Output for #{basename} (#{backend_end}#{" --release" if release}):"
                puts "─" * 60
                puts File.read(test_file)

                puts "─" * 10 + " expected " + "─" * 60
                puts expected
                puts "─" * 10 + " got " + "─" * 65
                puts result
                puts "─" * 80
                puts
                puts
              end

              result.should eq(expected)
            end
          end
        end
      end
    end
  end

  def self.get_all_backends
    all = %w{LLVM C QBE}

    if ENV["SPEC_LLVM"]? == "1"
      return %w{LLVM}
    end

    if ENV["SPEC_C"]? == "1"
      return %w{C}
    end

    if ENV["SPEC_QBE"]? == "1"
      return %w{QBE}
    end

    all
  end

  def self.get_all_release_modes
    if ENV["RELEASE"]? == "1"
      return [true]
    end

    if ENV["DEBUG"]? == "1"
      return [false]
    end

    [false, true]
  end

  def self.get_backend(name) : Myc::Backend::AbstractBackend.class | Nil
    case name
    when "LLVM"
      Myc::Backend::Llvm::Backend
    when "C"
      Myc::Backend::C::Backend
    when "QBE"
      Myc::Backend::QBE::Backend
    end
  end

  def self.run(filename, backend_class : Myc::Backend::AbstractBackend.class, release)
    data = Myc::Cli::Data.new
    data.mode = :run
    data.values << filename

    if release
      data.options["release"] = ""
    end

    backend = backend_class.new(data)
    backend.spec_run.try &.strip
  end
end

require "../src/backend/llvm/all"
require "../src/backend/qbe/all"
require "../src/backend/c/all"
