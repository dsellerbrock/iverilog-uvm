module sv_default_disable_duplicate_fail;
  logic r1=0, r2=0;
  default disable iff (r1);
  default disable iff (r2);
  initial $finish;
endmodule
