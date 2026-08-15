module sv_nettype_direct;
  nettype logic [7:0] byte_net;
  byte_net data;

  initial begin
    if ($bits(data) != 8)
      $fatal(1, "direct nettype width mismatch");
    $display("PASSED");
  end
endmodule
