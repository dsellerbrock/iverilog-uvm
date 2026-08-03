// Constant expressions, including module parameters, are legal sequence
// delay and repetition bounds (IEEE 1800-2017 16.9.2).
module param_bounds;
  parameter int N = 2;
  logic clk = 0, a = 0, b = 0;
  always #5 clk = ~clk;

  cw: cover property (@(posedge clk) a |-> ##[0:N] b);       // inst 0
  cr: cover property (@(posedge clk) a[* (N+1)]);            // inst 1

  initial begin
    @(negedge clk) a=1;
    @(negedge clk) a=1;
    @(negedge clk) a=1; b=1;
    @(negedge clk) a=0; b=0;
    @(negedge clk);
    $display("parameter bounds covers=%0d,%0d", _ivl_sva0_cnt0,
             _ivl_sva1_cnt0);
    $finish(0);
  end
endmodule
