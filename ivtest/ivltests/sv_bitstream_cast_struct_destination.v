typedef struct {
  byte length;
  shortint address;
  byte payload[];
  byte chksum;
} packet_t;

typedef struct {
  bit [3:0] two_state;
  logic [3:0] four_state;
} state_t;

typedef struct {
  byte first;
  byte second;
} pair_t;

typedef struct {
  byte members[2];
  byte tag;
} fixed_array_t;

typedef struct {
  byte payload[];
} payload_only_t;

class source_class;
  byte first;
  byte second;
endclass

module test;
  byte channel[$];
  byte fixed_source[2];
  byte empty_source[];
  packet_t packet;
  payload_only_t empty_value;
  state_t state_value;
  pair_t pair_from_struct;
  pair_t pair_from_class;
  pair_t pair_from_array;
  pair_t source_pair;
  fixed_array_t fixed_array_value;
  source_class source_object;
  logic [7:0] with_xz;

  initial begin
    channel.push_back(8'h02);
    channel.push_back(8'h12);
    channel.push_back(8'h34);
    channel.push_back(8'h56);
    channel.push_back(8'h78);
    channel.push_back(8'h11);

    packet = packet_t'(channel);
    if (packet.length !== 8'h02 || packet.address !== 16'h1234
        || packet.payload.size() != 2
        || packet.payload[0] !== 8'h56 || packet.payload[1] !== 8'h78
        || packet.chksum !== 8'h11)
      $fatal(1, "packet cast fields or greedy payload sizing are wrong");

    with_xz = 8'b10xz1010;
    state_value = state_t'(with_xz);
    if (state_value.two_state !== 4'b1000
        || state_value.four_state !== 4'b1010)
      $fatal(1, "struct cast did not preserve field ordering and 2-state coercion");

    fixed_array_value = fixed_array_t'(24'hA1B2C3);
    if (fixed_array_value.members[0] !== 8'hA1
        || fixed_array_value.members[1] !== 8'hB2
        || fixed_array_value.tag !== 8'hC3)
      $fatal(1, "fixed array member ordering is wrong");

    fixed_source[0] = 8'h17;
    fixed_source[1] = 8'hE2;
    pair_from_array = pair_t'(fixed_source);
    if (pair_from_array.first !== 8'h17
        || pair_from_array.second !== 8'hE2)
      $fatal(1, "fixed array source ordering is wrong");

    empty_value = payload_only_t'(empty_source);
    if (empty_value.payload.size() != 0)
      $fatal(1, "empty dynamic array source was not preserved as empty");

    source_pair.first = 8'hA5;
    source_pair.second = 8'h3C;
    pair_from_struct = pair_t'(source_pair);
    if (pair_from_struct.first !== 8'hA5
        || pair_from_struct.second !== 8'h3C)
      $fatal(1, "struct source cast did not preserve member order");

    source_object = new;
    source_object.first = 8'h69;
    source_object.second = 8'hD2;
    pair_from_class = pair_t'(source_object);
    if (pair_from_class.first !== 8'h69
        || pair_from_class.second !== 8'hD2)
      $fatal(1, "class source cast did not preserve property order");

    $display("PASSED");
  end
endmodule
