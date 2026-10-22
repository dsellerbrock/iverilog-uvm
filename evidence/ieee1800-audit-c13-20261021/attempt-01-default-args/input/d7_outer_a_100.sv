module d7_outer_a_100;
  int a = 100;
  function automatic int k(input int a = 1, input int b = a + 1); return b; endfunction
  initial $display("D7 outer_a=%0d", k());
endmodule
