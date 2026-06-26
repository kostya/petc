abstract class Myc::Backend::AbstractBackend
  record CommonOptions, target : Target?, release : Bool

  abstract def name
  abstract def dump(mod : Mod, output : String)
  abstract def obj(mod : Mod, output : String)

  CC = ENV["CC"]? || "cc"

  getter data : Cli::Data
  getter common_options : CommonOptions

  def initialize(@data)
    @common_options = parse_common_options
  end

  def run
    case data.mode
    in .compile?
      target = _compile(target_for_compile)
      puts "compiled to #{target}"
    in .run?       then _run
    in .obj?       then _obj
    in .dump?      then _dump
    in .beautify?  then _beautify
    in .undefined? then raise data.error("unknown mode #{data.mode}")
    end
  rescue ex : Error
    show_error(ex)
    exit(1)
  end

  protected def run_obj(input : String, output : String)
    ensure_dir(output)
    obj(validate(input), output)
  end

  protected def run_dump(input : String, output : String)
    ensure_dir(output)
    dump(validate(input), output)
  end

  protected def target_for_compile
    if data.values.size == 0
      raise data.error("nothing to compile")
    end

    last = data.values.last
    if last.ends_with?(EXT) || last.ends_with?(".o")
      if (data.values.size == 1) && data.stdin_filename.nil?
        return File.basename(data.values.first, EXT)
      else
        return "a.out"
      end
    end

    data.values.last
  end

  protected def _compile(target : String)
    files = [] of String
    objs = [] of String
    data.values.each do |file|
      if file.ends_with?(EXT)
        files << file
      elsif file.ends_with?(".o")
        objs << file
      elsif file == target
      else
        raise data.error("unexpected file to compile #{file}")
      end
    end

    files.each do |file|
      obj_file = object_for(file)

      run_obj(file, obj_file)
      objs << obj_file
    end

    raise data.error("nothing to compile") if files.empty? && objs.empty?

    linker(objs, target)
    target
  end

  protected def _run
    self.class.with_tempfile_path("myc", "run") do |output|
      _compile(output)
      self.class.run_cmd(output, data.unparsed_argv, check_status: false, catch_stdout: ENV["MYC_SPEC"]? == "1")
    end
  end

  protected def _obj
    input, output = if data.values.size == 1
                      {data.values[0], object_for(data.values[0])}
                    elsif data.values.size == 2
                      {data.values[0], data.values[1]}
                    else
                      raise data.error("obj require 2 files input and output")
                    end

    run_obj(input, output)
    puts "generated #{output}"
  end

  protected def _dump
    if data.values.size == 1
      input = data.values.first
      self.class.with_tempfile_path("myc", "dump") do |output|
        run_dump(input, output)
        puts File.read(output)
      end
    elsif data.values.size == 2
      input = data.values[0]
      output = data.values[1]
      run_dump(input, output)
      puts "dump generated to #{output}"
    else
      raise data.error("dump require 1 or 2 files input [and output]")
    end
  end

  protected def _beautify
    files = data.values.flat_map do |path|
      if File.directory?(path)
        Dir.glob("#{path}/**/*#{EXT}")
      elsif File.file?(path)
        [path]
      else
        [] of String
      end
    end

    files.each do |input|
      begin
        print "beautify #{input} "
        mod = validate(input)
        notes = Hash(Opcode, String).new
        if data.options["annotate"]?
          linter = Linter::Backend.new(data)
          linter.lint(mod)
          notes = linter.notes
        end
        s = Mod::Saver.new(mod, notes)
        dom = s.save
        File.open(input, "w") { |f| Myc::Source::Serialize.new(dom, f).serialize }
        puts "ok!".colorize(:green)
      rescue ex : Error
        puts "error! (#{ex.message})".colorize(:red)
      end
    end
  end

  protected def validate(input : String) : Mod
    raise data.error("input not found `#{input}`") unless File.exists?(input)
    raise data.error("input not file `#{input}`") unless File.file?(input)
    Myc.measure("load_mod") do
      src = File.read(input)
      src = preprocess(src, input)
      tokens = Source::Tokenizer.new(src, input).parse
      parser = Source::Parser.new(input, tokens)
      parser.parse
      dom = parser.dom
      l = Mod::Loader.new(dom, input)
      l.load
      l.mod.validate!
      l.mod
    end
  end

  protected def linker(objs : Array(String), output : String)
    ensure_dir(output)
    Myc.measure("linker") do
      self.class.run_cmd(CC, objs + ["-o", output])
    end
  end

  protected def show_error(error : Error)
    error.print(STDOUT)
  end

  protected def object_for(input, ext = "o")
    base_name = File.basename(input, EXT)
    output = Path[input].parent / "#{base_name}.#{ext}"
    output.to_s
  end

  protected def ensure_dir(file)
    Dir.mkdir_p(File.dirname(file))
  end

  def self.tempfile_path(prefix = "", ext = "")
    bytes = Bytes.new(10)
    Random::Secure.random_bytes(bytes)
    File.join(Dir.tempdir, "#{prefix}_#{bytes.hexstring}.#{ext}")
  end

  def self.with_tempfile_path(prefix, ext, &)
    path = tempfile_path(prefix, ext)
    yield path
  ensure
    if path && ENV["MYC_VERBOSE"]? != "1"
      File.delete(path) rescue nil
    end
  end

  def self.run_cmd(cmd : String, args : Array(String), check_status = true, catch_stdout = false) : String?
    if ENV["MYC_VERBOSE"]? == "1"
      puts "--- '#{cmd} #{args.join(" ")}' ---"
    end

    res = if catch_stdout
            io = IO::Memory.new
            Process.run(cmd,
              args: args,
              input: Process::Redirect::Inherit,
              output: io,
              error: Process::Redirect::Inherit)
            io.to_s
          else
            Process.run(cmd,
              args: args,
              input: Process::Redirect::Inherit,
              output: Process::Redirect::Inherit,
              error: Process::Redirect::Inherit)
            nil
          end

    if check_status && ($?.exit_code != 0)
      raise Error::Cmd.new("Command `#{cmd}` failed with status #{$?.exit_code}", cmd, args)
    end

    res
  rescue ex
    raise Error::Cmd.new(ex.message, cmd, args)
  end

  private def preprocess(str : String, filename : String) : String
    str.gsub(/{{(.*?)}}/) { File.read(File.join(File.dirname(filename), $1.to_s)) }
  end

  private def parse_common_options : CommonOptions
    target = if target_str = data.options.delete("target")
               Target.from_triple(target_str)
             end

    release = !!data.options.delete("release")
    CommonOptions.new(target: target, release: release)
  end

  protected def detect_native_target : Target
    arch = {% if flag?(:arm64) || flag?(:aarch64) %}
             Target::Arch::Arm64
           {% elsif flag?(:x86_64) || flag?(:amd64) %}
             Target::Arch::X86_64
           {% elsif flag?(:i386) %}
             Target::Arch::X86
           {% else %}
             Target::Arch::Unknown
           {% end %}
    Target.new(arch)
  end

  def debug_flags : String
    String.build do |s|
      s << '('
      s << (common_options.release ? "release" : "debug")
      if target = common_options.target
        s << ", "
        s << target.arch.to_s
      end
      s << ')'
    end
  end
end
