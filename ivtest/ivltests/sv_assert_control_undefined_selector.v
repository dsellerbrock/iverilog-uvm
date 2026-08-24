// An undefined generated-scope index is not a canonical hierarchy index.
// Preserving its source spelling is preferable to selecting a different,
// valid assertion instance.  Duplicate instances make a wrong G[0] fallback
// observable for both X and Z selectors.
module top;
  logic clk = 0;

  for (genvar i = 0; i < 2; i++) begin : G
    integer failures = 0;
    A: assert property (@(posedge clk) 1'b0) else failures++;
  end

  initial begin
    $assertoff(0, G[1'bx].A);
    $assertoff(0, G[1'bz].A);
    #1 clk = 1;
    #1 clk = 0;
    if (G[0].failures != 1 || G[1].failures != 1)
      $fatal(1, "undefined selector changed a valid instance: %0d/%0d",
             G[0].failures, G[1].failures);
    $display("PASSED");
  end
endmodule
