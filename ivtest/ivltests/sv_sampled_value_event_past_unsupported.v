module main;
  logic clk = 0;
  logic [7:0] data = 0;

  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking

  initial forever @($past(data)) $display("unexpected $past event");
endmodule
