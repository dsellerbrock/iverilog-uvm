interface A_Bus(input logic clk);
  logic sig;
  modport M2 (clocking cbx);
endinterface
module top;
  logic clk = 0;
  clocking cbx @(posedge clk);
    input clk;
  endclocking
  A_Bus b(clk);
endmodule
