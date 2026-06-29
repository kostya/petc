require 'digest'

FILES = [
  ["../examples/ir/mandel.myc", "005359a040b1689eaf88ac09c2883084"],
  ["../examples/ir/bf.myc", "c4a8df3a4adfe02e1f55c7717ef3d100"],
  ["../examples/ir/loop.myc", "da59897b0c689f23ff826998d316436e"],
  ["../examples/mycc/loop.cc", "da59897b0c689f23ff826998d316436e"],
  ["../examples/mycc/sieve.cc", "650cd81338acca4880c8b92bebcae897"],
]

BACKENDS = {
  "myc-llvm"  => "../myc-llvm",
  "myc-qbe"   => "../myc-qbe",
  "myc-c"     => "../myc-c",
}

MYCC = "../mycc"

def measure
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
end

RES = {}

ok_count = 0
fail_count = 0

FILES.each do |file, expected_md5|
  test_name = File.basename(file)
  puts "%-30s " % "============ #{test_name} ================"
  
  BACKENDS.each do |backend_name, backend_cmd|
    print "%-30s " % "#{backend_name} --release "
    compile_time = 0.0
    compile_file = file
    
    if test_name.end_with?(".cc")
      tmp_file = "/tmp/mycc-generate.myc"
      File.delete(tmp_file) rescue nil
      cmd = "#{MYCC} #{file} > #{tmp_file}"
      compile_time += measure { `#{cmd}` }
      compile_file = tmp_file
    end

    bin_name = "/tmp/myc_test_bench"
    cmd = "#{backend_cmd} c --release #{compile_file} #{bin_name}"
    File.delete(bin_name) rescue nil
    compile_time += measure { `#{cmd}` }
    sleep 0.5
    RES[backend_name] ||= {}
    RES[backend_name][test_name] ||= {}
    RES[backend_name][test_name][:compile_time] = compile_time

    result = nil
    runtime = measure do
      result = Digest::MD5.hexdigest(`#{bin_name}`.strip)
    end

    sleep 0.5
    if expected_md5 == result
      puts "OK"
      ok_count += 1
    else
      puts "ERR #{expected_md5}, got #{result}"
      fail_count += 1
    end

    RES[backend_name][test_name][:run_time] = runtime
  end
end

def markdown_table_grouped(compilers, benchmarks)
  output = []
  output << "| Benchmark | Backend | Compile | Run |"
  output << "|:----------|:-------:|--------:|----:|"
  
  benchmarks.each do |benchmark|
    compilers.each_with_index do |compiler, idx|
      times = RES[compiler][benchmark]
      compile = (times[:compile_time] * 1000).round
      run = (times[:run_time] * 1000).round
      
      if idx == 0
        output << "| #{benchmark} | #{compiler} | #{compile}ms | #{run}ms |"
      else
        output << "| | #{compiler} | #{compile}ms | #{run}ms |"
      end
    end
  end
  
  output.join("\n")
end

compilers = RES.keys
benchmarks = RES[compilers.first].keys

puts
puts markdown_table_grouped(compilers, benchmarks)

if fail_count > 0
  exit(1)
end