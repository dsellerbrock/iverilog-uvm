`timescale 1ns/1ns
interface hif;
  logic x;
  assign x = top.g;
endinterface
module top;
  logic g = 1'b1;
  hif h();
  virtual hif vh;
  initial begin
    vh = h;
    #1 $display("%b", vh.x);
  end
endmodule
