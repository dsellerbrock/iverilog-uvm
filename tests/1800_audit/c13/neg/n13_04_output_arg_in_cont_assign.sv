module top;
  function int f(output int o); o = 1; return 1; endfunction
  int q;
  wire [31:0] w;
  assign w = f(q);
endmodule
