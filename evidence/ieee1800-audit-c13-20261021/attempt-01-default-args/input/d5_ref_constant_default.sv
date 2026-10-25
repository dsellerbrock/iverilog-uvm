module d5_ref_constant_default;
  function void r(ref int x = 5); x = 7; endfunction
  initial r();
endmodule
