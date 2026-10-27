interface PBus #(parameter WIDTH=8);
  logic req, grant;
  logic [WIDTH-1:0] addr, data;
  modport phy(input addr, ref data);
endinterface
module top;
  PBus #(16) p16();
  virtual PBus #(16) v16;
  virtual PBus #(16).phy v16_phy;
  initial v16 = v16_phy;
endmodule
