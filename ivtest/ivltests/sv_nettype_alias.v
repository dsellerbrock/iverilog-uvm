module sv_nettype_alias;
  nettype logic [3:0] nibble_net;
  nettype nibble_net nibble_alias;
  nibble_alias data;

  initial begin
    if ($bits(data) != 4)
      $fatal(1, "nettype alias width mismatch");
    $display("PASSED");
  end
endmodule
