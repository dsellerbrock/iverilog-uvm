module p28_strength_reduce;
  wire pw, o1, o2;

  pullup(pw);
  rnmos r(o1, pw, 1'b1);
  cmos c(o2, 1'b0, 1'b1, 1'b0);

  initial #1 $display("R %v %v", o1, o2);
endmodule
