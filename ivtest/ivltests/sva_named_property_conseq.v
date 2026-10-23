// IEEE 1800-2017/2023 16.12.1: a named property instance may be used
// as a property_expr operand, including as an implication consequent.
module sva_named_property_conseq;
  reg clk = 0;
  reg a = 0, b = 0, c = 0;
  integer failures = 0;

  always #5 clk = ~clk;

  property q1;
    $rose(a) |-> ##[1:5] b;
  endproperty

  always @(negedge clk)
    assert property ($fell(c) |=> q1)
      else failures = failures + 1;

  initial begin
    repeat (8) @(negedge clk);
    if (failures == 0) $display("PASSED");
    else $display("FAILED: failures=%0d", failures);
    $finish;
  end
endmodule
