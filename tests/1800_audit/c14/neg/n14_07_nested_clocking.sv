module test;
  logic clk;
  clocking cb1 @(posedge clk);
    clocking cb2 @(posedge clk);
    endclocking
  endclocking
endmodule
