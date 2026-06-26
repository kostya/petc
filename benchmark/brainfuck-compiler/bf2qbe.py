#!/usr/bin/env python3
"""
Brainfuck to QBE IR translator.
Usage: python3 bf2qbe.py input.bf [output.qbe]

python3 bf2qbe.py mandel.bf mandel.ssa
time ../../plugins/qbe/qbe -o mandel.s mandel.ssa
time cc mandel.s -o bin_bf_qbe
"""

import sys


def compile_bf_to_qbe(bf_code: str) -> str:
    lines = []
    loop_id = 0
    loop_stack = []

    def header():
        lines.append('export function  $main() {')
        lines.append('@start')
        lines.append('  %array =l call $calloc(l 30000, l 1)')
        lines.append('  %ptr =l copy %array')
        lines.append('  jmp @body')
        lines.append('@body')
    
    def footer():
        lines.append('  call $free(l %array)')
        lines.append('  ret')
        lines.append('}')

    def emit_ptr_move(offset):
        if offset > 0:
            lines.append(f'  %ptr =l add %ptr, {offset}')
        elif offset < 0:
            lines.append(f'  %ptr =l sub %ptr, {-offset}')

    def emit_add(delta):
        lines.append(f'  %val =w loadub %ptr')
        if delta > 0:
            lines.append(f'  %val =w add %val, {delta}')
        elif delta < 0:
            lines.append(f'  %val =w sub %val, {-delta}')
        lines.append(f'  storeb %val, %ptr')

    def emit_putchar():
        lines.append('  %val =w loadub %ptr')
        lines.append('  %val =w extub %val')
        lines.append('  call $putchar(w %val)')

    def emit_getchar():
        lines.append('  %val =w call $getchar()')
        lines.append('  storeb %val, %ptr')

    def emit_loop_start():
        nonlocal loop_id
        loop_id += 1
        lid = loop_id
        loop_stack.append(lid)
        lines.append(f'  jmp @cond_{lid}')
        lines.append(f'@cond_{lid}')
        lines.append(f'  %val =w loadub %ptr')
        lines.append(f'  jnz %val, @body_{lid}, @end_{lid}')
        lines.append(f'@body_{lid}')
    
    def emit_loop_end():
        lid = loop_stack.pop()
        lines.append(f'  jmp @cond_{lid}')
        lines.append(f'@end_{lid}')

    # Build the IR
    header()
    
    for cmd in bf_code:
        if cmd == '>':
            emit_ptr_move(1)
        elif cmd == '<':
            emit_ptr_move(-1)
        elif cmd == '+':
            emit_add(1)
        elif cmd == '-':
            emit_add(-1)
        elif cmd == '.':
            emit_putchar()
        elif cmd == ',':
            emit_getchar()
        elif cmd == '[':
            emit_loop_start()
        elif cmd == ']':
            emit_loop_end()
    
    footer()
    return '\n'.join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 bf2qbe.py input.bf [output.qbe]")
        sys.exit(1)

    with open(sys.argv[1]) as f:
        bf_code = f.read()

    qbe_code = compile_bf_to_qbe(bf_code)

    if len(sys.argv) >= 3:
        with open(sys.argv[2], 'w') as f:
            f.write(qbe_code)
        print(f"Compiled {sys.argv[1]} -> {sys.argv[2]}")
    else:
        print(qbe_code)


if __name__ == '__main__':
    main()