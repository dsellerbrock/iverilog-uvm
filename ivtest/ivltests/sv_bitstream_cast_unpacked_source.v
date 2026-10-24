module sv_bitstream_cast_unpacked_source;
  typedef logic [15:0] p16_t;
  typedef struct {
    byte a;
    byte b;
  } pair_t;
  typedef struct {
    byte len;
    byte payload[];
    byte tail;
  } packet_t;
  typedef byte byte_q_t[$];

  pair_t pair;
  packet_t packet;
  p16_t packed_pair;
  byte_q_t packet_bytes;
  string text;
  byte_q_t text_bytes;

  initial begin
    pair.a = 8'h12;
    pair.b = 8'h34;
    packed_pair = p16_t'(pair);
    if (packed_pair !== 16'h1234)
      $fatal(1, "struct-to-packed cast: %h", packed_pair);

    packet.len = 4;
    packet.payload = new[4];
    packet.payload[0] = 8'h12;
    packet.payload[1] = 8'h34;
    packet.payload[2] = 8'h56;
    packet.payload[3] = 8'h78;
    packet.tail = 8'haa;
    packet_bytes = byte_q_t'(packet);
    if (packet_bytes.size() != 6
        || packet_bytes[0] !== 8'd4
        || packet_bytes[1] !== 8'h12
        || packet_bytes[2] !== 8'h34
        || packet_bytes[3] !== 8'h56
        || packet_bytes[4] !== 8'h78
        || packet_bytes[5] !== 8'haa)
      $fatal(1, "struct-to-queue cast has wrong stream contents");

    text = "AB";
    text_bytes = byte_q_t'(text);
    if (text_bytes.size() != 2
        || text_bytes[0] !== 8'd65
        || text_bytes[1] !== 8'd66)
      $fatal(1, "string-to-queue cast has wrong stream contents");

    $display("PASSED");
  end
endmodule
