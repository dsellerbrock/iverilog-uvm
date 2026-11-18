module issue3634;
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
    base = 6;
    result = bits[base +: 4]++;
    $display("partial postfix ++ %h %b", bits, result);
  end
endmodule
