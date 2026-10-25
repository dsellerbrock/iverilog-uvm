module test;
  wire clk = 0;
  wire d = 0;
  clocking @(posedge clk);
    input d;
  endclocking
endmodule
