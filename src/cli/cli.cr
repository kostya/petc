require "../myc"
require "colorize"

class Myc::Cli
  class Data
    enum Mode
      Undefined
      Compile
      Run
      Obj
      Dump
      Beautify
    end

    property mode = Mode::Undefined
    property values = Array(String).new
    property options = Hash(String, String).new
    property unparsed_argv = Array(String).new
    property stdin_filename : String? = nil

    def error(msg)
      Error::Cli.new(msg)
    end
  end

  getter data = Data.new

  private def set_mod(new_mode : Data::Mode)
    if @data.mode.undefined?
      @data.mode = new_mode
    else
      error("mode already defined #{@data.mode}, cant set #{new_mode} option")
    end
  end

  def parse
    unless STDIN.tty?
      content = STDIN.gets_to_end
      path = Backend::AbstractBackend.tempfile_path("stdin", "myc")
      File.open(path, "w") { |f| f.puts content }
      data.values << path
      data.stdin_filename = path
    end

    argv = ARGV.dup

    while true
      case arg = argv.shift?
      when "compile", "c"                    then set_mod(:compile)
      when "run", "r"                        then set_mod(:run)
      when "obj", "o"                        then set_mod(:obj)
      when "dump", "d"                       then set_mod(:dump)
      when "beautify", "b"                   then set_mod(:beautify)
      when "--version", "-v", "version", "v" then show_version
      when "--help", "-h", "help", "h"       then show_usage
      when Nil                               then break
      when "--"
        data.unparsed_argv = argv
        break
      else
        if arg.starts_with?("--")
          if arg.includes?("=")
            left, right = arg.split("=", 1)
            @data.options[left[2..-1]] = right
          else
            arg = arg[2..-1]
            if option_require_argument?(arg)
              if arg2 = argv.shift?
                @data.options[arg] = arg2
              else
                error("value for option #{arg} expected, but not provided")
              end
            else
              @data.options[arg] = ""
            end
          end
        else
          @data.values << arg
        end
      end
    end

    if ENV["MYC_DEBUG_CLI"]? == "1"
      p @data
    end

    if @data.mode.undefined?
      puts usage
      exit(0)
    end
  end

  private def option_require_argument?(arg : String)
    case arg
    when "release", "annotate"
      false
    else
      true
    end
  end

  private def version_string
    "MycCompiler version #{VERSION}-#{COMMIT}#{backend_version}"
  end

  private def show_version
    puts version_string
    exit(0)
  end

  private def show_usage
    puts usage
    exit(0)
  end

  protected def backend_version
    ""
  end

  protected def cli_name
    "myc"
  end

  protected def dump_ext
    ".txt"
  end

  private def usage
    <<-USAGE
Usage: ./#{cli_name} COMMAND [OPTIONS] INPUT [INPUT]* [OUTPUT]

Commands:

  compile|c  ; compile multiple .myc files into executable binary
             ;   ./#{cli_name} c file.myc out
             ;   ./#{cli_name} c --release *.myc out
             ;   cat file.myc | ./#{cli_name} c --release out

  run|r      ; compile multiple .myc files and run the program
             ;   ./#{cli_name} r file.myc
             ;   ./#{cli_name} r --release file.myc
             ;   cat file.myc | ./#{cli_name} r --release

  obj|o      ; compile one .myc file into object file (.o) for linking
             ;   ./#{cli_name} o file.myc file.o
             ;   ./#{cli_name} o --release file.myc file.o
             ;   cat file.myc | ./#{cli_name} o --release file.o

  dump|d     ; output backend IR to console (for debugging and optimization analysis)
             ;   ./#{cli_name} d file.myc
             ;   ./#{cli_name} d --release file.myc
             ;   cat file.myc | ./#{cli_name} d --release

  beautify|b ; format, validate, and add auto-comments to .myc files (--annotate adds stack state comments)
             ;   ./#{cli_name} b .
             ;   ./#{cli_name} b --annotate src/
             ;   ./#{cli_name} b file1.myc file2.myc

  version|v  ; display version information
             ;   ./#{cli_name} version

OPTIONS:
  --release ; compile in performance mode (optimizations enabled)
  --target=TARGET   (TARGET: arm64, x86_64, x86, wasm32, ...; default: native)
USAGE
  end

  protected def error(msg)
    puts usage
    puts "-" * 50
    puts msg.colorize(:red)
    puts "-" * 50
    exit(1)
  end

  def catch_errors(&)
    yield
  rescue ex : Myc::Error::Cli
    error(ex.message)
  rescue ex
    puts "-" * 100
    puts "Uncatched error, please report this AS IS to the issues"
    puts version_string
    p ex.message
    p ex.backtrace
    p data.inspect
    puts "-" * 100
    exit(1)
  ensure
    if filename = data.stdin_filename
      File.delete(filename)
    end
    Myc.print_timers
  end
end
