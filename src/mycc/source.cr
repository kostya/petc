class Myc::Mycc::Source
  SYSTEM_INCLUDES = [
    "-isysroot", "/Library/Developer/CommandLineTools/SDKs/MacOSX14.sdk",
  ]

  getter filename : String
  getter content : String

  def initialize(@filename)
    raise Exception.new("file not found `#{filename}`") unless File.exists?(filename)
    @content = File.read(filename)
  end

  def clang_parse : Clang::TranslationUnit
    index = Clang::Index.new
    files = [Clang::UnsavedFile.new(filename, content)]

    args = [
      "-x", "c",
      "-std=c99",
      "-I#{File.dirname(filename)}",
      "-Wno-implicit-function-declaration",
    ] + SYSTEM_INCLUDES

    Clang::TranslationUnit.from_source(index, files, args)
  end

  def debug_ast(cursor : Clang::Cursor, indent = 0)
    return if skip_debug_ast?(cursor)
    puts "  " * indent + cursor.inspect
    cursor.visit_children do |child|
      debug_ast(child, indent + 1)
      Clang::ChildVisitResult::Continue
    end
  end

  private def skip_debug_ast?(cursor : Clang::Cursor)
    if location = cursor.location
      if filename = location.file_name
        return true if !filename.includes?(@filename)
      end
    end

    return true if cursor.kind == Clang::CursorKind::MacroDefinition && cursor.type.kind == Clang::TypeKind::Invalid
    false
  end
end
