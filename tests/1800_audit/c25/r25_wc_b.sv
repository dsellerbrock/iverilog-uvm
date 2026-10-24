interface simple_bus(input logic clk);
  logic req;
endinterface : simple_bus
module memMod(simple_bus sb_intf);
  initial #1 $display("B clk=%b", sb_intf.clk);
endmodule
module top;
  logic clk = 0;
  simple_bus sb_intf(clk);
  memMod mem(.*);
endmodule
