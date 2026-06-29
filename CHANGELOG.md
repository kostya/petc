## 0.4.0-dev
* mycc: rewrite with typed AST + single-pass codegen
* AS: remove C specific casts int->bool, float->bool

## 0.3.0 (28.06.2026)
* UNARY :not was splitted into :lnot, :bnot
* AS :bool, now can cast from int, float
* opcode OFFSET was deleted, use BINARY :add instead
* add SIZEOF opcode
* add opcode TO, and RET, STORE, BINARY, CALL use it to auto safe cast
* added mycc, remove python c compiler
* `TO` safe coercions only: widening with same sign, no sign change at same size
* `BINARY`: renamed `l_shr` → `shr`, `a_shr` → `sar`

## 0.2.0 (24.06.2026)
* Added linter for auto-annotating stack state (beautify --annotate)
* Linter also used for pretty error output
* Added C compiler to examples
* Isolate stack for seqs
* opcode RESULT was deleted, use just RET

## 0.1.0 (22.06.2026)
* First release
