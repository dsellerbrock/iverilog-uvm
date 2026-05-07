// G59: global clocking block syntax (IEEE 1800-2017 §14.12)
// Global clocking semantics not yet modelled; parse accepted and ignored.
module top;
  logic clk;
  global clocking gcb @(posedge clk);
  endclocking
  initial begin
    $display("PROBE_OK_global_clocking");
    $finish;
  end
endmodule
