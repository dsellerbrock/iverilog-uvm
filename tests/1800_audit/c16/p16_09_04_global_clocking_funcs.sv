// IEEE 1800-2017/2023 §16.9.4: global-clock past sampled-value function.
module test;
  logic clk = 0;
  logic sig = 0;
  always #5 clk = ~clk;

  global clocking gclk @(posedge clk); endclocking

  // The implication avoids depending on the first global-clock history value.
  assert property (@($global_clock) 1'b1 |=> ($past_gclk(sig) === 1'b0))
    else $fatal(1, "$past_gclk did not return the prior global-clock sample");

  initial begin
    #30;
    $display("PASSED: §16.9.4 global clocking past function");
    $finish(0);
  end
endmodule
