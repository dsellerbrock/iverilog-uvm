// IEEE 1800-2023 §8.27: parameter overrides through a forward class typedef.
typedef class C;
module top; C#(1, real) v2; C#(.p(2), .T(real)) v3;
  initial begin v2 = new; v3 = new; $display("FP %0d %0d %0d", v2.p, v3.p, $bits(v2.t)); end
endmodule
class C #(parameter p = 2, type T = int); T t; endclass
