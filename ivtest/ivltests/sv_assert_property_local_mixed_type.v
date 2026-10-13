module sv_assert_property_local_mixed_type;
  logic clk = 0;
  int failures = 0;

  always #5 clk = ~clk;

  property mixed_integral_types;
    int a;
    logic [3:0] z;
    @(posedge clk)
      (1'b1, a = 1) ##1 (1'b1, z = a[3:0]) ##1 (z == 4'd1);
  endproperty

  property same_int_type;
    int a;
    int b;
    @(posedge clk)
      (1'b1, a = 3) ##1 (1'b1, b = a) ##1 (b == 3);
  endproperty

  property same_logic_type;
    logic [3:0] a;
    logic [3:0] b;
    @(posedge clk)
      (1'b1, a = 4'd5) ##1 (1'b1, b = a) ##1 (b == 4'd5);
  endproperty

  ap_mixed: assert property (mixed_integral_types) else failures++;
  ap_int: assert property (same_int_type) else failures++;
  ap_logic: assert property (same_logic_type) else failures++;

  initial begin
    repeat (6) @(negedge clk);
    if (failures != 0)
      $fatal(1, "mixed assertion-local declaration failures=%0d", failures);
    $display("PASSED");
    $finish;
  end
endmodule
