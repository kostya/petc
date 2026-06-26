#!/usr/bin/env python3
"""
Brainfuck to LLVM IR translator.
Usage: python3 bf2llvm.py input.bf [output.ll]

python3 bf2llvm.py mandel.bf mandel.ll
cc -O3 mandel.ll -o ./bin_bf_ll
"""

import sys

def compile_bf_to_llvm(bf_code: str) -> str:
    lines = []
    tmp_id = 0
    block_id = 0
    loop_id = 0
    loop_stack = []

    def new_tmp():
        nonlocal tmp_id
        tmp_id += 1
        return f"%t{tmp_id}"

    def new_block(name):
        nonlocal block_id
        block_id += 1
        return f"{name}_{block_id}"

    lines.append('@array = global [30000 x i8] zeroinitializer, align 16')
    lines.append('')
    lines.append('declare i32 @putchar(i32)')
    lines.append('declare i32 @getchar()')
    lines.append('')
    lines.append('define i32 @main() {')
    lines.append('entry:')
    t_ptr_alloca = new_tmp()
    t_array_base = new_tmp()
    lines.append(f'  {t_ptr_alloca} = alloca i8*, align 8')
    lines.append(f'  {t_array_base} = getelementptr inbounds [30000 x i8], [30000 x i8]* @array, i64 0, i64 0')
    lines.append(f'  store i8* {t_array_base}, i8** {t_ptr_alloca}, align 8')
    
    current_block = new_block('body')
    lines.append(f'  br label %{current_block}')
    lines.append(f'{current_block}:')
    
    for cmd in bf_code:
        if cmd == '>':
            t_ptr = new_tmp()
            t_next = new_tmp()
            lines.append(f'  {t_ptr} = load i8*, i8** {t_ptr_alloca}, align 8')
            lines.append(f'  {t_next} = getelementptr inbounds i8, i8* {t_ptr}, i64 1')
            lines.append(f'  store i8* {t_next}, i8** {t_ptr_alloca}, align 8')
        elif cmd == '<':
            t_ptr = new_tmp()
            t_prev = new_tmp()
            lines.append(f'  {t_ptr} = load i8*, i8** {t_ptr_alloca}, align 8')
            lines.append(f'  {t_prev} = getelementptr inbounds i8, i8* {t_ptr}, i64 -1')
            lines.append(f'  store i8* {t_prev}, i8** {t_ptr_alloca}, align 8')
        elif cmd == '+':
            t_ptr = new_tmp()
            t_val = new_tmp()
            t_inc = new_tmp()
            lines.append(f'  {t_ptr} = load i8*, i8** {t_ptr_alloca}, align 8')
            lines.append(f'  {t_val} = load i8, i8* {t_ptr}, align 1')
            lines.append(f'  {t_inc} = add i8 {t_val}, 1')
            lines.append(f'  store i8 {t_inc}, i8* {t_ptr}, align 1')
        elif cmd == '-':
            t_ptr = new_tmp()
            t_val = new_tmp()
            t_dec = new_tmp()
            lines.append(f'  {t_ptr} = load i8*, i8** {t_ptr_alloca}, align 8')
            lines.append(f'  {t_val} = load i8, i8* {t_ptr}, align 1')
            lines.append(f'  {t_dec} = sub i8 {t_val}, 1')
            lines.append(f'  store i8 {t_dec}, i8* {t_ptr}, align 1')
        elif cmd == '.':
            t_ptr = new_tmp()
            t_val = new_tmp()
            t_ext = new_tmp()
            lines.append(f'  {t_ptr} = load i8*, i8** {t_ptr_alloca}, align 8')
            lines.append(f'  {t_val} = load i8, i8* {t_ptr}, align 1')
            lines.append(f'  {t_ext} = zext i8 {t_val} to i32')
            lines.append(f'  call i32 @putchar(i32 {t_ext})')
        elif cmd == ',':
            t_ptr = new_tmp()
            t_call = new_tmp()
            t_trunc = new_tmp()
            lines.append(f'  {t_ptr} = load i8*, i8** {t_ptr_alloca}, align 8')
            lines.append(f'  {t_call} = call i32 @getchar()')
            lines.append(f'  {t_trunc} = trunc i32 {t_call} to i8')
            lines.append(f'  store i8 {t_trunc}, i8* {t_ptr}, align 1')
        elif cmd == '[':
            loop_id += 1
            cond_block = new_block(f'cond_{loop_id}')
            body_block = new_block(f'body_{loop_id}')
            end_block = new_block(f'end_{loop_id}')
            
            lines.append(f'  br label %{cond_block}')
            lines.append(f'{cond_block}:')
            t_ptr = new_tmp()
            t_val = new_tmp()
            t_cond = new_tmp()
            lines.append(f'  {t_ptr} = load i8*, i8** {t_ptr_alloca}, align 8')
            lines.append(f'  {t_val} = load i8, i8* {t_ptr}, align 1')
            lines.append(f'  {t_cond} = icmp ne i8 {t_val}, 0')
            lines.append(f'  br i1 {t_cond}, label %{body_block}, label %{end_block}')
            lines.append(f'{body_block}:')
            
            loop_stack.append((cond_block, end_block))
        elif cmd == ']':
            if not loop_stack:
                raise ValueError("Unmatched ']'")
            cond_block, end_block = loop_stack.pop()
            lines.append(f'  br label %{cond_block}')
            lines.append(f'{end_block}:')

    lines.append('  ret i32 0')
    lines.append('}')
    
    return '\n'.join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 bf2llvm.py input.bf [output.ll]")
        sys.exit(1)
    
    with open(sys.argv[1]) as f:
        bf_code = f.read()
    
    llvm_code = compile_bf_to_llvm(bf_code)
    
    if len(sys.argv) >= 3:
        with open(sys.argv[2], 'w') as f:
            f.write(llvm_code)
        print(f"Compiled {sys.argv[1]} -> {sys.argv[2]}")
    else:
        print(llvm_code)


if __name__ == '__main__':
    main()