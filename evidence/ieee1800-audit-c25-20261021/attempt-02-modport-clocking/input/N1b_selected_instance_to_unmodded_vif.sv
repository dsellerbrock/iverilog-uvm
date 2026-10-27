interface PBus #(parameter WIDTH=8);
  logic req, grant;
  logic [WIDTH-1:0] addr, data;
  modport phy(input addr, ref data);
endinterface
module top;
  PBus #(32) p32();
  virtual PBus #(32) v32;
  initial v32 = p32.phy;
endmodule
