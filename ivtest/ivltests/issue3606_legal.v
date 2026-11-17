class C #(int N = 1);
  typedef int T;
  C::T value;
  extern function void f();
  extern function T get();
endclass
function void C::f();
  C::T x;
  x = 5;
endfunction
function C::T C::get();
  return 5;
endfunction
typedef C alias_t;
class D;
  typedef int T;
endclass
module top;
  alias_t::T x;
  D::T y;
  alias_t obj;
  initial begin
    x = 42; y = 7;
    obj = new;
    if (x != 42 || y != 7 || obj.get() != 5) $fatal(1, "wrong values");
    $display("PASS");
  end
endmodule
