checker sample_checker(input logic b, input logic clk,
                       output logic z, output logic v);
  logic seen = 0;
  always_ff @(posedge clk) begin
    assert (seen || !b) else $fatal(1, "checker always_ff assert was not sampled");
    z <= b;
    seen <= 1;
  end
  always_comb v = b;
endchecker

module sv_checker_always_ff_sample;
  logic b = 0;
  logic clk = 0;
  logic z, v, module_z;

  sample_checker check_b(b, clk, z, v);
  always_ff @(posedge clk) module_z <= b;

  initial begin
    #1 b = 1; clk = 1;
    #1 $display("first checker_z=%0b v=%0b module_z=%0b", z, v, module_z);
    if (z !== 0 || v !== 1 || module_z !== 1)
      $fatal(1, "first checker sample mismatch");
    #1 clk = 0;
    #1 clk = 1;
    #1 $display("next checker_z=%0b v=%0b module_z=%0b", z, v, module_z);
    if (z !== 1 || v !== 1 || module_z !== 1)
      $fatal(1, "next checker sample mismatch");
    $display("PASSED");
    $finish;
  end
endmodule
