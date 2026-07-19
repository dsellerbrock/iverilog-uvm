// M9-NFA stage B.5: fixed-length `throughout` keeps the legacy
// source-level lowering (a plain chain) under both engines -> verdict
// parity.
module throughout_fixed;
  logic clk = 0, g=0, x=0, y=0, z=0;
  always #5 clk = ~clk;

  t1: assert property (@(posedge clk) g throughout (x ##1 y ##1 z))
        else $display("TFAIL at %0t", $time);

  initial begin
    @(negedge clk) x=1; g=1;
    @(negedge clk) x=0; y=1; g=1;
    @(negedge clk) y=0; z=1; g=1;   // g held all 3 -> ok
    @(negedge clk) z=0; g=0;
    @(negedge clk) x=1; g=1;
    @(negedge clk) x=0; y=1; g=0;   // g drops mid -> fail
    @(negedge clk) y=0; z=1;
    @(negedge clk) z=0;
    repeat(2) @(negedge clk);
    $finish(0);
  end
endmodule
