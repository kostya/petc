class Myc::Mod::GlobalDef
  property node : Source::Node
  property name : String
  property type : Type
  property initial_keyword : Bool
  property initial_value : Source::Token::ArgType?
  property constant : Bool

  def initialize(@node, @name, @type, @initial_keyword, @initial_value = nil, @constant = false)
  end
end
