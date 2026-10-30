module tb;
  supply0 [1:0] supply_bus;
  assign (strong1,strong0) supply_bus = 2'b01;

  wire [1:0] ordinary_bus;
  assign (strong1,strong0) ordinary_bus = 2'b01;
endmodule
