// M9-NFA dual-run seed: final-position ##[m:n] window (both engines
// support it; the NFA lowers it as branch states).
module window_final;
  logic clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;

  w1: assert property (@(posedge clk) a |-> ##[1:2] b)
        $display("w1 PASS at %0t", $time);
        else $display("w1 FAIL at %0t", $time);

  initial begin
    @(negedge clk) a = 1;            // a@15: b@25 or b@35
    @(negedge clk) a = 0;
    @(negedge clk) b = 1;            // b@35: PASS@35
    @(negedge clk) b = 0; a = 1;     // a@45: b@55 or b@65
    @(negedge clk) a = 0;
    repeat (2) @(negedge clk);       // no b: FAIL@65
    @(negedge clk);
    $finish(0);
  end
endmodule
