// IEEE 1800-2017/2023 8.20: legal overrides keep compiling. A derived
// class return type is allowed, default expressions need not match (only
// their presence), and a typedef of int is a matching type for int.
class R; endclass
class S extends R; endclass
typedef int T;
class Base;
  virtual function R make(); R r = new; return r; endfunction
  virtual function int scale(int a = 1); return a; endfunction
  virtual function int same(int x); return x; endfunction
endclass
class Derived extends Base;
  function S make(); S s = new; return s; endfunction
  function int scale(int a = 2); return a * 10; endfunction
  function int same(T x); return x + 1; endfunction
endclass
module top;
  initial begin
    Base b;
    Derived d = new;
    b = d;
    $display("scale=%0d same=%0d", b.scale(3), b.same(4));
    if (b.scale(3) == 30 && b.same(4) == 5) $display("PASSED");
    else $display("FAILED");
  end
endmodule
