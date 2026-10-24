interface I; logic a; endinterface
module t;
  virtual I v;
  initial begin v.a = 1; $display("SURVIVED"); end
endmodule
