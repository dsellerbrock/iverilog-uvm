// C5-1: a named property whose body is a sequence-composition TREE
// (or/and/intersect/...) has no per-instantiation clone recipe yet, so
// only ONE instantiation is supported. Pre-fix the second use fell
// through SILENTLY (dead assertion); it must now be a loud sorry that
// fails the compile. When tree cloning lands, this becomes a positive
// dual-run test and the negative gate will flag it — promote it then.
module sva_named_prop_tree_reuse;
  logic clk = 0, a = 0, b = 0, c = 0;
  always #5 clk = ~clk;

  property tp;
    @(posedge clk) (a ##1 b) or (a ##1 c);
  endproperty

  u1: assert property (tp);
  u2: assert property (tp);
endmodule
