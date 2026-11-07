// IEEE 1800-2017/2023 6.23: a type() operand may only appear in an
// equality, inequality, case equality or case inequality comparison;
// relational comparison of types is illegal. (6.22.1 struct matching
// itself is supported: see ivtest issue756_type_match_aggregates.)
module type_operator_struct_compare;
  typedef struct packed { int x; int y; } pair_t;
  pair_t p1, p2;
  bit r;
  initial begin
    r = (type(p1) < type(p2));
  end
endmodule
