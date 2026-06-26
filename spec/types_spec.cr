require "./spec_helper"

describe "Typer" do
  it "finds standard types" do
    spec_find_type("i32").to_s.should eq "i32"
    spec_find_type("u8").to_s.should eq "u8"
    spec_find_type("f64").to_s.should eq "f64"
    spec_find_type("bool").to_s.should eq "bool"
    spec_find_type("void").to_s.should eq "void"
  end

  it "finds pointer types" do
    spec_find_type("ptr<i32>").to_s.should eq "ptr<i32>"
    spec_find_type("ptr<u8>").to_s.should eq "ptr<u8>"
    spec_find_type("ptr<f64>").to_s.should eq "ptr<f64>"
    spec_find_type("ptr<ptr<i32>>").to_s.should eq "ptr<ptr<i32>>"
  end

  it "finds struct types on the fly" do
    t = spec_find_type("struct<i32, f64>")
    t.should be_a(Myc::Type::StructType)
    t.to_s.should eq "struct<i32, f64>"
  end

  it "finds nested struct types" do
    spec_find_type(" struct <    struct < i32 ,  f64 >, i32 > ").to_s.should eq "struct<struct<i32, f64>, i32>"
  end

  it "finds struct with pointer fields" do
    spec_find_type("struct<i32, ptr<f64>>").to_s.should eq "struct<i32, ptr<f64>>"
  end

  it "finds flat types on the fly" do
    t = spec_find_type("flat<i32, 10>")
    t.should be_a(Myc::Type::FlatType)
    t.to_s.should eq "flat<i32, 10>"
  end

  it "finds flat with struct element" do
    spec_find_type("flat<struct<i32, f64>, 5>").to_s.should eq "flat<struct<i32, f64>, 5>"
  end

  it "caches types" do
    t = typer

    t1 = t.find("struct<i32, f64 >", Myc::Location.new("/tmp/1", 0))
    t2 = t.find("struct < i32,f64>", Myc::Location.new("/tmp/1", 0))

    t1.should be t2
  end

  it "finds named types from module" do
    mod = Myc::Mod.new("1", "/tmp/1")
    point = Myc::Type::StructType.new("Point")
    point.data << mod.typer.i32
    point.data << mod.typer.i32
    node = Myc::Source::Node.new(Myc::Opcode::Code::TYPE)
    mod.type_defs["Point"] = Myc::Mod::TypeDef.new(node, point)

    t = mod.typer.find(" Point ", Myc::Location.new("/tmp/1", 0))
    t.to_s.should eq "Point"
    t.should be point

    t = mod.typer.find(" struct <Point, ptr<Point>> ", Myc::Location.new("/tmp/1", 0))
    t.to_s.should eq "struct<Point, ptr<Point>>"
  end

  it "errors on invalid syntax" do
    expect_raises(Myc::Error::ErrorLoc, /expected name got/) {
      spec_find_type("><")
    }
  end

  it "errors on unknown type" do
    expect_raises(Myc::Error::ErrorLoc, /not found type/) {
      spec_find_type("unknown_type_xyz")
    }
  end

  it "errors on unclosed ptr" do
    expect_raises(Myc::Error::ErrorLoc, /expected `>`/) {
      spec_find_type("ptr<i32")
    }
  end

  it "errors on unclosed struct" do
    expect_raises(Myc::Error::ErrorLoc, /expected `,` or '>' for struct/) {
      spec_find_type("struct<i32, f64")
    }
  end

  it "errors on flat without count" do
    expect_raises(Myc::Error::ErrorLoc, /expected number/) {
      spec_find_type("flat<i32, >")
    }
  end

  context "complex" do
    it "finds deeply nested types" do
      spec_find_type("ptr<struct<flat<i32, 3>, ptr<f64>>>").to_s.should eq "ptr<struct<flat<i32, 3>, ptr<f64>>>"
    end

    it "finds struct with many fields" do
      spec_find_type("struct<i32, f64, u8, bool, ptr<i32>>").to_s.should eq "struct<i32, f64, u8, bool, ptr<i32>>"
    end

    it "finds flat of pointers" do
      spec_find_type("flat<ptr<struct<i32, f64>>, 10>").to_s.should eq "flat<ptr<struct<i32, f64>>, 10>"
    end

    it "finds struct with inline flat" do
      t = spec_find_type("struct<i32, flat<f64, 4>>")
      t.should be_a(Myc::Type::StructType)
      t.as(Myc::Type::StructType).data[1].should be_a(Myc::Type::FlatType)
    end

    it "finds ptr to inline struct" do
      t = spec_find_type("ptr<struct<i32, f64>>")
      t.should be_a(Myc::Type::PtrType)
      t.as(Myc::Type::PtrType).target_type.should be_a(Myc::Type::StructType)
    end

    it "finds ptr to inline flat" do
      t = spec_find_type("ptr<flat<u8, 256>>")
      t.should be_a(Myc::Type::PtrType)
      t.as(Myc::Type::PtrType).target_type.should be_a(Myc::Type::FlatType)
    end

    it "finds struct with multiple nested types" do
      spec_find_type("struct<flat<ptr<i32>, 5>, struct<bool, f64>, ptr<flat<u8, 10>>>").to_s.should eq "struct<flat<ptr<i32>, 5>, struct<bool, f64>, ptr<flat<u8, 10>>>"
    end

    it "finds crazy nested type" do
      t = spec_find_type("ptr<struct<struct<flat<ptr<i32>, 3>, f64>, ptr<struct<bool, flat<u8, 10>>>>>")
      t.to_s.should eq "ptr<struct<struct<flat<ptr<i32>, 3>, f64>, ptr<struct<bool, flat<u8, 10>>>>>"
    end
  end
end
