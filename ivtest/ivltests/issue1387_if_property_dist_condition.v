module issue1387_if_property_dist_condition;
  logic clk = 0, sel = 1, a = 1, b = 1;
  int failures = 0;

  always #5 clk = ~clk;

  ap_no_else: assert property (@(posedge clk)
    if (sel dist {1'b1 := 1}) a) else failures++;
  ap_else: assert property (@(posedge clk)
    if (sel dist {1'b1 := 1}) a else b) else failures++;

  initial begin
    repeat (2) @(negedge clk);
    if (failures != 0) $fatal(1, "if property dist condition failed");
    $display("if-property-dist-condition");
    $display("PASSED");
    $finish(0);
  end
endmodule
