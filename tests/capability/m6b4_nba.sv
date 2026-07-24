// Sampled value must be the value BEFORE the NBA update in the same slot.
module top;
  bit clk = 0; logic v = 0; int hits = 0, miss = 0;
  always #5 clk = ~clk;
  always @(posedge clk) v <= 1;   // NBA in the same slot as the edge
  // At t=5 the preponed value of v is 0 -> property (v==0) must hold.
  ck: assert property (@(posedge clk) v == 0) hits++; else miss++;
  initial begin
    #26 $display("nba-sample: hits=%0d miss=%0d", hits, miss);
    // t=5: v preponed 0 (ok). t=15,25: v preponed 1 -> genuinely fails.
    if (hits >= 1) $display("PASS m6b4_nba (first edge saw preponed 0)");
    else           $display("FAIL m6b4_nba (saw post-NBA value at first edge)");
    $finish(0);
  end
endmodule
