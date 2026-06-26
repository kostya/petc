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
  builder = Myc::Mycc::Builder.new(source, tu)
  builder.visit(tu.cursor)

  Myc.debug(:myc) { puts "-" * 50 }
  builder.save(STDOUT)
rescue ex : Myc::Mycc::Error
  puts ex.message
  p ex.backtrace
rescue ex
  p ex
end
