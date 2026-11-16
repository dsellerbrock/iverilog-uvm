interface bus;
  logic data;
  modport master(input data);
endinterface
module top;
  bus b();
  virtual interface bus assigned = b;
  virtual interface bus empty;
  virtual interface bus.master mp;
  virtual interface bus elements[1:2];
  initial #10 $finish;
endmodule
