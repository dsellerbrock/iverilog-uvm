module p28_switch_notri;
  wire n1, n2, r1, t1, t2;
  reg d = 1, g = 1;
  supply1 vdd;

  nmos  m1(n1, d, g);
  pmos  m2(n2, d, g);
  rnmos m3(r1, vdd, g);
  tran  s1(t1, t2);
  assign t1 = 1'b0;

  initial #1 $display("S %v %v %v %v", n1, n2, r1, t2);
endmodule
