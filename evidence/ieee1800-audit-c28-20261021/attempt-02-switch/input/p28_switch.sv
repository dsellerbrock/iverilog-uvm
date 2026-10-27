module p28_switch;
  wire n1, n2, r1, t1, t2;
  trireg (medium) cap;
  reg d = 1, g = 1, en = 1;
  supply1 vdd;

  nmos  m1(n1, d, g);          // strong 1 passed
  pmos  m2(n2, d, g);          // gate 1 -> off -> z
  rnmos m3(r1, vdd, g);        // supply reduced to pull: Pu1
  tran  s1(t1, t2);
  assign t1 = 1'b0;            // bidirectional: t2 sees St0
  bufif1 drv(cap, d, en);

  initial begin
    #1 $display("S %v %v %v %v", n1, n2, r1, t2);
    #1 en = 0;
    #1 $display("C1 %v", cap);
  end
endmodule
