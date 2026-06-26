module Myc
  VERSION = "0.3.0-dev"
  COMMIT  = `git rev-parse --short HEAD`.chomp
  EXT     = ".myc"
end

require "./*"
require "./cli/cli"
