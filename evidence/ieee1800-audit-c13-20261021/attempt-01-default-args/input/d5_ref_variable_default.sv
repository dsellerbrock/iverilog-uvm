module d5_ref_variable_default;
  int gv;
  function void r(ref int x = gv); x = 7; endfunction
  initial begin gv = 2; r(); $display("D5 gv=%0d", gv); end
endmodule
