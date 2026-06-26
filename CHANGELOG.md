## 0.3.0-dev
* UNARY :not was splitted into :lnot, :bnot
* AS :bool, now can cast from int, float
* opcode OFFSET was deleted, use BINARY :add instead
* add SIZEOF opcode
* add opcode TO, and RET, STORE, BINARY, CALL use it to auto safe cast

## 0.2.0 (24.06.2026)
* Added linter for auto-annotating stack state (beautify --annotate)
* Linter also used for pretty error output
* Added C compiler to examples
* Isolate stack for seqs
* opcode RESULT was deleted, use just RET

## 0.1.0 (22.06.2026)
* First release
