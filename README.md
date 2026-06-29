# myc - MyCompiler

**A small IR for building programming languages.**

### What is it?

* Simple DSL over LLVM/QBE.
* Your language AST -> mycIR -> [LLVM / QBE / C] -> binary.
* ~25 stack-based opcodes. 
* Whole IR spec fits in 15 minutes of reading. 
* Compiles to native code via LLVM, QBE, or C. 
* Fast compilation, zero overhead. 
* ~6500 lines in Crystal.
* Includes mycc: a C subset compiler using mycIR as backend and libclang for C parsing.


### Why?

* I was writing my own language and got tired of fighting with LLVM IR. SSA, phi nodes, basic blocks — X(.
* Usually when you write your own language, you first build a parser and generate an AST. Then comes the hell stage — translating your AST into LLVM or another backend. Myc takes on all that complexity.
* LLVM is complex. 
* Myc is simple and fun.
* Stack-based opcodes are easy to emit from AST with a simple one-pass tree walk.
* You're not locked into one backend. LLVM for speed, QBE for fast compiles, C for anywhere.

### Current status

Alpha. But already powerful. All 3 backends work smoothly. 2900 tests pass.

### Ultimate goal

Beat LLVM (joke). Real goal: beat gcc :).

## Benchmark: 

Mandelbrot renderer from mandel.bf (by Erik Bosman). All IR represent the same program. Shows whether Myc adds overhead over direct backend usage. Running on Ryzen3800+Linux in benchmark/brainfuck-compiler.

| IR | Compiler | IR size, Kb | Compile time | Run time |
|:---------:|:---------:|:---------:|:---------:|:---------:|
| llvm-ll | clang(-O3) | 1529 | 1668ms | 618ms |
| myc | myc-llvm(--release) | 486 | 1552ms | 632ms |
| qbe-ssa | qbe + clang(as+linker) | 345 | 197ms + 58ms | 812ms |
| myc | myc-qbe(--release) | 486 | 1041ms | 833ms |
| c | clang(-O3) | 128 | 1711ms | 641ms |
| myc | myc-c(--release) | 486 | 1902ms | 619ms |

Myc adds "zero" overhead over the LLVM and C backends. The myc-qbe backend adds overhead due to suboptimal code generation, which will be addressed by future peephole optimization passes.

## Install

Requires [Crystal](https://crystal-lang.org) to compile the myc compiler.

Quick Start (compile and run first program).

```sh
echo 'FUNC main BODY PUSH "Hello myc\n" PRINTF 0 ENDFUNC' | crystal src/cli/llvm.cr r
```

### Build

```sh
git clone https://github.com/kostya/myc
cd myc

# compile Myc IR C backend
crystal build src/cli/c.cr --release -o myc-c

# compile Myc IR LLVM backend
# requires LLVM >= 15.0, install it system wide or provide LLVM_CONFIG env variable
crystal build src/cli/llvm.cr --release -o myc-llvm 

# compile Myc IR Qbe backend
git clone https://github.com/kostya/qbe.git plugins/qbe
cd plugins/qbe; make; cd -
crystal build src/cli/qbe.cr --release -o myc-qbe
```

## mycIR

All opcodes [self documented](https://github.com/kostya/myc/tree/master/src/opcode). Also see [examples](https://github.com/kostya/myc/tree/master/examples).

* 19 main opcodes: PUSH, LOCAL, STORE, CALL, PARAM, BINARY, UNARY, FIELD, DEREF, ADDR, AS, SELECT, MALLOC, CREATE, INSPECT, PRINTF, STACK, SIZEOF, TO
* 6 Control flow: IF/THEN/ELSE, LOOP/INIT/COND/BODY/STEP, SWITCH/CASE, BREAK, NEXT, RET
* Types: STRUCT, ENUM/VARIANT, FLAT + void, bool, i8..i64, u8..u64, f32, f64, ptr<T>

## mycc: a C subset compiler

~1300 lines of Crystal. Uses mycIR as backend and libclang for C parsing. Require LLVM >= 20.

```sh
# Build
# sudo apt install llvm-20 libclang-20-dev
shards install; crystal build src/cli/mycc.cr -o ./mycc

# Show mycIR output
./mycc examples/mycc/sieve.cc

# Build and run (LLVM backend)
./mycc examples/mycc/sieve.cc | ./myc-llvm r --release

# Show LLVM IR dump
./mycc examples/mycc/sieve.cc | ./myc-llvm d

# Show optimized LLVM IR dump
./mycc examples/mycc/sieve.cc | ./myc-llvm d --release
```

### Example: Brainfuck compiler with myc IR.

```sh
cd benchmark/brainfuck-compiler
python3 bf2myc.py mandel.bf | ../../myc-llvm run --release
```

## More benchmarks from examples/

```sh
./myc-llvm run --release examples/ir/mandel.myc
./myc-llvm run --release examples/ir/bf.myc
./myc-llvm run --release examples/ir/loop.myc
```

| Benchmark | Backend | Compile | Run |
|:----------|:-------:|--------:|----:|
| mandel.myc | myc-llvm | 1561ms | 633ms |
| | myc-qbe | 1048ms | 834ms |
| | myc-c | 1883ms | 618ms |
| bf.myc | myc-llvm | 75ms | 2570ms |
| | myc-qbe | 59ms | 4233ms |
| | myc-c | 94ms | 2865ms |
| loop.myc | myc-llvm | 61ms | 169ms |
| | myc-qbe | 56ms | 2437ms |
| | myc-c | 75ms | 140ms |
| loop.cc | myc-llvm | 81ms | 142ms |
| | myc-qbe | 76ms | 2437ms |
| | myc-c | 95ms | 127ms |
| sieve.cc | myc-llvm | 90ms | 439ms |
| | myc-qbe | 76ms | 449ms |
| | myc-c | 106ms | 446ms |

### Example: factorial in mycIR, examples/ir/fact.myc, translation

<details>
<summary>examples/ir/fact.myc</summary>

```myc
FUNC fact
  ARGS
    TYPE i32
  RETURN
    TYPE i32
  BODY
    PUSH 1
    PARAM 0
    BINARY less_eq
    IF
      THEN
        PUSH 1
        RET
    ENDIF
    PUSH 1
    PARAM 0
    BINARY sub
    CALL fact
    PARAM 0
    BINARY mul
    RET
ENDFUNC

FUNC main
  BODY
    PUSH 5
    CALL fact
    INSPECT
ENDFUNC
```
</details>

<details>
<summary>LLVM Backend `./myc-llvm dump examples/ir/fact.myc`</summary>

```
; ModuleID = 'fact'
source_filename = "fact"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-darwin23.3.0"

@str = private constant [15 x i8] c"fact(%d) = %d\0A\00"

define i32 @fact(i32 %0) {
alloca:
  %__myc_result = alloca i32, align 4
  br label %body

body:                                             ; preds = %alloca
  %1 = icmp sle i32 %0, 1
  br i1 %1, label %then, label %endif

ret:                                              ; preds = %endif, %then
  %2 = load i32, ptr %__myc_result, align 4
  ret i32 %2

then:                                             ; preds = %body
  store i32 1, ptr %__myc_result, align 4
  br label %ret

endif:                                            ; preds = %body
  %3 = sub i32 %0, 1
  %4 = call i32 @fact(i32 %3)
  %5 = mul i32 %0, %4
  store i32 %5, ptr %__myc_result, align 4
  br label %ret
}

define void @main() {
alloca:
  br label %body

body:                                             ; preds = %alloca
  %0 = call i32 @fact(i32 5)
  %1 = call i32 (ptr, ...) @printf(ptr @str, i32 5, i32 %0)
  br label %ret

ret:                                              ; preds = %body
  ret void
}

declare i32 @printf(ptr, ...)
```

</details>

<details>
<summary>QBE Backend `./myc-qbe dump examples/ir/fact.myc`</summary>

```
data $str_0 = { b "fact(%d) = %d\n", b 0 }
export function w $fact(w %arg0) {
@start
  %__myc_result =l alloc8 4
  jmp @body
@body
  %t1 =w cslew %arg0, 1
  jnz %t1, @then_1, @endif_2
@then_1
  storew 1, %__myc_result
  jmp @ret
@endif_2
  %t2 =w sub %arg0, 1
  %t3 =w call $fact(w %t2)
  %t4 =w mul %arg0, %t3
  storew %t4, %__myc_result
  jmp @ret
@ret
  %ret_val =w loadw %__myc_result
  ret %ret_val
}

export function  $main() {
@start
  jmp @body
@body
  %t1 =w call $fact(w 5)
  %t2 =w call $printf(l $str_0, ..., w 5, w %t1)
  jmp @ret
@ret
  ret
}
```

</details>

<details>
<summary>C Backend `./myc-c dump examples/ir/fact.myc`</summary>

```
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <inttypes.h>

int32_t fact(int32_t arg0);
void main();
int32_t fact(int32_t arg0) {
  int32_t __myc_result;
  int t1 = arg0 <= 1;
  if (t1) goto then_1; else goto endif_2;

then_1:;
  __myc_result = 1;
  goto ret;

endif_2:;
  int32_t t2 = arg0 - 1;
  int32_t t3 = fact(t2);
  int32_t t4 = arg0 * t3;
  __myc_result = t4;
  goto ret;

ret:;
  return __myc_result;
}
void main() {
  int32_t t5 = fact(5);
  int32_t t6 = printf("fact(%d) = %d\n", 5, t5);
  goto ret;

ret:;
  return;
}
```

</details>

## Run tests

```
crystal spec
```

## Usage

<details>
<summary>Usage</summary>

```
Usage: ./myc-llvm COMMAND [OPTIONS] INPUT [INPUT]* [OUTPUT]

Commands:

  compile|c  ; compile multiple .myc files into executable binary
             ;   ./myc-llvm c file.myc out
             ;   ./myc-llvm c --release *.myc out
             ;   cat file.myc | ./myc-llvm c --release out

  run|r      ; compile multiple .myc files and run the program
             ;   ./myc-llvm r file.myc
             ;   ./myc-llvm r --release file.myc
             ;   cat file.myc | ./myc-llvm r --release

  obj|o      ; compile one .myc file into object file (.o) for linking
             ;   ./myc-llvm o file.myc file.o
             ;   ./myc-llvm o --release file.myc file.o
             ;   cat file.myc | ./myc-llvm o --release file.o

  dump|d     ; output backend IR to console (for debugging and optimization analysis)
             ;   ./myc-llvm d file.myc
             ;   ./myc-llvm d --release file.myc
             ;   cat file.myc | ./myc-llvm d --release

  beautify|b ; format, validate, and add auto-comments(--annotate) to .myc files
             ;   ./#{cli_name} b .
             ;   ./#{cli_name} b --annotate src/
             ;   ./#{cli_name} b file1.myc file2.myc

  version|v  ; display version information
             ;   ./myc-llvm version

OPTIONS:
  --release ; compile in performance mode (optimizations enabled)
  --target=TARGET   (TARGET: arm64, x86_64, x86, wasm32, ...; default: native)
```

</details>

## License

Licensed under the Apache License, Version 2.0.

## Thanks

- [Crystal language](https://crystal-lang.org)
- [QBE](https://c9x.me/compile/)
- [LLVM](https://llvm.org/)
- [clang.cr](https://github.com/crystal-lang/clang.cr)
