abstract class Myc::Backend::AbstractBB
  getter name : String
  getter builder : AbstractBuilder
  getter func : AbstractFunc
  getter func_def : Mod::FuncDef

  def initialize(@name, @builder, @func, @func_def)
  end

  abstract def alloca(name : String, type : Type) : Value
  abstract def call(name : String, type_fn : Type::Fn, args : Array(Value)) : Value?
  abstract def store(lhs : Value, rhs : Value)
  abstract def fn_addr(name : String, type_fn : Type::Fn) : Value
  abstract def invoke(fn : Value, type_fn : Type::Fn, args : Array(Value)) : Value?

  abstract def next(name : String) : AbstractBB
  abstract def jmp(other : AbstractBB)
  abstract def cond(cond : Value, then_bb : AbstractBB, else_bb : AbstractBB)
  abstract def switch(index : Value, case_values : Array(Value), case_bbs : Array(AbstractBB), default_bb : AbstractBB)
  abstract def ret(val : Value?)

  abstract def load_ref(value : Value) : Value
  abstract def field(value : Value, field_type : Type, offset : Int32) : Value
  abstract def extract_value(value : Value, field_type : Type, offset : Int32) : Value
  abstract def deref(value : Value, target_type : Type) : Value
  abstract def addr(value : Value, ptr_type : Type) : Value
  abstract def offset(value : Value, target_type : Type, offset : Value) : Value
  abstract def bitcast(value : Value, to_type : Type) : Value

  abstract def binary(op : Opcode::Binary::Op, lhs : Value, rhs : Value) : Value?
  abstract def unary(op : Opcode::Unary::Op, rhs : Value) : Value?
  abstract def cast?(value : Value, from_type : Type, to_type : Type) : Value?
  abstract def to?(value : Value, from_type : Type, to_type : Type) : Value?
  abstract def select(cond : Value, arg_true : Value, arg_false : Value) : Value
end
