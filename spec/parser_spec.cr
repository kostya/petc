require "./spec_helper"

context "Myc::Source::Parser" do
  it "simple func" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :main
    BODY
      PUSH 1
      RET
    ENDFUNC
    _____________________________src
    FUNC :main
      BODY
        PUSH 1
        RET
    ENDFUNC
    _____________________________res
  end

  it "onelined" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :main BODY PUSH 1 RET ENDFUNC
    _____________________________src
    FUNC :main
      BODY
        PUSH 1
        RET
    ENDFUNC
    _____________________________res
  end

  it "FUNC with RETURN and ARGS" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :add
    RETURN TYPE :i32
    ARGS TYPE :i32 TYPE :i32
    BODY
      PARAM 0
      PARAM 1
      BINARY :add
      RET
    ENDFUNC
    _____________________________src
    FUNC :add
      RETURN
        TYPE :i32
      ARGS
        TYPE :i32
        TYPE :i32
      BODY
        PARAM 0
        PARAM 1
        BINARY :add
        RET
    ENDFUNC
    _____________________________res
  end

  it "IF THEN ELSE" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test
    BODY
      IF
        THEN
          PUSH 1
        ELSE
          PUSH 2
      ENDIF
    ENDFUNC
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

  it "LOOP" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test
    BODY
      LOOP
        COND
          PUSH 1
        BODY
          PUSH 2
        STEP
          PUSH 3
      ENDLOOP
    ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        LOOP
          COND
            PUSH 1
          BODY
            PUSH 2
          STEP
            PUSH 3
        ENDLOOP
    ENDFUNC
    _____________________________res
  end

  it "SWITCH" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test
    BODY
      SWITCH
        CASE 1
          PUSH 1
        CASE 2
          PUSH 2
        ELSE
          PUSH 3
      ENDSWITCH
    ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        SWITCH
          CASE 1
            PUSH 1
          CASE 2
            PUSH 2
          ELSE
            PUSH 3
        ENDSWITCH
    ENDFUNC
    _____________________________res
  end

  it "STRUCT" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    STRUCT :point
      TYPE :i32
      TYPE :i32
    ENDSTRUCT
    _____________________________src
    STRUCT :point
      TYPE :i32
      TYPE :i32
    ENDSTRUCT
    _____________________________res
  end

  it "ENUM" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    ENUM :option
      VARIANT :none
      VARIANT :some
        TYPE :i32
    ENDENUM
    _____________________________src
    ENUM :option
      VARIANT :none
      VARIANT :some
        TYPE :i32
    ENDENUM
    _____________________________res
  end

  it "FLAT" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FLAT :vec3
      TYPE f64
      COUNT 3
    ENDFLAT
    _____________________________src
    FLAT :vec3
      TYPE :f64
      COUNT 3
    ENDFLAT
    _____________________________res
  end

  it "GLOBAL" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    GLOBAL :counter
      TYPE :i32
      INITIAL 0
    ENDGLOBAL
    _____________________________src
    GLOBAL :counter
      TYPE :i32
      INITIAL 0
    ENDGLOBAL
    _____________________________res
  end

  it "IF inside LOOP" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test
    BODY
      LOOP
        COND
          PUSH 1
        BODY
          IF
            THEN
              PUSH 2
            ELSE
              PUSH 3
          ENDIF
        STEP
          PUSH 4
      ENDLOOP
    ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        LOOP
          COND
            PUSH 1
          BODY
            IF
              THEN
                PUSH 2
              ELSE
                PUSH 3
            ENDIF
          STEP
            PUSH 4
        ENDLOOP
    ENDFUNC
    _____________________________res
  end

  it "LOOP inside IF" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test
    BODY
      IF
        THEN
          LOOP
            COND
              PUSH 1
            BODY
              PUSH 2
          ENDLOOP
        ELSE
          PUSH 3
      ENDIF
    ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        IF
          THEN
            LOOP
              COND
                PUSH 1
              BODY
                PUSH 2
            ENDLOOP
          ELSE
            PUSH 3
        ENDIF
    ENDFUNC
    _____________________________res
  end

  it "SWITCH inside IF" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test
    BODY
      IF
        THEN
          SWITCH
            CASE 1
              PUSH 1
            ELSE
              PUSH 2
          ENDSWITCH
        ELSE
          PUSH 3
      ENDIF
    ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        IF
          THEN
            SWITCH
              CASE 1
                PUSH 1
              ELSE
                PUSH 2
            ENDSWITCH
          ELSE
            PUSH 3
        ENDIF
    ENDFUNC
    _____________________________res
  end

  it "IF inside IF" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :test
    BODY
      IF
        THEN
          IF
            THEN
              PUSH 1
            ELSE
              PUSH 2
          ENDIF
        ELSE
          PUSH 3
      ENDIF
    ENDFUNC
    _____________________________src
    FUNC :test
      BODY
        IF
          THEN
            IF
              THEN
                PUSH 1
              ELSE
                PUSH 2
            ENDIF
          ELSE
            PUSH 3
        ENDIF
    ENDFUNC
    _____________________________res
  end

  it "empty func" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :empty
    BODY
    ENDFUNC
    _____________________________src
    FUNC :empty
      BODY
    ENDFUNC
    _____________________________res
  end

  it "func without return and args" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :simple
    BODY
      PUSH 42
      RET
    ENDFUNC
    _____________________________src
    FUNC :simple
      BODY
        PUSH 42
        RET
    ENDFUNC
    _____________________________res
  end

  it "multiple structs and enums" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    STRUCT :a
      TYPE :i32
    ENDSTRUCT
    STRUCT :b
      TYPE :f64
    ENDSTRUCT
    ENUM :c
      VARIANT :d
      VARIANT :e
        TYPE :i32
    ENDENUM
    _____________________________src
    STRUCT :a
      TYPE :i32
    ENDSTRUCT

    STRUCT :b
      TYPE :f64
    ENDSTRUCT

    ENUM :c
      VARIANT :d
      VARIANT :e
        TYPE :i32
    ENDENUM
    _____________________________res
  end

  it "error: bad root section" do
    expect_raises(Myc::Error::ErrorLoc, /unknown root section/) do
      parse(<<-'_____________________________src')
      UNKNOWN opcode
      _____________________________src
    end
  end

  it "error: values not allowed at top level" do
    expect_raises(Myc::Error::ErrorLoc, /values not allowed/) do
      parse(<<-'_____________________________src')
      "string" at top
      _____________________________src
    end
  end

  it "error: not closed section" do
    expect_raises(Myc::Error::ErrorLoc, /not closed section/) do
      parse(<<-'_____________________________src')
      FUNC :main
      BODY
        PUSH 1
      _____________________________src
    end
  end

  it "error: no sections" do
    expect_raises(Myc::Error::ErrorLoc, /expected section opcode/) do
      parse(<<-'_____________________________src')
      FUNC :main JOPA ENDFUNC
      _____________________________src
    end
  end

  it "error: top section in local context" do
    expect_raises(Myc::Error::ErrorLoc, /unexpected opcode FUNC/) do
      parse(<<-'_____________________________src')
      FUNC :main
      BODY
        FUNC nested
        BODY
        ENDFUNC
      ENDFUNC
      _____________________________src
    end
  end

  it "error: unknown opcode in body" do
    expect_raises(Myc::Error::ErrorLoc, /unknown opcode/) do
      parse(<<-'_____________________________src')
      FUNC :main
      BODY
        UNKNOWN_OP
      ENDFUNC
      _____________________________src
    end
  end

  it "error: wrong close tag inside IF" do
    expect_raises(Myc::Error::ErrorLoc, /unexpected opcode ENDFUNC/) do
      parse(<<-'_____________________________src')
      FUNC :main
      BODY
        IF
          THEN
            PUSH 1
        ENDFUNC
      ENDFUNC
      _____________________________src
    end
  end

  it "error: STRUCT at top level closed with wrong tag" do
    expect_raises(Myc::Error::ErrorLoc, /unexpected opcode ENDFUNC/) do
      parse(<<-'_____________________________src')
      STRUCT point
        TYPE :i32
      ENDFUNC
      _____________________________src
    end
  end

  it "error: ENUM with bad subsection" do
    expect_raises(Myc::Error::ErrorLoc, /not closed section/) do
      parse(<<-'_____________________________src')
      ENUM option
        IF
          THEN
            PUSH 1
        ENDIF
      ENDENUM
      _____________________________src
    end
  end

  it "error: GLOBAL with nested FUNC" do
    expect_raises(Myc::Error::ErrorLoc, /unexpected opcode FUNC/) do
      parse(<<-'_____________________________src')
      GLOBAL
        FUNC :test
        BODY
      ENDGLOBAL
      _____________________________src
    end
  end

  it "ok: LOOP without COND" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
      FUNC :main
      BODY
        LOOP
          BODY
            PUSH 1
        ENDLOOP
      ENDFUNC
      _____________________________src
      FUNC :main
        BODY
          LOOP
            BODY
              PUSH 1
          ENDLOOP
      ENDFUNC
      _____________________________res
  end

  it "error: SWITCH without ENDSWITCH" do
    expect_raises(Myc::Error::ErrorLoc, /unexpected opcode ENDFUNC/) do
      parse(<<-'_____________________________src')
      FUNC :main
      BODY
        SWITCH
          CASE 1
            PUSH 1
      ENDFUNC
      _____________________________src
    end
  end

  it "declare external func" do
    parse(<<-'_____________________________src').should eq <<-'_____________________________res'
    FUNC :printf RETURN TYPE :i32 ARGS TYPE "ptr<u8>" ENDFUNC
    _____________________________src
    FUNC :printf
      RETURN
        TYPE :i32
      ARGS
        TYPE :ptr<u8>
    ENDFUNC
    _____________________________res
  end

  it "error: use undefined section from another container" do
    expect_raises(Myc::Error::ErrorLoc, /unexpected opcode CASE/) do
      parse(<<-'_____________________________src')
      FUNC :main
      ARGS
        TYPE :i32
      CASE
        PUSH 1
      ENDFUNC
      _____________________________src
    end
  end

  it "error: use undefined section from another container" do
    expect_raises(Myc::Error::ErrorLoc, /unexpected opcode CASE/) do
      parse(<<-'_____________________________src')
      FUNC :main
      ARGS
        TYPE :i32
      BODY
        IF
        THEN
        CASE
        ENDIF
      ENDFUNC
      _____________________________src
    end
  end

  it "error: CASE in FUNC" do
    expect_raises(Myc::Error::ErrorLoc, /not closed section/) do
      validate(<<-'src')
        FUNC foo CASE PUSH 1 ENDFUNC
        src
    end
  end
end
