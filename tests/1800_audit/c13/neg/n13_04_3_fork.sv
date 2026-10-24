module top;
  function int cf(int a); fork join_none return a; endfunction
  localparam int P = cf(2);
endmodule
