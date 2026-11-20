class issue3634_container;
  bit [7:0] queue_words[$];
  bit [7:0] dynamic_words[];
endclass

module issue3634;
  typedef struct packed {
    logic [7:0] sentinel;
    bit [7:0] member;
  } mixed_t;
  mixed_t mixed;
  mixed_t mixed_words [0:1];
  issue3634_container box = new;
  bit [1:0][7:0] packed_bits = 16'h1234;
  bit [7:0] bits = 8'h5a;
  logic [7:0] four_state = 8'h5a;
  logic [3:0] result;
  logic bit_result;
  logic unknown_base = 1'bx;
  integer base = 20;
  int calls = 0;

  function automatic integer get_base();
    calls++;
    return base;
  endfunction

  initial begin
    result = ++packed_bits[1][unknown_base +: 4];
    $display("unknown prefix ++ %h %b", packed_bits, result);
    result = ++bits[get_base() +: 4];
    $display("out of range ++ %h %b %0d", bits, result, calls);
    result = --bits[base -: 4];
    $display("out of range -- %h %b", bits, result);
    result = ++bits[11:8];
    $display("constant range ++ %h %b", bits, result);
    result = ++bits[4'bx +: 4];
    $display("constant X base ++ %h %b", bits, result);
    result = ++packed_bits[0][11:8];
    $display("constant range outside packed row ++ %h %b", packed_bits, result);
    result = packed_bits[1][unknown_base +: 4]++;
    $display("unknown postfix ++ %h %b", packed_bits, result);
    unknown_base = 1'bz;
    result = bits[unknown_base +: 4]--;
    $display("high impedance postfix -- %h %b", bits, result);
    bit_result = ++bits[unknown_base +: 1];
    $display("one-bit part-select ++ %h %b", bits, bit_result);
    bit_result = ++bits[unknown_base];
    $display("bit-select ++ %h %b", bits, bit_result);
    result = ++four_state[base +: 4];
    $display("four-state ++ %h %b", four_state, result);

    base = 0;
    result = ++bits[base +: 4];
    $display("valid prefix ++ %h %b", bits, result);
    result = bits[base +: 4]--;
    $display("valid postfix -- %h %b", bits, result);
    bits = 8'h5f;
    result = ++bits[base +: 4];
    $display("wraparound ++ %h %b", bits, result);

    bits = 8'haa;
    base = 6;
    result = bits[base +: 4]++;
    $display("partial postfix ++ %h %b", bits, result);

    mixed = 16'ha5aa;
    result = mixed.member[base +: 4]++;
    $display("mixed partial ++ %h %b", mixed, result);
    mixed_words[0] = 16'ha5aa;
    mixed_words[1] = 16'h5a55;
    result = mixed_words[0].member[base +: 4]++;
    $display("mixed array partial ++ %h %h %b", mixed_words[0], mixed_words[1], result);
    base = 8;
    result = ++mixed.member[base +: 4];
    $display("mixed out of range ++ %h %b", mixed, result);
    mixed = 16'b10100101_xxxx1010;
    base = 4;
    result = ++mixed.member[base +: 4];
    $display("mixed member conversion ++ %h %b", mixed, result);

    box.queue_words = '{8'ha5};
    box.dynamic_words = new[1];
    box.dynamic_words[0] = 8'ha5;
    base = 3;
    calls = 0;
    result = ++box.queue_words[get_base()][0 +: 4];
    $display("missing queue word ++ %h %b %0d %0d",
             box.queue_words[0], result, box.queue_words.size(), calls);
    result = --box.dynamic_words[get_base()][0 +: 4];
    $display("missing dynamic word -- %h %b %0d %0d",
             box.dynamic_words[0], result, box.dynamic_words.size(), calls);
    base = 6;
    result = box.queue_words[0][get_base() +: 4]++;
    $display("queue word partial ++ %h %b %0d", box.queue_words[0], result, calls);
  end
endmodule
