class Myc::Mycc::Error < Exception
  getter cursor : Clang::Cursor

  def initialize(@message, @cursor)
  end
end
