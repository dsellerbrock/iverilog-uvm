module test;
  property p_typed(logic [3:0] arg);
    arg == 4'h5;
  endproperty

  initial $finish;
endmodule
