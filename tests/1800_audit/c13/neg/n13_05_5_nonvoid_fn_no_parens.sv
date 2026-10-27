module top;
  function int g(); return 1; endfunction
  int x;
  initial x = g;
endmodule
