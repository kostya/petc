abstract struct Myc::Source::Token
  property offset : UInt32 = 0
  record Eof < Token
  record Opcode < Token, code : Myc::Opcode::Code
  record OpcodeUnknown < Token, name : String
  alias ArgType = Int64 | Float64 | String | Bool
  record Arg < Token, v : ArgType
end
