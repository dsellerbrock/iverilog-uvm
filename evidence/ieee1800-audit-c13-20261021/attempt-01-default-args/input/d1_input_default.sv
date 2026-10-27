module d1_input_default;
  function automatic int f(input int a = 5); return a; endfunction
  initial $display("D1 f()=%0d", f());
endmodule
