module top;
  typedef struct {
    byte length;
    shortint address;
    byte payload[];
    byte chksum;
  } Packet;
  typedef byte channel_type[$];

  Packet packet;
  channel_type channel;

  initial begin
    packet.length = 2;
    packet.address = 16'h1234;
    packet.payload = '{8'haa, 8'hbb};
    packet.chksum = 8'h11;
    channel = channel_type'(packet);
    if (channel.size() != 6 || channel[0] !== 8'h02
        || channel[1] !== 8'h12 || channel[2] !== 8'h34
        || channel[3] !== 8'haa || channel[4] !== 8'hbb
        || channel[5] !== 8'h11)
      $fatal(1, "struct-to-queue bit-stream cast failed");
    $display("PASS");
  end
endmodule
