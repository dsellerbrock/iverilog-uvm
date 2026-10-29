module issue1386_nested_disable_iff_property_2017;
  logic clk=0, outer_reset=0, inner_reset=0, a=0;
  always #5 clk=~clk;
  property inner_p; disable iff (inner_reset) a; endproperty
  property outer_p; disable iff (outer_reset) inner_p; endproperty
  ap: assert property (@(posedge clk) outer_p) else $display("unexpected-failure");
  initial begin #6 a=1; #20 $finish(0); end
endmodule
