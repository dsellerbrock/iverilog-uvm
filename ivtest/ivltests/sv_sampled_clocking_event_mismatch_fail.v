module main;
  logic clk = 0;
  logic d = 0;
  logic other_sig = 0;
  always #5 clk = ~clk;
  clocking cb @(negedge clk);
    input #1step d;
  endclocking
  always @(posedge clk) begin
    if ($rose(cb.d & other_sig)) $display("unexpected");
  end
endmodule
