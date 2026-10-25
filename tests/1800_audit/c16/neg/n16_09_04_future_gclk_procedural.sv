module test;
  logic clk = 0;
  logic sig = 0;
  always #5 clk = ~clk;
  global clocking gclk @(posedge clk); endclocking

  initial begin
    // §16.9.4 allows future global-clock functions only in properties/sequences.
    if ($future_gclk(sig)) $display("illegal procedural future function");
  end
endmodule
