# FLAT - Fixed-Size Array Type Definition
#
# Defines a named flat array type: N elements of the same type.
# Anonymous flats: flat<T, N>.
#
#   FLAT :Vec3
#     TYPE :f64
#     COUNT 3
#   ENDFLAT
#
#   ; Create
#   PUSH 3.0
#   PUSH 2.0
#   PUSH 1.0
#   CREATE :Vec3            ; Vec3(1.0, 2.0, 3.0)
#
#   ; Anonymous
#   PUSH 3
#   PUSH 2
#   PUSH 1
#   CREATE "flat<i32, 3>"   ; flat<i32, 3>(1, 2, 3)
#
