interface simple_bus;
  logic req;
endinterface : simple_bus
module memMod(simple_bus sb_intf);
  initial #1 $display("C req=%b", sb_intf.req);
endmodule
module top;
  simple_bus sb_intf();
  memMod mem(.sb_intf);
  initial sb_intf.req = 1;
endmodule
