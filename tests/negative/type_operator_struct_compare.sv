// IEEE 1800-2017 6.23/6.22.1: type() equality comparison is only
// implemented for vector/atom, real, string, enum and class-handle
// operands (see the type_operator_kind_supported_ allow-list in
// elab_expr.cc). Packed-struct operands are deliberately sorried rather
// than answered with the coarse width-only "equivalent" test the rest
// of the type system uses for structs -- that test does not check
// member names/order, so treating it as 6.22.1 "matching" here could
// give a silently WRONG verdict for two same-width-but-different
// structs. This must fail loudly, not silently accept a wrong answer.
module type_operator_struct_compare;
  typedef struct packed { int x; int y; } pair_t;
  pair_t p1, p2;
  bit r;
  initial begin
    r = (type(p1) == type(p2));
  end
endmodule
