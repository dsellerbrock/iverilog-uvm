interface i2;
  wire a;
  modport m1(input a);
  modport m2(output a);
endinterface
module m(i2.m1 p); endmodule
module t;
  i2 i();
  m u(.p(i.m2));
endmodule
