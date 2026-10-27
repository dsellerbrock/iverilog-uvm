module d7_no_outer_a;
  function automatic int k(input int a = 1, input int b = a + 1); return b; endfunction
  initial $display("D7 no_outer_a=%0d", k());
endmodule
