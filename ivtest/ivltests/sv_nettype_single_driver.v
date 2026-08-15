module sv_nettype_single_driver;
  nettype logic [3:0] nibble_net;
  logic [3:0] driver = 4'ha;
  nibble_net data;

  assign data = driver;

  initial begin
    #1;
    if (data !== 4'ha)
      $fatal(1, "single-driver nettype value mismatch: %h", data);
    $display("PASSED");
  end
endmodule
