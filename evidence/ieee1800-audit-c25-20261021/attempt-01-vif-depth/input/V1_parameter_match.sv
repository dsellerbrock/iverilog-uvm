`timescale 1ns/1ns
interface pif #(parameter int W = 4);
  logic [W-1:0] d;
endinterface
module top;
  pif #(8) i8();
  virtual pif #(8) v8;
  initial begin
    v8 = i8;
    $display("%0d", $bits(v8.d));
  end
endmodule
