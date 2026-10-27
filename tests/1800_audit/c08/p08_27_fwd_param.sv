// IEEE 1800-2017/2023 §8.27: parameter overrides through a forward class typedef.
typedef class C;
module top; C#(1, real) v2; C#(.p(2), .T(real)) v3; C#() v4;
  initial begin
    v2 = new; v3 = new; v4 = new;
    v2.t = 1.5; v3.t = 2.25; v4.t = 1.5;
    $display("FP %0d %0d %0d %0.2f %0.2f %0d", v2.p, v3.p, v4.p, v2.t, v3.t, v4.t);
  end
endmodule
class C #(parameter p = 2, type T = int); T t; endclass
