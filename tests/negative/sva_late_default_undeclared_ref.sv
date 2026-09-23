// NEG-DIAG: default clocking block `nosuch' is not declared
// A later but invalid default reference cannot rescue an earlier assertion.
module sva_late_default_undeclared_ref(input logic clk, a);
  check: assert property (a |=> !a);
  default clocking nosuch;
endmodule
