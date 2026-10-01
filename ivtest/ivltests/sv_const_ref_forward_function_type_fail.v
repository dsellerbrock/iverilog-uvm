module sv_const_ref_forward_function_type_fail;
  logic [7:0] value;
  function automatic int read_nibble(const ref logic [3:0] x);
    return x;
  endfunction
  function automatic int forward(const ref logic [7:0] x);
    return read_nibble(x);
  endfunction
  initial $display("%0d", forward(value));
endmodule
