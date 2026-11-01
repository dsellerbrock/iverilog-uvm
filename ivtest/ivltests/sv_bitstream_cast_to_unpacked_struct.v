// IEEE 1800-2017/2023 6.24.3: unpacked struct destinations consume a
// bit stream in declaration order; the first unbounded member is greedy.
module sv_bitstream_cast_to_unpacked_struct;
  typedef struct { byte a; byte b; } fixed_s_t;
  typedef byte channel_t[$];
  typedef bit [7:0] bit_byte_t;
  typedef struct {
    byte length;
    shortint address;
    byte payload[];
    byte chksum;
  } Packet;
  typedef struct {
    bit_byte_t first;
    bit_byte_t payload[];
    bit_byte_t last;
  } BitPacket;
  typedef struct {
    bit_byte_t first;
    bit_byte_t payload[$];
    bit_byte_t last;
  } BitQueuePacket;

  fixed_s_t fixed_value;
  channel_t channel;
  logic [23:0] logic_bits;
  Packet packet;
  BitPacket bit_packet;
  BitQueuePacket bit_queue_packet;

  initial begin
    fixed_value = fixed_s_t'(16'h1234);
    if (fixed_value.a != 8'h12 || fixed_value.b != 8'h34)
      $fatal(1, "scalar-to-struct cast=%h %h", fixed_value.a, fixed_value.b);

    channel.push_back(8'h02);
    channel.push_back(8'h12);
    channel.push_back(8'h34);
    channel.push_back(8'hAA);
    channel.push_back(8'hBB);
    channel.push_back(8'h11);
    packet = Packet'(channel);
    if (packet.length != 2 || packet.address != 16'h1234
        || packet.payload.size() != 2 || packet.payload[0] != 8'hAA
        || packet.payload[1] != 8'hBB || packet.chksum != 8'h11)
      $fatal(1, "queue-to-Packet cast=%h/%h/%0d/%h/%h",
             packet.length, packet.address, packet.payload.size(),
             packet.payload[0], packet.chksum);

    logic_bits = 24'hx5a7x9;
    bit_packet = BitPacket'(logic_bits);
    bit_queue_packet = BitQueuePacket'(logic_bits);
    if (bit_packet.first != 8'h05 || bit_packet.payload.size() != 1
        || bit_packet.payload[0] != 8'hA7 || bit_packet.last != 8'h09
        || bit_queue_packet.first != 8'h05
        || bit_queue_packet.payload.size() != 1
        || bit_queue_packet.payload[0] != 8'hA7
        || bit_queue_packet.last != 8'h09)
      $fatal(1, "2-state struct cast failed X-to-0 coercion");

    $display("PASSED");
  end
endmodule
