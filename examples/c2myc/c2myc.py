#!/usr/bin/env python3

# subset of C -> MycIR translator
# 
# python3 -m venv py
# source py/bin/activate
# pip install pycparser
# python c2myc.py tests/03-loop.cc | ../../myc-llvm run --release 

import sys
import os
from pycparser import c_parser, c_ast

class IRGenerator(c_ast.NodeVisitor):
    def __init__(self):
        self.ir_lines = []
        self.indent = 0
        self.params = {}
        self.vars = {}
    
    def emit(self, line):
        self.ir_lines.append("  " * self.indent + line)
    
    def visit_FileAST(self, node):
        for ext in node.ext:
            self.visit(ext)
    
    def visit_FuncDef(self, node):
        func_name = node.decl.name
        self.params = {}
        self.vars = {}
        
        self.emit(f"FUNC :{func_name}")
        self.indent += 1
        
        if hasattr(node.decl.type, 'args') and node.decl.type.args:
            self.emit("ARGS")
            self.indent += 1
            param_id = 0
            for param in node.decl.type.args.params:
                if isinstance(param, c_ast.Decl):
                    param_type = self._get_type(param.type)
                    self.params[param.name] = param_id
                    self.emit(f"  TYPE :{param_type}")
                    param_id += 1
            self.indent -= 1
        
        ret_type = self._get_return_type(node.decl.type)
        if ret_type != "void":
            self.emit("RETURN")
            self.indent += 1
            self.emit(f"  TYPE :{ret_type}")
            self.indent -= 1
        
        self.emit("BODY")
        self.indent += 1
        self.visit(node.body)
        self.indent -= 1
        
        self.emit("ENDFUNC")
        self.indent -= 1
    
    def visit_Compound(self, node):
        if node.block_items:
            for item in node.block_items:
                self.visit(item)
    
    def visit_Decl(self, node):
        var_type = self._get_type(node.type)
        self.vars[node.name] = var_type
        if node.init:
            self.visit(node.init)
            self.emit(f"LOCAL :{node.name} :{var_type}")
            self.emit("STORE")
    
    def visit_Assignment(self, node):
        if isinstance(node.lvalue, c_ast.ID):
            self.visit(node.rvalue)
            self.emit_id(node.lvalue.name)
            self.emit("STORE")
    
    def visit_BinaryOp(self, node):
        self.visit(node.right)
        self.visit(node.left)
        
        op_map = {
            '+': 'add', '-': 'sub', '*': 'mul', '/': 'div',
            '<': 'less', '>': 'more', '<=': 'less_eq', '>=': 'more_eq',
            '==': 'eq', '!=': 'not_eq', '%': 'rem',
        }
        
        op = op_map.get(node.op, node.op)
        self.emit(f"BINARY :{op}")
    
    def visit_Constant(self, node):
        if node.type == 'int':
            self.emit(f"PUSH {node.value} :i32")
        elif node.type == 'string':
            self.emit(f"PUSH {node.value}")
    
    def visit_ID(self, node):
        if node.name != 'printf':
            self.emit_id(node.name)
    
    def visit_FuncCall(self, node):
        func_name = node.name.name
        
        if func_name == 'printf':
            args = list(node.args)
            args.reverse()
            for arg in args:
                self.visit(arg)
            self.emit(f"PRINTF {len(args) - 1}")
        else:
            args = list(node.args)
            args.reverse()
            for arg in args:
                self.visit(arg)
            self.emit(f"CALL :{func_name}")
    
    def visit_If(self, node):
        self.visit(node.cond)
        
        self.emit("IF")
        self.indent += 1
        
        self.emit("THEN")
        self.indent += 1
        self.visit(node.iftrue)
        self.indent -= 1
        
        if node.iffalse:
            self.emit("ELSE")
            self.indent += 1
            self.visit(node.iffalse)
            self.indent -= 1
        
        self.indent -= 1
        self.emit("ENDIF")
    
    def visit_While(self, node):
        self.emit("LOOP")
        self.indent += 1
        
        self.emit("COND")
        self.indent += 1
        self.visit(node.cond)
        self.indent -= 1
        
        self.emit("BODY")
        self.indent += 1
        self.visit(node.stmt)
        self.indent -= 1
        
        self.emit("STEP")
        
        self.indent -= 1
        self.emit("ENDLOOP")
    
    def visit_Return(self, node):
        if node.expr:
            self.visit(node.expr)
        self.emit("RET")
    
    def visit_UnaryOp(self, node):
        if node.op == 'p++':
            self.emit("PUSH 1 :i32")
            self.visit(node.expr)
            self.emit("BINARY :add")
            if isinstance(node.expr, c_ast.ID):
                self.emit_id(node.expr.name)
                self.emit("STORE")
        elif node.op == 'p--':
            self.emit("PUSH 1 :i32")
            self.visit(node.expr)
            self.emit("BINARY :sub")
            if isinstance(node.expr, c_ast.ID):
                self.emit_id(node.expr.name)
                self.emit("STORE")

    def visit_Break(self, node):
        self.emit("BREAK")

    def emit_id(self, name):
        if name in self.vars:
            self.emit(f"LOCAL :{name} :{self.vars[name]}")
        elif name in self.params:
            self.emit(f"PARAM {self.params[name]}")
        else:
            self.emit(f"LOCAL :{name}")

    def _get_type(self, type_node):
        if isinstance(type_node, c_ast.TypeDecl):
            return self._get_type(type_node.type)
        elif isinstance(type_node, c_ast.IdentifierType):
            type_map = {'int': 'i32', 'char': 'i8', 'void': 'void'}
            return type_map.get(type_node.names[0], 'i32')
        return "i32"
    
    def _get_return_type(self, type_node):
        if isinstance(type_node, c_ast.FuncDecl):
            if isinstance(type_node.type, c_ast.TypeDecl):
                return self._get_type(type_node.type.type)
        return "void"
    
    def get_ir(self):
        return "\n".join(self.ir_lines)


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <input_file.c>", file=sys.stderr)
        sys.exit(1)
    
    with open(sys.argv[1], 'r') as f:
        code = f.read()
    
    parser = c_parser.CParser()
    ast = parser.parse(code)
    if os.environ.get('AST') == '1':
        ast.show()
    
    generator = IRGenerator()
    generator.visit(ast)
    
    print(generator.get_ir())

if __name__ == "__main__":
    main()