module top;
  function automatic int h(int a = 1); return a; endfunction
  initial void'(h(.zz(3)));
endmodule
