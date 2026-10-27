module main;
  logic clk = 0;
  logic [1:0] d = 0;
  always #5 clk = ~clk;
  clocking cb @(posedge clk);
    input mapped = d;
  endclocking
  always @(posedge clk) begin
    if ($past(cb.mapped[0])) $display("unexpected");
  end
endmodule
