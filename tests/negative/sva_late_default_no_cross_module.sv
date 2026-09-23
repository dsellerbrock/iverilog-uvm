// NEG-DIAG: concurrent assertion has no clocking event
// A default in one module must not clock an assertion in a sibling module.
module sva_late_default_clock_owner(input logic clk, a);
  check: assert property (a |=> !a);
  default clocking cb @(posedge clk); endclocking
endmodule

module sva_late_default_no_cross_module(input logic a);
  check: assert property (a |=> !a);
endmodule
