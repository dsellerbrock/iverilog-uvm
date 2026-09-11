class state_operand_item;
  bit [7:0] value;
endclass
module sv_compound_four_state_operand;
  bit [7:0] value;
  logic [7:0] unknown_value, four_state;
  state_operand_item h;
  int calls;
  function automatic logic [7:0] rhs();
    calls++;
    return 'x;
  endfunction
  initial begin
    unknown_value = 'x;
    value = 1;
    value += unknown_value;
    if (value !== 0) $fatal(1, "addition X propagation");
    value = 1;
    value -= unknown_value;
    if (value !== 0) $fatal(1, "subtraction X propagation");
    value = 7;
    value *= unknown_value;
    if (value !== 0) $fatal(1, "multiplication X propagation");
    value = 7;
    value /= unknown_value;
    if (value !== 0) $fatal(1, "division X propagation");
    value = 7;
    value %= unknown_value;
    if (value !== 0) $fatal(1, "remainder X propagation");
    value = 8'hff;
    value ^= 8'bx0x0x0x0;
    if (value !== 8'h55) $fatal(1, "bitwise known bits");
    value = 8'hff;
    value &= 8'b1x1x1x1x;
    if (value !== 8'haa) $fatal(1, "AND known bits");
    value = 8'h00;
    value |= 8'b1z1z1z1z;
    if (value !== 8'haa) $fatal(1, "OR known bits");
    value = 8'hff;
    value >>= unknown_value;
    if (value !== 0) $fatal(1, "unknown shift count");
    value = 1;
    value += rhs();
    if (value !== 0 || calls != 1) $fatal(1, "RHS function once");
    four_state = 1;
    four_state += unknown_value;
    if (four_state !== 8'hxx) $fatal(1, "four-state destination");
    value = 8'b1x1z1x1z;
    if (value !== 8'haa) $fatal(1, "ordinary assignment conversion");
    value = 3;
    value += 2;
    if (value !== 5) $fatal(1, "known arithmetic");
    h = new;
    h.value = 1;
    h.value += unknown_value;
    if (h.value !== 0) $fatal(1, "property result conversion");
    $display("PASSED");
  end
endmodule
