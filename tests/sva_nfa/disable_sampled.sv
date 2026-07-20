// M9-NFA dual-run seed: disable iff + $rose sampled-value rewrite
// through the automaton path.
module disable_sampled;
  logic clk = 0, rst = 0, a = 0, b = 0;
  always #5 clk = ~clk;

  d1: assert property (@(posedge clk) disable iff (rst) $rose(a) |=> b)
        $display("d1 PASS at %0t", $time);
        else $display("d1 FAIL at %0t", $time);

  initial begin
    @(negedge clk) a = 1;            // rose@15 -> b@25?
    @(negedge clk);                  // b=0: FAIL@25
    @(negedge clk) a = 0;
    @(negedge clk) rst = 1; a = 1;   // rose@45 but disabled
    @(negedge clk);                  // disabled: silent
    @(negedge clk) rst = 0; a = 0;
    @(negedge clk) a = 1;            // rose@75 -> b@85
    @(negedge clk) b = 1;            // PASS@85
    @(negedge clk);
    $finish(0);
  end
endmodule
