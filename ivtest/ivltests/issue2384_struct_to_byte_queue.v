module issue2384_struct_to_byte_queue;
  typedef struct {
    byte length;
    shortint address;
    byte payload[];
    byte chksum;
  } packet_t;
  typedef byte byte_queue_t[$];

  packet_t packet;
  byte_queue_t channel;

  initial begin
    packet.length = 2;
    packet.address = 16'h1234;
    packet.payload = '{8'haa, 8'hbb};
    packet.chksum = 8'h11;
    channel = byte_queue_t'(packet);

    if (channel.size() != 6
        || channel[0] !== 8'h02
        || channel[1] !== 8'h12
        || channel[2] !== 8'h34
        || channel[3] !== 8'haa
        || channel[4] !== 8'hbb
        || channel[5] !== 8'h11)
      $fatal(1, "bit-stream cast lost struct members: size=%0d", channel.size());
    $display("PASSED");
  end
endmodule
