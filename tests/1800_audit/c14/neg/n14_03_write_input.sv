module test;
  wire clk = 0;
  wire d = 0;
  clocking cb @(posedge clk);
    input d;
  endclocking

  initial cb.d <= 1'b1;
endmodule
