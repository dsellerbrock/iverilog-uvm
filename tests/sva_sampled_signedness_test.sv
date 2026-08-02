module sva_sampled_signedness_test;
  bit clk, rst_n, trig;
  logic signed [7:0] signed_value;
  int passes, failures;

  always #5 clk = ~clk;

  assert property (@(posedge clk) disable iff (!rst_n)
                   trig |=> $past(signed_value) < 0)
    passes++; else failures++;

  initial begin
    rst_n = 0;
    signed_value = -8'sd2;
    @(negedge clk);
    rst_n = 1;
    trig = 1;
    @(negedge clk);
    trig = 0;
    signed_value = 8'sd3;
    repeat (2) @(negedge clk);
    if (passes != 1 || failures != 0)
      $fatal(1, "$past lost signedness: %0d/%0d", passes, failures);
    $display("PASS: sampled-value history preserves signedness");
    $finish;
  end
endmodule
