interface I; logic a; endinterface
module t;
  I i();
  virtual I v = i;
  wire w;
  assign w = v.a;
endmodule
