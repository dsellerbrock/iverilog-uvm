`timescale 1ns/1ns
interface pif #(parameter int W = 4);
  logic [W-1:0] d;
endinterface
module top;
  pif i();
  defparam i.W = 8;
  virtual pif #(8) v;
  initial begin
    v = i;
    $display("UNEXPECTED %0d", $bits(v.d));
  end
endmodule
