# run comparison for codegen Myc vs others

CC = ENV["CC"] || "cc"
QBE = ENV["QBE"] || "../../plugins/qbe/qbe"
MYC_LLVM = "../../myc-llvm"
MYC_C = "../../myc-c"
MYC_QBE = "../../myc-qbe"

CFG = {
	"llvm": {
		"ir": "llvm-ll",
		"compiler": "clang(-O3)",
		"src": "mandel.ll",
		"cmd": "#{CC} -O3 mandel.ll -o ./bin_bf_ll",
		"run": "./bin_bf_ll",
		"py": "python3 bf2llvm.py mandel.bf mandel.ll"
	}, 
	"myc-llvm": {
		"ir": "myc",
		"compiler": "myc-llvm(--release)",
		"src": "mandel.myc",
		"cmd": "#{MYC_LLVM} c --release mandel.myc bin_bf_myc_llvm",
		"run": "./bin_bf_myc_llvm",
		"py": "python3 bf2myc.py mandel.bf mandel.myc"
	},
	"qbe": {
		"ir": "qbe-ssa",
		"compiler": "qbe + clang(as+linker)",
		"src": "mandel.ssa",
		"cmd": ["#{QBE} -o mandel.s mandel.ssa", "#{CC} mandel.s -o bin_bf_qbe"],
		"run": "./bin_bf_qbe",
		"py": "python3 bf2qbe.py mandel.bf mandel.ssa"
	}, 
	"myc-qbe": {
		"ir": "myc",
		"compiler": "myc-qbe(--release)",
		"src": "mandel.myc",
		"cmd": "#{MYC_QBE} c --release mandel.myc bin_bf_myc_qbe",
		"run": "./bin_bf_myc_qbe",
		"py": "python3 bf2myc.py mandel.bf mandel.myc"
	},
	"c": {
		"ir": "c",
		"compiler": "clang(-O3)",
		"src": "mandel.c",
		"cmd": "#{CC} -O3 mandel.c -o bin_bf_c",
		"run": "./bin_bf_c",
		"py": "python3 bf2c.py mandel.bf mandel.c"
	}, 
	"myc-c": {
		"ir": "myc",
		"compiler": "myc-c(--release)",
		"src": "mandel.myc",
		"cmd": "#{MYC_C} c --release mandel.myc bin_bf_myc_c",
		"run": "./bin_bf_myc_c",
		"py": "python3 bf2myc.py mandel.bf mandel.myc"
	},
}

def measure
	t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
	yield
	Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
end

def delta_to_s(delta)
	"#{(delta * 1000).to_i}ms"
end

results = Hash.new { |h, k| h[k] = {} }

# generate sources
CFG.each do |name, h|
	`#{h[:py]}`
	results[name]["source_size"] = File.read(h[:src]).size
end

# compile and measure time
CFG.each do |name, h|
	cmd = h[:cmd]
	result_str = ""
	if cmd.is_a?(Array)
		cmd.each do |c|
			delta = measure { `#{c}` }
			result_str += " + #{delta_to_s(delta)}"
		end
		result_str = result_str[3..-1]
	else
		delta = measure { `#{cmd}` }
		result_str = delta_to_s(delta)
	end

	results[name]["compile_time"] = result_str
	sleep 0.5
end

sleep 1

# run 
CFG.each do |name, h|
	cmd = h[:run]	
	delta = measure { `#{cmd}` }
	results[name]["run_time"] = delta_to_s(delta)
	sleep 0.5
end

def markdown_table(headers, rows)
  output = []
  output << "| " + headers.join(" | ") + " |"
  output << "|" + (":---------:|" * headers.size)
  rows.each do |row|
    output << "| " + row.map { |cell| cell.to_s }.join(" | ") + " |"
  end  
  output.join("\n")
end

rows = []
results.each do |name, h|
	rows << [CFG[name][:ir], CFG[name][:compiler], (h["source_size"] / 1024.0).to_i, h["compile_time"], h["run_time"]]
end

puts markdown_table(["IR", "Compiler", "IR size, Kb", "Compile time", "Run time"], rows)
