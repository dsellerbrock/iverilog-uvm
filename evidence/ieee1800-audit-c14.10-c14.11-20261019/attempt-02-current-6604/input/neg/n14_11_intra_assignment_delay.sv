module test;
  logic clk = 0;
  logic a, b;
  logic data;
  always #5 clk = ~clk;

  default clocking cb @(posedge clk);
    input data;
  endclocking

  initial a = ##1 b;
endmodule
