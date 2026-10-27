module top;
  function int cf(int a); return a + $random; endfunction
  localparam int P = cf(2);
endmodule
