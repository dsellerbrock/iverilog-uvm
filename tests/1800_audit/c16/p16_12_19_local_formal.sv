module test;
  property p_local(local input int arg);
    arg == 7;
  endproperty

  initial $finish;
endmodule
