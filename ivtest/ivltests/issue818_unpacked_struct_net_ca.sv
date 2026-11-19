module issue818_unpacked_struct_net_ca;
  typedef struct { logic a; logic [3:0] b; } record_t;
  typedef struct { record_t header; logic [2:0] data [2:1][0:1]; } packet_t;
  record_t source;
  packet_t packet_source;
  wire record_t direct, copied, positional, named, from_function;
  wire record_t constant_value = record_t'{1'bz, 4'b010x};
  wire packet_t packet, packet_copy;
  logic contend = 1'b0;
  logic [3:0] argument = 4'hb;
  int calls = 0;

  function automatic record_t make_record(input logic [3:0] value);
    calls++;
    return '{1'b0, value};
  endfunction

  assign direct = source;
  assign copied = direct;
  assign positional = '{source.a, source.b};
  assign named = record_t'{b: source.b, a: source.a};
  assign from_function = make_record(argument);
  assign direct.a = contend ? 1'b0 : 1'bz;
  assign packet = packet_source;
  assign packet_copy = packet;

  initial begin
    source.a = 1'b1;
    source.b = 4'h3;
    packet_source = '{'{1'b1, 4'ha}, '{'{3'b001, 3'bx10}, '{3'b011, 3'bz00}}};
    #1;
    if ({direct.a, direct.b, copied.a, copied.b,
         positional.a, positional.b, named.a, named.b} !== {4{5'b1_0011}})
      $fatal(1, "initial struct values");
    if ({from_function.a, from_function.b} !== 5'b0_1011 || calls != 1)
      $fatal(1, "initial function result or call count %0d", calls);
    if ({constant_value.a, constant_value.b} !== 5'bz_010x)
      $fatal(1, "constant net declaration assignment");
    if ({packet_copy.header.a, packet_copy.header.b,
         packet_copy.data[2][0], packet_copy.data[2][1],
         packet_copy.data[1][0], packet_copy.data[1][1]} !== 17'b1_1010_001_x10_011_z00)
      $fatal(1, "nested struct or fixed-array word order");

    source.b = 4'bz1x0;
    argument = 4'b0z1x;
    packet_source.data[2][1] = 3'b11z;
    #1;
    if ({direct.a, direct.b, copied.a, copied.b,
         positional.a, positional.b, named.a, named.b} !== {4{5'b1_z1x0}})
      $fatal(1, "four-state member update");
    if ({from_function.a, from_function.b} !== 5'b0_0z1x || calls != 2)
      $fatal(1, "updated function result or call count %0d", calls);
    if (packet_copy.data[2][1] !== 3'b11z || packet_copy.data[1][1] !== 3'bz00)
      $fatal(1, "fixed-array word update");

    contend = 1'b1;
    #1;
    if ({direct.a, direct.b, copied.a, copied.b} !== {2{5'bx_z1x0}})
      $fatal(1, "independent member driver contention");

    contend = 1'b0;
    #1;
    if ({direct.a, direct.b, copied.a, copied.b} !== {2{5'b1_z1x0}})
      $fatal(1, "independent member driver release");
    $display("PASSED");
  end
endmodule
