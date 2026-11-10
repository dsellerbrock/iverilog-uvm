// IEEE 1800-2023 39.4.2: "The cbAssertionStart, cbAssertionSuccess, and
// cbAssertionFailure callbacks may also be registered on a sequence
// instance or a property instance." The whole property of ap is the
// property instance p, of as the sequence instance s, of ap2 the
// parameterized property instance pa(a); a3 has none.
// Edges are at 5, 15, 25, 35; b is 0 only at 25.
module sva_vpi_instance_cb;
  logic clk = 0, a = 1, b = 1;
  always #5 clk = ~clk;
  property p; a |=> b; endproperty
  sequence s; a ##1 b; endsequence
  property pa(x); x |=> b; endproperty
  ap: assert property (@(posedge clk) p) else ;
  as: assert property (@(posedge clk) s) else ;
  ap2: assert property (@(posedge clk) pa(a)) else ;
  a3: assert property (@(posedge clk) a) else ;
  initial begin
    #1 $sva_instance_probe;
    #19 b = 0;
    #10 b = 1;
    #10 $finish;
  end
endmodule
