module top;
  int g;
  function int cf(int a); return a + g; endfunction
  localparam int P = cf(2);
endmodule
