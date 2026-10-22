# Class-scoped type casts

IEEE 1800-2017 §8.5 and IEEE 1800-2023 §8.5 show `vector #(3)::T'(3.45)` as a type cast, and mark the object-property expression `(v.T)'(3.45)` illegal.

Both editions' §6.24.1 define a cast as `casting_type'(expression)` and include `simple_type` in `casting_type`. The `simple_type` grammar includes `ps_type_identifier`; Annex A.2.2.1 permits `class_scope` before `type_identifier` in `ps_type_identifier`. Together those clauses cover a type selected through class scope as a cast type.

The probes cast integer 9 to `C#(3)::T`, where `T` is `bit [2:0]`. The §6.24.1 static-cast assignment rule therefore gives `3'b001` (decimal 1).
