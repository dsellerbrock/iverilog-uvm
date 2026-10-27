module main;
  bit clk = 0;
  logic d = 0;

  always #5 clk = ~clk;

  clocking cb @(posedge clk);
    input #1step d;
  endclocking

  // Clocking inputs already have their own #1step sample. Do not route one
  // through the procedural history sampler until that path can preserve it.
  always @(posedge clk) begin
    if ($past(cb.d)) $display("unexpected clocking-input sampled value");
  end
endmodule
