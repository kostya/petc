module Myc
  VERSION = "0.3.0"
  COMMIT  = `git rev-parse --short HEAD`.chomp
  EXT     = ".myc"
end

require "./*"
require "./cli/cli"

module Myc
  extend Stats
end
