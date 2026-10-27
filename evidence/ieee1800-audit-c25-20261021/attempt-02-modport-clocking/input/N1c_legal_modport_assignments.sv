interface PBus #(parameter WIDTH=8);
  logic req, grant;
  logic [WIDTH-1:0] addr, data;
  modport phy(input addr, ref data);
endinterface
module top;
  PBus #(16) p16();
  PBus #(32) p32();
  virtual PBus #(16) v16;
  virtual PBus #(16).phy v16_phy;
  virtual PBus #(32).phy v32_phy;
  initial begin
    v16 = p16;
    v16_phy = v16;
    v32_phy = p32;
    $display("legal");
    $finish;
  end
endmodule
