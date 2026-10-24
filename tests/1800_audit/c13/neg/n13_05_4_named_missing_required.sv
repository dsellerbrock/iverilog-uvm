module top;
  function automatic int h(int a, int b = 2); return a; endfunction
  initial void'(h(.b(3)));
endmodule
