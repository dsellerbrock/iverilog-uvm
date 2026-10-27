interface E;
  integer I;
  logic Q;
  modport mp(input Q);
endinterface
module sub(E.mp i);
  initial i.I = 0;
endmodule
module t;
  E e();
  sub s(e.mp);
endmodule
