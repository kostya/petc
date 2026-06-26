require "./spec_helper"

context "Myc::Source::Tokenizer" do
  it "PUSH number" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:1:7]"
      PUSH 1
    SRC
  end

  it "PUSH space" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:4, V:1:9]"
        PUSH 1
    SRC
  end

  it "some" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:1:7, O:RET:11]"
      PUSH 1
      RET
    SRC
  end

  it "double quotes" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:\"hello\":7]"
      PUSH "hello"
    SRC
  end

  it "single quotes" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:\"hello\":7]"
      PUSH 'hello'
    SRC
  end

  it "string :asdf" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:\"asdf\":7]"
      PUSH :asdf
    SRC
  end

  it "string" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:\"lba#@$\":7]"
      PUSH "lba#@$"
    SRC
  end

  it "float number" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:3.14:7]"
      PUSH 3.14
    SRC
  end

  it "float exp" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:15000000000.0:7]"
      PUSH 1.5e10
    SRC
  end

  it "neg" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:-42:7]"
      PUSH -42
    SRC
  end

  it "hex number" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:4096:7, O:PUSH:16, V:255:21, O:PUSH:28, V:43981:33]"
      PUSH 0x1000
      PUSH 0xFF
      PUSH 0xABCD
    SRC
  end

  it "true" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:true:7]"
      PUSH true
    SRC
  end

  it "false" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:false:7]"
      PUSH false
    SRC
  end

  it "string without anything" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:\"my_var\":7]"
      PUSH my_var
    SRC
  end

  it "commeng" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:1:7, O:RET:23]"
      PUSH 1
      # comment
      RET
    SRC
  end

  it "comment" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:1:7]"
      PUSH 1 # comment
    SRC
  end

  it "comment ;" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:1:7, O:RET:33]"
      PUSH 1
      ; this is a comment
      RET
    SRC
  end

  it "comment ;" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:1:7]"
      PUSH 1 ; comment
    SRC
  end

  it "empty strings" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:1:7, O:RET:14]"
      PUSH 1



      RET
    SRC
  end

  it "tabs" do
    tokenize("\tPUSH\t1\t").inspect.should eq "[O:PUSH:1, V:1:6]"
  end

  it "CRLF" do
    tokenize("PUSH 1\r\nRET").inspect.should eq "[O:PUSH:0, V:1:5, O:RET:8]"
  end

  it "func" do
    src = <<-SRC
    FUNC main
    RETURN TYPE i32
    ARGS TYPE i32 TYPE i32
    BODY
      PARAM 0
      PARAM 1
      BINARY add
      RET
    ENDFUNC
    SRC

    tokenize(src).inspect.should eq <<-EQ
    [O:FUNC:0, V:"main":5, O:RETURN:10, O:TYPE:17, V:"i32":22, O:ARGS:26, O:TYPE:31, V:"i32":36, O:TYPE:40, V:"i32":45, O:BODY:49, O:PARAM:56, V:0:62, O:PARAM:66, V:1:72, O:BINARY:76, V:"add":83, O:RET:89, O:ENDFUNC:93]
    EQ
  end

  it "error bad string" do
    expect_raises(Myc::Error::ErrorLoc, /string not ended/) do
      tokenize(%(PUSH "hello))
    end
  end

  it "error unexpected@" do
    expect_raises(Myc::Error::ErrorLoc, /unexpected symbol/) do
      tokenize("PUSH @value")
    end
  end

  it "error @" do
    expect_raises(Myc::Error::ErrorLoc, /unexpected symbol/) do
      tokenize("@")
    end
  end

  it "error number with word" do
    expect_raises(Myc::Error::ErrorLoc, /expected separator after number/) do
      tokenize("PUSH 1bla")
    end
  end

  it "error: overflow" do
    expect_raises(Myc::Error::ErrorLoc, /number constant is too big/) do
      tokenize("PUSH 100000000000000000000000")
    end
  end

  it "error -word" do
    expect_raises(Myc::Error::ErrorLoc, /unexpected symbol '-'/) do
      tokenize("PUSH -myvar")
    end
  end

  it "empty" do
    tokenize("").inspect.should eq "[]"
  end

  it "spaces" do
    tokenize("   \n  \t  ").inspect.should eq "[]"
  end

  it "comments" do
    tokenize("# just a comment\n").inspect.should eq "[]"
  end

  it "no values" do
    tokenize(<<-SRC).inspect.should eq "[O:RET:2]"
      RET
    SRC
  end

  it "many values" do
    tokenize(<<-SRC).inspect.should eq "[O:CALL:2, V:\"printf\":7, V:1:14]"
      CALL printf 1
    SRC
  end

  it "escape" do
    tokenize(%(PUSH "hello\\nworld")).inspect.should eq %([O:PUSH:0, V:"hello\\nworld":5])
  end

  it "hard string" do
    tokenize(%(PUSH 'it\\'s')).inspect.should eq %([O:PUSH:0, V:"it's":5])
  end

  it "unknown opcode" do
    tokenize(<<-SRC).inspect.should eq "[OU:HAHHAHAHA:2, V:1:12]"
      HAHHAHAHA 1
    SRC
  end

  it "parse float, was bug" do
    tokenize(<<-SRC).inspect.should eq "[O:PUSH:2, V:1.0:7]"
      PUSH 1.0
    SRC
  end
end
