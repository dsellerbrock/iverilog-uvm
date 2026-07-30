// IEEE 1800-2017 A.2.10 defines property_expr recursively, so
// `not (a |-> b)' is LEGAL. This fork models a property as a flat step
// chain and cannot represent it yet. Before this test the grammar had
// no production for the form at all, so it died as a bare `syntax
// error' -- a diagnostic that tells the user their correct code is
// malformed. It must be refused BY NAME, citing the clause that makes
// it legal, until the nested representation lands.
module sva_not_nested_property;
  logic clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;
  ap: assert property (@(posedge clk) not (a |-> b));
endmodule
