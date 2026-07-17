// M9C-live negative: unbounded `eventually' is not legal SVA (it must
// carry a cycle range); use `s_eventually'. Must be rejected.
module top; logic clk=0,p;
  assert property (@(posedge clk) eventually p);
endmodule
