module d6_const_ref_variable_default;
  int gv;
  function automatic int cr(const ref int x = gv); return x; endfunction
  initial begin gv = 11; $display("D6 value=%0d", cr()); end
endmodule
