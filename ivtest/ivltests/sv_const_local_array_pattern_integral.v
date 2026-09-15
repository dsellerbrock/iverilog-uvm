module sv_const_local_array_pattern_integral;
  function automatic int checked;
    logic signed [3:0] signed_words[2:3] = '{8'hff, 8'h07};
    bit [3:0] two_state[-1:0] = '{4'hx, 8'h1f};
    signed_words = '{8'hfe, 8'h09};
    if (signed_words[2] !== -2 || signed_words[3] !== -7) return 0;
    if (two_state[-1] !== 0 || two_state[0] !== 4'hf) return 0;
    return 1;
  endfunction
  localparam int OK = checked();
  initial begin
    if (!OK || !checked()) $fatal(1, "integral array conversion mismatch");
    $display("PASSED");
  end
endmodule
