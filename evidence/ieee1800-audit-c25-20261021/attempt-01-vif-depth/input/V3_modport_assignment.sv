`timescale 1ns/1ns
interface mif;
  logic a, b;
  modport drv(output a, input b);
endinterface
module top;
  mif m();
  virtual mif.drv vd;
  initial begin
    vd = m;
    vd.a = 1'b1;
    #1 $display("%b", m.a);
  end
endmodule
