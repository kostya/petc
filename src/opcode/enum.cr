# ENUM - Tagged Union Definition
#
# Defines a sum type with named variants, each with an optional payload.
# Variants are numbered from 0. Layout: { tag: i32, payload: max variant size }.
# Access payload via AS :Enum::Variant.
#
# STACK: [] - []
#
#   ENUM :Option
#     VARIANT :None           ; tag 0, no payload
#     VARIANT :Some           ; tag 1
#       TYPE :i32
#   ENDENUM
#
#   ; Create via CREATE
#   PUSH 42
#   CREATE :Option::Some      ; tag auto-set to 1
#
#   ; Create manually
#   PUSH 1
#   LOCAL :v :Option
#   FIELD 0
#   STORE                   ; tag = 1
#   PUSH 42
#   LOCAL :v
#   AS :Option::Some
#   FIELD 1
#   STORE                   ; payload = 42
#
#   ; Match
#   LOCAL :opt :Option
#   FIELD 0
#   SWITCH
#     CASE 0                  ; None
#       ...
#     CASE 1                  ; Some
#       LOCAL :opt
#       AS :Option::Some
#       FIELD 1
#       ...
#   ENDSWITCH
#
