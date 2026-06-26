#!/usr/bin/env ruby
# Usage: ruby run.rb

BACKENDS = {
  "LLVM"  => "../../../myc-llvm",
  "QBE"   => "../../../myc-qbe",
  "C"     => "../../../myc-c",
}

FLAGS = [
  "", 
  "--release"
]

c3myc = "python3 ../c2myc.py"
tests_dir = "."
passed = 0
failed = 0

TEST_FILES = Dir["#{tests_dir}/*.cc"].sort

TEST_FILES.each do |c_file|
  name = File.basename(c_file, ".cc")
  txt_file = "#{tests_dir}/#{name}.txt"

  unless File.exist?(txt_file)
    puts "SKIP #{name} (no expected output)"
    next
  end

  puts "%-30s " % "================ #{name} ================"

  BACKENDS.each do |backend_name, backend_cmd|
    FLAGS.each do |flag|
      print "%-30s " % "#{backend_name} #{flag} "

      tmp_file = "/tmp/с2myc.myc"
      File.delete(tmp_file) rescue nil
      `#{c3myc} #{c_file} 2>/dev/null > #{tmp_file}`
      got = `#{backend_cmd} run #{flag} #{tmp_file} 2>/dev/null`

      expected = File.read(txt_file).strip
      got = got.strip

      if expected == got
        puts "OK"
        passed += 1
      else
        puts "FAIL"
        puts "--- expected ---"
        puts expected
        puts "--- got ---"
        puts got
        puts "---"
        failed += 1
      end
    end
  end
end

puts ""
puts "Total: Passed: #{passed} | Failed: #{failed}"

exit 1 if failed > 0
