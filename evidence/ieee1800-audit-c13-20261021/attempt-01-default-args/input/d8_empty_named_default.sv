module d8_empty_named_default;
  function automatic int f(input int a = 5); return a; endfunction
  initial $display("D8 f(.a())=%0d", f(.a()));
endmodule
