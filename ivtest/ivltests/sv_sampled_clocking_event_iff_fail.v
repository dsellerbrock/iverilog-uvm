module main;
  logic clk = 0;
  logic en = 0;
  logic d = 0;
  always #5 clk = ~clk;
  clocking cb @(posedge clk);
    input #1step d;
  endclocking
  always @(posedge clk iff en) begin
    if ($past(cb.d)) $display("unexpected");
  end
endmodule
