interface P #(parameter W=8); logic [W-1:0] a; endinterface
module t;
  P #(16) p16();
  P #(32) p32();
  virtual P #(16) v16;
  initial v16 = p32;
endmodule
