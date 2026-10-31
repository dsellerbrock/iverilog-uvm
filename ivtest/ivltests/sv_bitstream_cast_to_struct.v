typedef struct { byte a; byte b; } fixed_t;
typedef struct {
  byte length;
  shortint address;
  byte payload[];
  byte chksum;
} Packet;
typedef byte byte_queue_t[$];

module sv_bitstream_cast_to_struct;
  int errors;
  fixed_t fixed_value;
  Packet packet;
  byte_queue_t bytes;
  logic [15:0] four_state_source;
  typedef struct { bit [7:0] a; bit [7:0] b; } two_state_t;
  two_state_t two_state_value;

  initial begin
    fixed_value = fixed_t'(16'h1234);
    if (fixed_value.a !== 8'h12 || fixed_value.b !== 8'h34) begin
      errors++;
      $display("FAILED: scalar stream to fixed struct");
    end

    bytes = '{2, 8'h12, 8'h34, 8'haa, 8'hbb, 8'h11};
    packet = Packet'(bytes);
    if (packet.length !== 2 || packet.address !== 16'h1234
        || packet.payload.size() != 2 || packet.payload[0] !== 8'haa
        || packet.payload[1] !== 8'hbb || packet.chksum !== 8'h11) begin
      errors++;
      $display("FAILED: greedy byte queue stream to Packet");
    end

    four_state_source = 16'hx234;
    two_state_value = two_state_t'(four_state_source);
    if (two_state_value.a !== 8'h02 || two_state_value.b !== 8'h34) begin
      errors++;
      $display("FAILED: four-state stream to two-state struct coercion");
    end

    if (errors == 0)
      $display("PASSED");
    else
      $fatal(1, "FAILED -- %0d mismatches", errors);
  end
endmodule
