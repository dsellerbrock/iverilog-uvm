module test;
  wire clk = 0;
  wire a = 0;
  wire b = 0;
  clocking cb @(posedge clk);
    output out = a + b;
  endclocking
endmodule
