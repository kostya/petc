class Myc::Opcode
  property offset : UInt32 = 0

  def with_position(node : Source::Node)
    self.offset = node.offset
    self
  end

  enum Code : UInt64
    CALL    = 0
    PUSH
    LOCAL
    STORE
    FIELD
    DEREF
    AS
    INSPECT
    PRINTF
    MALLOC
    PARAM
    BINARY
    RET
    BREAK
    NEXT
    UNARY
    STACK
    SELECT
    CREATE
    ADDR
    SIZEOF
    TO

    UNDEF    = 500
    TYPE
    INITIAL
    COUNT
    ATTR
    CONSTANT
    ALIGN

    MOD    = 1000
    FUNC
    LOOP
    IF
    ENUM
    SWITCH

    BODY       = 2000
    ARGS
    RETURN
    VARIANT
    GLOBAL
    THEN
    ELSE
    INIT
    COND
    STEP
    CASE
    STRUCT
    ATTRIBUTES
    FLAT

    ENDFUNC   = 3000
    ENDENUM
    ENDGLOBAL
    ENDSTRUCT
    ENDIF
    ENDLOOP
    ENDSWITCH
    ENDFLAT

    def container?
      self.value >= 1000 && self.value < 2000
    end

    def sequence?
      self.value >= 2000 && self.value < 3000
    end

    def meta?
      self.value >= 3000 && self.value < 4000
    end
  end
end

require "./opcode/*"
