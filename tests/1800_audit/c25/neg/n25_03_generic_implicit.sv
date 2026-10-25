interface i; endinterface
module g(interface a); endmodule
module t;
  i a();
  g u(.*);
endmodule
