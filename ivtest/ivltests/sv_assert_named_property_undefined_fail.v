// Companion negative to sv_assert_named_property_forward_ref.v: a property
// name that is genuinely never declared anywhere in the module (not a
// forward reference to a later declaration) must still be rejected as an
// unresolved identifier, unchanged by the forward-reference fix.
module main;
  bit clk = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  ap: assert property (this_property_is_never_declared);
endmodule
