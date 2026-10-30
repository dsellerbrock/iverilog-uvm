module issue726_property_local_input_formal;
  logic clk = 0;
  logic a = 1;
  int actual = 1;
  int failures = 0;
  always #5 clk = ~clk;

  property p(local input int value);
    a ##1 (a && (value == 1));
  endproperty

  property q(local input int value = 1);
    a ##1 (a && (value == 1));
  endproperty

  ap: assert property (@(posedge clk) p(actual))
    else failures++;
  aq: assert property (@(posedge clk) q())
    else failures++;

  initial begin
    #6 actual = 2;
    #15;
    if (failures != 0)
      $fatal(1, "local property input formal failed: %0d", failures);
    $display("PASS");
    $finish;
  end
endmodule
