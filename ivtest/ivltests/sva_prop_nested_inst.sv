// IEEE 1800-2023 16.12: a named property may be instantiated anywhere a
// property_expr may be written, including as an operand of a property
// operator when its own body is a property operator.
// nb: b |=> p2(b) with p2(v) = a or (1'b1 |=> v) and a = 0 requires b two
//   ticks after each attempt that starts with b; b drops at 40, so the
//   attempts at 25 and 35 fail at 45 and 55.
// f7: F.7's own example (p1 -> p3 -> p1, with p3() an actual of p2). Every
//   obligation in it is an implication whose base case is vacuous here,
//   so no attempt fails.
module sva_prop_nested_inst;
  logic clk = 0, a = 0, b = 1;
  always #5 clk = ~clk;
  property p1(v);
    v |=> p2(p3());
  endproperty
  property p2(v);
    a or (1'b1 |=> v);
  endproperty
  property p3;
    p1(a && b);
  endproperty
  nb: assert property (@(posedge clk) b |=> p2(b))
    else $display("%0t nb fail", $time);
  f7: assert property (@(posedge clk) p1(b))
    else $display("%0t f7 fail", $time);
  initial begin
    #40 b = 0;
    #40 $display("done");
    $finish;
  end
endmodule
