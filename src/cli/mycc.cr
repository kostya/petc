require "../myc"
require "../mycc"
require "../mycc/all"

filename = ARGV[0]?
unless filename
  puts "Usage: mycc INPUT"
  exit(1)
end

begin
  source = Myc::Mycc::Source.new(filename)
  Myc.debug(:myc) { puts "-" * 50; puts source.content }

  Myc.debug(:myc) { puts "-" * 50 }
  tu = source.clang_parse

  Myc.debug(:myc) { puts "-" * 50; source.debug_ast(tu.cursor) }

  Myc.debug(:myc) { puts "-" * 50 }

  builder = Myc::Mycc::ASTBuilder.new(source, tu)
  ast = builder.build
  if ENV["DEBUG"]? == "1"
    p ast
  end

  c = Myc::Mycc::CodeGenerator.new(builder.mod.typer)
  io = c.generate(ast)

  Myc.debug(:myc) { puts "-" * 50 }

  IO.copy(io, STDOUT)
rescue ex : Myc::Mycc::Error
  puts ex.message
  p ex.backtrace
rescue ex : Myc::Error
  ex.print(STDOUT)
  exit(1)
rescue ex
  p ex
  p ex.backtrace
end
