class C #(int N = 1); endclass
class T #(type P = int); endclass
module issue3112_fail;
  C#(1) a;
  C#(2) b;
  T#(int) x;
  T#(byte) y;
  function C#(2) get_b(); return b; endfunction
  initial begin
    a = b;
    x = y;
    a = get_b();
    a = 1 ? b : b;
  end
endmodule
