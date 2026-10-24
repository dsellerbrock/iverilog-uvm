module r06_19a_default_value;
  enum integer {IDLE=0, XX='x, S1='b01, S2='b10} st4;
  initial $display("INFO enum_integer_default=%b decimal=%0d", st4, st4);
endmodule
