// IEEE 1800-2023 17.8: a function in the right-hand side of a checker
// variable assignment shall not have output, inout or (non-const) ref
// arguments.
checker c(input bit a, input bit clk, output bit z);
  bit side, comb_value, ff_value;
  function automatic bit f_out(input bit x, output bit y);
    y = x;
    return x;
  endfunction
  function automatic bit f_inout(input bit x, inout bit y);
    y = x;
    return x;
  endfunction
  always_comb comb_value = f_out(a, side);
  always_ff @(posedge clk) ff_value <= !f_inout(a, side);
  assign z = comb_value ^ ff_value;
endchecker

module top;
  bit a = 1, clk, z;
  c ci(a, clk, z);
endmodule
