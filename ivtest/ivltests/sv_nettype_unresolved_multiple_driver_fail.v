module sv_nettype_unresolved_multiple_driver_fail;
  nettype logic [3:0] nibble_net;
  nibble_net data;

  assign data = 4'ha;
  assign data = 4'h5;
endmodule
