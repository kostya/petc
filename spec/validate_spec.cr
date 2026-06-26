require "./spec_helper"

context "Validate" do
  it "simple func" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :main BODY PUSH 1 RET ENDFUNC
    _____________________________src
    FUNC :main
      BODY
        PUSH 1
        RET
    ENDFUNC
    _____________________________res
  end

  it "func with args and return" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :add RETURN TYPE :i32 ARGS TYPE :i32 TYPE :i32 BODY PARAM 0 PARAM 1 BINARY :add RET ENDFUNC
    _____________________________src
    FUNC :add
      ARGS
        TYPE :i32
        TYPE :i32
      RETURN
        TYPE :i32
      BODY
        PARAM 0
        PARAM 1
        BINARY :add
        RET
    ENDFUNC
    _____________________________res
  end

  it "func with attributes" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :main BODY PUSH 1 RET ATTRIBUTES ATTR :vaarg ENDFUNC
    _____________________________src
    FUNC :main
      ATTRIBUTES
        ATTR :vaarg
      BODY
        PUSH 1
        RET
    ENDFUNC
    _____________________________res
  end

  it "if else" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test BODY IF THEN PUSH 1 ELSE PUSH 2 ENDIF ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        IF
          THEN
            PUSH 1
          ELSE
            PUSH 2
        ENDIF
    ENDFUNC
    _____________________________res
  end

  it "loop" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test BODY LOOP COND PUSH true BODY PUSH 1 STEP PUSH 1 ENDLOOP ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        LOOP
          COND
            PUSH true
          BODY
            PUSH 1
          STEP
            PUSH 1
        ENDLOOP
    ENDFUNC
    _____________________________res
  end

  it "struct" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    STRUCT "Point" TYPE i32 TYPE i32 ALIGN 8 ENDSTRUCT
    _____________________________src
    STRUCT :Point
      ALIGN 8
      TYPE :i32
      TYPE :i32
    ENDSTRUCT
    _____________________________res
  end

  it "enum" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    ENUM "Option" VARIANT "None" VARIANT "Some" TYPE i32 TYPE "f64" ALIGN 8 ENDENUM
    _____________________________src
    ENUM :Option
      ALIGN 8
      VARIANT :None
      VARIANT :Some
        TYPE :i32
        TYPE :f64
    ENDENUM
    _____________________________res
  end

  it "flat" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FLAT "Point" TYPE i32 COUNT 5 ALIGN 8 ENDFLAT
    _____________________________src
    FLAT :Point
      ALIGN 8
      TYPE :i32
      COUNT 5
    ENDFLAT
    _____________________________res
  end

  it "globals" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    GLOBAL counter TYPE i32 CONSTANT INITIAL 0 ENDGLOBAL
    _____________________________src
    GLOBAL :counter
      TYPE :i32
      INITIAL 0
      CONSTANT
    ENDGLOBAL
    _____________________________res
  end

  it "globals" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    GLOBAL counter TYPE i32 ENDGLOBAL
    _____________________________src
    GLOBAL :counter
      TYPE :i32
    ENDGLOBAL
    _____________________________res
  end

  it "declare external func" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC printf RETURN TYPE i32 ARGS TYPE "ptr<u8>" ENDFUNC
    _____________________________src
    FUNC :printf
      ARGS
        TYPE :ptr<u8>
      RETURN
        TYPE :i32
    ENDFUNC
    _____________________________res
  end

  it "full program" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    STRUCT "Point" TYPE i32 TYPE i32 ENDSTRUCT
    ENUM "Option" VARIANT "None" VARIANT "Some" TYPE i32 ENDENUM
    GLOBAL counter TYPE i32 INITIAL 0 ENDGLOBAL
    FUNC printf RETURN TYPE i32 ARGS TYPE "ptr<u8>" ENDFUNC
    FUNC main BODY PUSH 1 RET ENDFUNC
    _____________________________src
    STRUCT :Point
      TYPE :i32
      TYPE :i32
    ENDSTRUCT

    ENUM :Option
      VARIANT :None
      VARIANT :Some
        TYPE :i32
    ENDENUM

    GLOBAL :counter
      TYPE :i32
      INITIAL 0
    ENDGLOBAL

    FUNC :printf
      ARGS
        TYPE :ptr<u8>
      RETURN
        TYPE :i32
    ENDFUNC

    FUNC :main
      BODY
        PUSH 1
        RET
    ENDFUNC
    _____________________________res
  end

  context "Validate Errors" do
    it "error: duplicate RETURN in FUNC" do
      expect_raises(Myc::Error::ErrorLoc, /return already defined/) do
        validate(<<-'_____________________________src')
      FUNC main
      RETURN TYPE i32
      RETURN TYPE f64
      BODY
        PUSH 1
        RET
      ENDFUNC
      _____________________________src
      end
    end

    it "error: duplicate ARGS in FUNC" do
      expect_raises(Myc::Error::ErrorLoc, /args already defined/) do
        validate(<<-'_____________________________src')
      FUNC main
      ARGS TYPE i32
      ARGS TYPE f64
      BODY
        PUSH 1
        RET
      ENDFUNC
      _____________________________src
      end
    end

    it "error: duplicate BODY in FUNC" do
      expect_raises(Myc::Error::ErrorLoc, /body already defined/) do
        validate(<<-'_____________________________src')
      FUNC main
      BODY PUSH 1 RET
      BODY PUSH 2 RET
      ENDFUNC
      _____________________________src
      end
    end

    it "error: RETURN with wrong number of types" do
      expect_raises(Myc::Error::ErrorLoc, /return should have one type/) do
        validate(<<-'_____________________________src')
      FUNC main
      RETURN TYPE i32 TYPE f64
      BODY
        PUSH 1
        RET
      ENDFUNC
      _____________________________src
      end
    end

    it "error: duplicate THEN in IF" do
      expect_raises(Myc::Error::ErrorLoc, /then already defined/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        IF
          THEN PUSH 1
          THEN PUSH 2
        ENDIF
      ENDFUNC
      _____________________________src
      end
    end

    it "error: duplicate ELSE in IF" do
      expect_raises(Myc::Error::ErrorLoc, /else already defined/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        IF
          THEN PUSH 1
          ELSE PUSH 2
          ELSE PUSH 3
        ENDIF
      ENDFUNC
      _____________________________src
      end
    end

    it "error: IF without THEN" do
      expect_raises(Myc::Error::ErrorLoc, /undefined THEN/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        IF
          ELSE PUSH 1
        ENDIF
      ENDFUNC
      _____________________________src
      end
    end

    it "error: LOOP without BODY" do
      expect_raises(Myc::Error::ErrorLoc, /LOOP should have at least BODY/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        LOOP
          COND PUSH true
          STEP PUSH 1
        ENDLOOP
      ENDFUNC
      _____________________________src
      end
    end

    it "error: duplicate INIT in LOOP" do
      expect_raises(Myc::Error::ErrorLoc, /INIT already defined/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        LOOP
          INIT PUSH 0
          INIT PUSH 1
          COND PUSH true
          BODY PUSH 1
        ENDLOOP
      ENDFUNC
      _____________________________src
      end
    end

    it "error: duplicate COND in LOOP" do
      expect_raises(Myc::Error::ErrorLoc, /COND already defined/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        LOOP
          COND PUSH true
          COND PUSH false
          BODY PUSH 1
        ENDLOOP
      ENDFUNC
      _____________________________src
      end
    end

    it "error: duplicate BODY in LOOP" do
      expect_raises(Myc::Error::ErrorLoc, /BODY already defined/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        LOOP
          COND PUSH true
          BODY PUSH 1
          BODY PUSH 2
        ENDLOOP
      ENDFUNC
      _____________________________src
      end
    end

    it "error: duplicate STEP in LOOP" do
      expect_raises(Myc::Error::ErrorLoc, /STEP already defined/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        LOOP
          COND PUSH true
          BODY PUSH 1
          STEP PUSH 1
          STEP PUSH 2
        ENDLOOP
      ENDFUNC
      _____________________________src
      end
    end

    it "error: SWITCH without CASE" do
      expect_raises(Myc::Error::ErrorLoc, /SWITCH empty cases/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        SWITCH
          ELSE PUSH "default"
        ENDSWITCH
      ENDFUNC
      _____________________________src
      end
    end

    it "error: SWITCH without values" do
      expect_raises(Myc::Error::ErrorLoc, /CASE expected only 1 value/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        SWITCH
          CASE PUSH 1
        ENDSWITCH
      ENDFUNC
      _____________________________src
      end
    end

    it "error: duplicate ELSE in SWITCH" do
      expect_raises(Myc::Error::ErrorLoc, /ELSE already defined/) do
        validate(<<-'_____________________________src')
      FUNC test
      BODY
        SWITCH
          CASE 1 PUSH 1
          ELSE PUSH "first"
          ELSE PUSH "second"
        ENDSWITCH
      ENDFUNC
      _____________________________src
      end
    end

    it "error: duplicate TYPE in GLOBAL" do
      expect_raises(Myc::Error::ErrorLoc, /TYPE already defined/) do
        validate(<<-'_____________________________src')
      GLOBAL counter
        TYPE i32
        TYPE f64
      ENDGLOBAL
      _____________________________src
      end
    end

    it "error: missing TYPE in GLOBAL" do
      expect_raises(Myc::Error::ErrorLoc, /missing TYPE/) do
        validate(<<-'_____________________________src')
      GLOBAL counter
        INITIAL 0
      ENDGLOBAL
      _____________________________src
      end
    end

    it "error: ENUM without VARIANT" do
      expect_raises(Myc::Error::ErrorLoc, /ENUM must have at least one VARIANT/) do
        validate(<<-'_____________________________src')
      ENUM "Empty"
      ENDENUM
      _____________________________src
      end
    end

    it "error: RETURN in FUNC with wrong count" do
      expect_raises(Myc::Error::ErrorLoc, /return should have one type/) do
        validate(<<-'_____________________________src')
      FUNC foo RETURN TYPE i32 TYPE f64 ENDFUNC
      _____________________________src
      end
    end
  end

  it "stack commands" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC main BODY
      STACK :swap2
      STACK :drop
      STACK :drop 10
    ENDFUNC
    _____________________________src
    FUNC :main
      BODY
        STACK :swap2
        STACK :drop
        STACK :drop 10
    ENDFUNC
    _____________________________res
  end

  it "stack unknown command" do
    expect_raises(Myc::Error::ErrorLoc, /unknown shift asdf/) do
      validate(<<-'_____________________________src')
      FUNC test
      BODY
        STACK :asdf
      ENDFUNC
      _____________________________src
    end
  end

  it "global usage" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    GLOBAL x TYPE i32 ENDGLOBAL
    FUNC main BODY
      GLOBAL x
    ENDFUNC
    _____________________________src
    GLOBAL :x
      TYPE :i32
    ENDGLOBAL

    FUNC :main
      BODY
        GLOBAL :x
    ENDFUNC
    _____________________________res
  end

  it "PUSH with type" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC main BODY
      PUSH 1 u8
    ENDFUNC
    _____________________________src
    FUNC :main
      BODY
        PUSH 1 :u8
    ENDFUNC
    _____________________________res
  end

  it "LOCAL with optional type" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC main BODY
      LOCAL x i32
      LOCAL x
    ENDFUNC
    _____________________________src
    FUNC :main
      BODY
        LOCAL :x :i32
        LOCAL :x
    ENDFUNC
    _____________________________res
  end

  it "CALL vaargs" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC main BODY
      PUSH "bla\n"
      CALL printf 1
    ENDFUNC
    _____________________________src
    FUNC :main
      BODY
        PUSH "bla\n"
        CALL :printf 1
    ENDFUNC
    _____________________________res
  end

  it "canonize IF THEN ELSE" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :main
    BODY
      IF ELSE PUSH 1 THEN PUSH 2 ENDIF
    ENDFUNC
    _____________________________src
    FUNC :main
      BODY
        IF
          THEN
            PUSH 2
          ELSE
            PUSH 1
        ENDIF
    ENDFUNC
    _____________________________res
  end

  it "canonize FUNC sections" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :add
    BODY
      PARAM 0
      PARAM 1
      BINARY :add
      RET
    ARGS TYPE :i32 TYPE :i32
    RETURN TYPE :i32
    ENDFUNC
    _____________________________src
    FUNC :add
      ARGS
        TYPE :i32
        TYPE :i32
      RETURN
        TYPE :i32
      BODY
        PARAM 0
        PARAM 1
        BINARY :add
        RET
    ENDFUNC
    _____________________________res
  end

  it "canonize top level order" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :main
    BODY
      RET
    ENDFUNC
    STRUCT point
      TYPE :i32
    ENDSTRUCT
    ENUM option
      VARIANT none
    ENDENUM
    _____________________________src
    STRUCT :point
      TYPE :i32
    ENDSTRUCT

    ENUM :option
      VARIANT :none
    ENDENUM

    FUNC :main
      BODY
        RET
    ENDFUNC
    _____________________________res
  end

  it "canonize LOOP order" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test
    BODY
      LOOP
        BODY
          PUSH 1
        STEP
          PUSH 2
        COND
          PUSH 3
        INIT
          PUSH 4
      ENDLOOP
    ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        LOOP
          INIT
            PUSH 4
          COND
            PUSH 3
          BODY
            PUSH 1
          STEP
            PUSH 2
        ENDLOOP
    ENDFUNC
    _____________________________res
  end

  it "all constructs" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :main
    RETURN TYPE :i32
    ARGS TYPE :i32 TYPE :i32
    BODY
      PARAM 0
      PARAM 1
      BINARY :add
      PUSH 10
      BINARY "less"
      IF
        THEN
          PUSH 1
          PUSH "yes"
          PRINTF 1
        ELSE
          PUSH 1
          PUSH "no"
          PRINTF 1
      ENDIF
      LOOP
        INIT
          LOCAL x :i32
          PUSH 0
          STORE
        COND
          LOCAL x :i32
          PUSH 10
          BINARY "less"
        BODY
          LOCAL x :i32
          PUSH "iter %d\n"
          PRINTF 1
        STEP
          PUSH 1
          LOCAL x :i32
          BINARY "add"
          LOCAL x :i32
          STORE
      ENDLOOP
      SWITCH
        CASE 1
          PUSH "zero"
          PRINTF 1
        CASE 2
          PUSH "one"
          PRINTF 1
        ELSE
          PUSH "other"
          PRINTF 1
      ENDSWITCH
      RET
    ENDFUNC
    STRUCT :point
      TYPE :i32
      TYPE :i32
    ENDSTRUCT
    ENUM :option
      VARIANT :none
      VARIANT :some
        TYPE :i32
    ENDENUM
    GLOBAL :counter
      TYPE :i32
      INITIAL 0
    ENDGLOBAL
    _____________________________src
    STRUCT :point
      TYPE :i32
      TYPE :i32
    ENDSTRUCT

    ENUM :option
      VARIANT :none
      VARIANT :some
        TYPE :i32
    ENDENUM

    GLOBAL :counter
      TYPE :i32
      INITIAL 0
    ENDGLOBAL

    FUNC :main
      ARGS
        TYPE :i32
        TYPE :i32
      RETURN
        TYPE :i32
      BODY
        PARAM 0
        PARAM 1
        BINARY :add
        PUSH 10
        BINARY :less
        IF
          THEN
            PUSH 1
            PUSH :yes
            PRINTF 1
          ELSE
            PUSH 1
            PUSH :no
            PRINTF 1
        ENDIF
        LOOP
          INIT
            LOCAL :x :i32
            PUSH 0
            STORE
          COND
            LOCAL :x
            PUSH 10
            BINARY :less
          BODY
            LOCAL :x
            PUSH "iter %d\n"
            PRINTF 1
          STEP
            PUSH 1
            LOCAL :x
            BINARY :add
            LOCAL :x
            STORE
        ENDLOOP
        SWITCH
          CASE 1
            PUSH :zero
            PRINTF 1
          CASE 2
            PUSH :one
            PRINTF 1
          ELSE
            PUSH :other
            PRINTF 1
        ENDSWITCH
        RET
    ENDFUNC
    _____________________________res
  end

  it "SELECT" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test
    BODY
      PUSH 1
      PUSH 2
      PUSH true
      SELECT
    ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        PUSH 1
        PUSH 2
        PUSH true
        SELECT
    ENDFUNC
    _____________________________res
  end

  it "recursive struct" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    STRUCT "Point1" TYPE :ptr<Point2> ENDSTRUCT
    STRUCT "Point2" TYPE :ptr<Point1> ENDSTRUCT
    _____________________________src
    STRUCT :Point1
      TYPE :ptr<Point2>
    ENDSTRUCT

    STRUCT :Point2
      TYPE :ptr<Point1>
    ENDSTRUCT
    _____________________________res
  end

  it "ADDR" do
    validate(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test
    BODY
      LOCAL x :i32
      ADDR
    ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        LOCAL :x :i32
        ADDR
    ENDFUNC
    _____________________________res
  end
end
