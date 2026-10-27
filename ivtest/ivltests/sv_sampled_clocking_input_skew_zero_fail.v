module main;
  logic clk = 0;
  logic d = 0;
  always #5 clk = ~clk;
  clocking cb @(posedge clk);
    input #0 d;
  endclocking
  always @(posedge clk) begin
    if ($past(cb.d)) $display("unexpected");
  end
endmodule
