interface P; logic a; modport m(input a); endinterface
module t;
  P p();
  virtual P v;
  virtual P.m vm;
  initial begin vm = p; v = vm; end
endmodule
