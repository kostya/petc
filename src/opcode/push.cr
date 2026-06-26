# PUSH - Push Constant
#
# Pushes a constant. Type inferred if not given:
# Int - i32, Float - f64, String - ptr<u8>, Bool - bool.
#
# STACK: [] - [value]
#
#   PUSH 42                ; i32
#   PUSH 255 :u8           ; u8
#   PUSH 3.14              ; f64
#   PUSH 3.14 :f32         ; f32
#   PUSH true              ; bool
#   PUSH "hello"           ; ptr<u8>
#
class Myc::Opcode::Push < Myc::Opcode
  getter value : Source::Token::ArgType
  getter type : Type?

  def initialize(@value, @type = nil)
  end
end
