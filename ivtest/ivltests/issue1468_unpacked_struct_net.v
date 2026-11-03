module issue1468_unpacked_struct_net;
  typedef struct {
    logic [3:0] undriven;
    logic [3:0] driven;
  } packet_t;
  typedef struct {
    logic [3:0] member = 4'h5;
  } default_packet_t;

  wire packet_t packet;
  wire default_packet_t default_packet;

  assign packet.driven = 4'ha;

  initial begin
    #1;
    if (packet.undriven !== 4'hz)
      $fatal(1, "undriven member was %h, expected z", packet.undriven);
    if (packet.driven !== 4'ha)
      $fatal(1, "driven member was %h, expected a", packet.driven);
    if (default_packet.member !== 4'hz)
      $fatal(1, "member initializer was not ignored: %h", default_packet.member);
    $display("PASS");
  end
endmodule
