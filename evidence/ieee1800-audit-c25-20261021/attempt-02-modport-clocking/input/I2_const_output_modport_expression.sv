interface I;
  const int x = 1;
  modport C (output .Q(x));
endinterface
module M(interface i);
  initial i.Q = 1;
endmodule
module top;
  I i1();
  M u1(i1.C);
endmodule
