class Myc::Backend::Value
  enum MM
    Val
    Ref

    def short_name
      case self
      in .val? then "val"
      in .ref? then "ref"
      end
    end
  end

  abstract struct PP
    def short_name
      case self
      in PP::Primitive          then "Co"
      in PP::Param              then "Pa"
      in PP::Global             then "Gl"
      in PP::GlobalConstant     then "Gc"
      in PP::LocalUninitialized then "Lu"
      in PP::Local              then "Lo"
      in PP::CallResult         then "Ca"
      in PP::Unknown, PP        then "??"
      end
    end

    record Unknown < PP
    record Primitive < PP
    record Param < PP, index : Int32
    record Global < PP, name : String
    record GlobalConstant < PP, name : String
    record Local < PP, name : String
    record LocalUninitialized < PP, name : String
    record CallResult < PP, name : String
  end

  getter bbval : AbstractBBVal
  getter type : Type
  getter mm : MM
  property pp : PP

  def initialize(@bbval, @type, @mm, @pp)
  end

  def unsafe_new_with_type(new_type : Type) : Value
    Value.new(@bbval, new_type, @mm, @pp)
  end

  def to_rhs(visitor : AbstractVisitor) : Value
    case _pp = pp
    when PP::LocalUninitialized
      raise visitor.error("cant read from uninitialized local `#{_pp.name}`")
    end

    case @mm
    in .val? then self
    in .ref? then visitor.bb.load_ref(self)
    end
  end

  def to_lhs(visitor : AbstractVisitor) : Value
    case @mm
    in .val? then raise visitor.error("cant use #{@pp.to_s} as LHS#{@type.is_a?(Type::PtrType) ? ", maybe forgot DEREF?" : ""}")
    in .ref? then self
    end
  end

  def _to_ref(visitor : AbstractVisitor) : Value
    case @mm
    in .val?
      tmp_name = visitor.next_unique("__myc_to_ref_wrapper__")
      tmp = visitor.func.alloca_bb.alloca(tmp_name, @type)
      tmp.pp = PP::Local.new(tmp_name)
      tmp.store(visitor, self)
      tmp
    in .ref? then self
    end
  end

  def store(visitor : AbstractVisitor, from : Value)
    visitor.bb.store(self, from)
    if_local_mark_it_as_initialized(visitor)
  end

  def field(visitor : AbstractVisitor, index : Int32) : Value
    field_type = @type.field_type?(index)
    raise visitor.error("no field #{index} in #{@type}") unless field_type

    case @mm
    in .val?
      visitor.bb.extract_value(self, field_type, index)
    in .ref?
      visitor.bb.field(self, field_type, index)
    end
  end

  def addr(visitor : AbstractVisitor) : Value
    if_local_mark_it_as_initialized(visitor)

    case @mm
    in .ref?
      ptr_type = visitor.mod.typer.to_ptr(@type, visitor.current_op.offset)
      visitor.bb.addr(self, ptr_type)
    in .val?
      raise visitor.error("Cannot take address of val, store it to LOCAL before")
    end
  end

  def deref(visitor : AbstractVisitor) : Value
    case @mm
    in .ref?
      case t = @type
      when Type::PtrType
        v = visitor.bb.load_ref(self)
        visitor.bb.deref(v, t.target_type)
      else
        raise visitor.error("Cannot dereference #{@mm.to_s.downcase}")
      end
    in .val?
      case t = @type
      when Type::PtrType
        visitor.bb.deref(self, t.target_type)
      else
        raise visitor.error("Cannot dereference #{@mm.to_s.downcase}")
      end
    end
  end

  def offset(visitor : AbstractVisitor, offset : Value) : Value
    case @mm
    in .ref?
      raise visitor.error("Cannot take offset of ref")
    in .val?
      case t = type
      when Type::PtrType
        visitor.bb.offset(self, t.target_type, offset)
      else
        raise visitor.error("not ptr type")
      end
    end
  end

  def bitcast_flat(visitor : AbstractVisitor, to_type : Type) : Value
    case @mm
    in .val?
      raise visitor.error("Cannot bitcast_flat for val")
    in .ref?
      visitor.bb.bitcast(self, to_type)
    end
  end

  private def if_local_mark_it_as_initialized(visitor : AbstractVisitor)
    case _pp = @pp
    when PP::LocalUninitialized
      if local = visitor.locals[_pp.name]?
        local.pp = PP::Local.new(_pp.name)
      end
    end
  end
end
