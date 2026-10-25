interface simple_bus;
  logic req;
endinterface : simple_bus
module memMod(simple_bus sb_intf, input logic clk);
  initial #1 $display("A req=%b", sb_intf.req);
endmodule
module top;
  logic clk = 0;
  simple_bus sb_intf();
  memMod mem(.*);
  initial sb_intf.req = 1;
endmodule
