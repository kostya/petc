#!/usr/bin/env python3
"""
Brainfuck to mycIR translator.
Usage: python3 bf2myc.py input.bf [output.myc]

python3 bf2myc.py mandel.bf mandel.myc
time ../../myc-llvm c --release mandel.myc bin_bf_myc_llvm
time ../../myc-c c --release mandel.myc bin_bf_myc_c
time ../../myc-qbe c --release mandel.myc bin_bf_myc_qbe
"""

import sys

def compile_bf(bf_code: str) -> str:
    lines = []
    
    lines.append('FUNC putchar RETURN TYPE i32 ARGS TYPE i32 ENDFUNC')
    lines.append('FUNC getchar RETURN TYPE i32 ENDFUNC')
    
    lines.append('FUNC main')
    lines.append('BODY')
    
    lines.append('PUSH 30000')
    lines.append('MALLOC u8')
    lines.append('LOCAL ptr "ptr<u8>"')
    lines.append('STORE')

    lines.append('LOCAL ptr')
    lines.append('LOCAL bp "ptr<u8>"')
    lines.append('STORE')
    
    for cmd in bf_code:
        if cmd == '>':
            lines.append('PUSH 1')
            lines.append('LOCAL bp')
            lines.append('BINARY :add')
            lines.append('LOCAL bp')
            lines.append('STORE')
        elif cmd == '<':
            lines.append('PUSH -1')
            lines.append('LOCAL bp')
            lines.append('BINARY :add')
            lines.append('LOCAL bp')
            lines.append('STORE')
        elif cmd == '+':
            lines.append('PUSH 1 u8')
            lines.append('LOCAL bp')
            lines.append('DEREF')
            lines.append('BINARY add')
            lines.append('LOCAL bp')
            lines.append('DEREF')
            lines.append('STORE')
        elif cmd == '-':
            lines.append('PUSH 1 u8')
            lines.append('LOCAL bp')
            lines.append('DEREF')
            lines.append('BINARY sub')
            lines.append('LOCAL bp')
            lines.append('DEREF')
            lines.append('STORE')
        elif cmd == '.':
            lines.append('LOCAL bp')
            lines.append('DEREF')
            lines.append('AS i32')
            lines.append('CALL putchar')
            lines.append('STACK :drop')
        elif cmd == ',':
            lines.append('CALL getchar')
            lines.append('AS u8')
            lines.append('LOCAL bp')
            lines.append('DEREF')
            lines.append('STORE')
        elif cmd == '[':
            lines.append('LOOP')
            lines.append('COND')
            lines.append('LOCAL bp')
            lines.append('DEREF')
            lines.append('PUSH 0 u8')
            lines.append('BINARY not_eq')
            lines.append('BODY')
        elif cmd == ']':
            lines.append('ENDLOOP')

    lines.append('LOCAL ptr')
    lines.append('AS "ptr<void>"')
    lines.append('CALL free')
    lines.append('ENDFUNC')
    
    return '\n'.join(lines)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 bf2myc.py input.bf [output.myc]")
        sys.exit(1)
    
    with open(sys.argv[1]) as f:
        bf_code = f.read()
    
    myc_code = compile_bf(bf_code)
    
    if len(sys.argv) >= 3:
        with open(sys.argv[2], 'w') as f:
            f.write(myc_code)
        print(f"Compiled {sys.argv[1]} -> {sys.argv[2]}")
    else:
        print(myc_code)

if __name__ == '__main__':
    main()
