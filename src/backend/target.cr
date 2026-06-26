struct Myc::Backend::Target
  enum Arch
    Arm64
    X86_64
    X86
    Wasm32
    Unknown
  end

  getter arch : Arch
  getter original_triple : String?

  def initialize(@arch, @original_triple = nil)
  end

  def self.from_triple(triple : String) : self
    arch = case triple
           when /aarch64|arm64/       then Arch::Arm64
           when /x86_64|amd64/        then Arch::X86_64
           when /i386|i486|i586|i686/ then Arch::X86
           when /wasm32/              then Arch::Wasm32
           else                            Arch::Unknown
           end
    self.new(arch, triple)
  end

  def pointer_size
    case arch
    in .arm64?, .x86_64?, .unknown?
      8_u64
    in .x86?, .wasm32?
      4_u64
    end
  end

  def pointer_alignment
    case arch
    in .arm64?, .x86_64?, .unknown?
      8_u64
    in .x86?, .wasm32?
      4_u64
    end
  end

  def triple : String
    original_triple || default_triple
  end

  private def default_triple
    case arch
    in .arm64?   then "arm64-apple-darwin"
    in .x86_64?  then "x86_64-unknown-linux-gnu"
    in .x86?     then "i386-unknown-linux-gnu"
    in .wasm32?  then "wasm32-unknown-unknown"
    in .unknown? then "unknown-unknown-unknown"
    end
  end
end
