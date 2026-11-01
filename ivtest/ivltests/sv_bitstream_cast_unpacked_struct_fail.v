// This formerly expected the compiler's "not yet implemented" rejection.
// Both conversions are legal bit-stream casts under IEEE 1800-2017/2023 6.24.3.
module test;
  typedef struct { byte a; byte b; } fixed_t;
  typedef struct {
    byte length;
    shortint address;
    byte payload[];
    byte chksum;
  } Packet;
  typedef struct { bit [3:0] two_state; logic [3:0] four_state; } mixed_t;
  typedef byte channel_t[$];

  fixed_t fixed;
  Packet packet;
  mixed_t mixed;
  channel_t channel;

  initial begin
    fixed = fixed_t'(16'h1234);
    $display("fixed=%02h,%02h", fixed.a, fixed.b);

    mixed = mixed_t'(8'bxz10_1x0z);
    $display("mixed=%h,%b", mixed.two_state, mixed.four_state);

    channel = '{2, 8'h12, 8'h34, 8'haa, 8'hbb, 8'h11};
    packet = Packet'(channel);
    $display("packet=%0d,%04h,%0d,%02h,%02h,%02h",
             packet.length, packet.address, packet.payload.size(),
             packet.payload[0], packet.payload[1], packet.chksum);
  end
endmodule
