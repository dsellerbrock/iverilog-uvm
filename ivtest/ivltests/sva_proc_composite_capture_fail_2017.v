module sva_proc_composite_capture_fail;
  bit root, clk1, clk2, request, a, b;

  property p;
    (@(posedge clk1) 1'b1 |-> a) and (@(posedge clk2) 1'b1 |-> b);
  endproperty

  always @(posedge request)
    for (int i = 0; i < 2; i++)
      check_p: assert property (@(posedge root) disable iff (i == 1) 1'b1 |=> p);
endmodule
