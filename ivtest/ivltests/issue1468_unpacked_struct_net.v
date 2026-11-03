module issue1468_unpacked_struct_net;
  typedef struct {
    logic [3:0] defaulted = 4'h5;
    logic [1:0] driven;
    logic undriven;
    logic conflict;
  } packet_t;

  wire packet_t net_packet;

  assign net_packet.driven = 2'b10;
  assign net_packet.conflict = 1'b0;
  assign net_packet.conflict = 1'b1;

  initial begin
    #1;
    if (net_packet.defaulted !== 4'bzzzz)
      $fatal(1, "net struct member initializer was not ignored: %b",
             net_packet.defaulted);
    if (net_packet.driven !== 2'b10)
      $fatal(1, "net struct member driver mismatch: %b", net_packet.driven);
    if (net_packet.undriven !== 1'bz)
      $fatal(1, "undriven net struct member was not high impedance: %b",
             net_packet.undriven);
    if (net_packet.conflict !== 1'bx)
      $fatal(1, "net struct member drivers did not resolve: %b",
             net_packet.conflict);
    $display("PASSED");
    $finish;
  end
endmodule
