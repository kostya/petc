#!/usr/bin/env python3
"""
Brainfuck to C translator.
Usage: python3 bf2c.py input.bf [output.c]

python3 bf2c.py mandel.bf mandel.c
cc -O3 mandel.c -o bin_bf_c
"""

import sys

def compile_bf_to_c(bf_code: str) -> str:
    lines = []
    
    lines.append('#include <stdio.h>')
    lines.append('#include <stdlib.h>')
    lines.append('')
    lines.append('int main() {')
    lines.append('    unsigned char array[30000] = {0};')
    lines.append('    unsigned char *ptr = array;')
    lines.append('')
    
    indent = 1
    
    for cmd in bf_code:
        if cmd == '>':
            lines.append('    ptr++;')
        elif cmd == '<':
            lines.append('    ptr--;')
        elif cmd == '+':
            lines.append('    (*ptr)++;')
        elif cmd == '-':
            lines.append('    (*ptr)--;')
        elif cmd == '.':
            lines.append('    putchar(*ptr);')
        elif cmd == ',':
            lines.append('    *ptr = getchar();')
        elif cmd == '[':
            lines.append('    while (*ptr) {')
            indent += 1
        elif cmd == ']':
            indent -= 1
            lines.append('    }')
    
    lines.append('')
    lines.append('    return 0;')
    lines.append('}')
    
    return '\n'.join(lines)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 bf2c.py input.bf [output.c]")
        sys.exit(1)
    
    with open(sys.argv[1]) as f:
        bf_code = f.read()
    
    c_code = compile_bf_to_c(bf_code)
    
    if len(sys.argv) >= 3:
        with open(sys.argv[2], 'w') as f:
            f.write(c_code)
        print(f"Compiled {sys.argv[1]} -> {sys.argv[2]}")
    else:
        print(c_code)

if __name__ == '__main__':
    main()