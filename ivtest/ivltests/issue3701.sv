// IEEE 1800-2017/2023 8.20 and 8.25: an override of a prototype in a
// parameterized base is checked against that specialization's types, and
// legal overrides keep compiling. A base named through a forward
// `typedef class' declared later keeps its #(...) parameter values: P8's
// T is logic [7:0], not the default int.
typedef class fwd_proxy;
class E; endclass
class F extends E; endclass

class P8 extends fwd_proxy #(logic [7:0]);
  function logic [7:0] pass(logic [7:0] v); return v; endfunction
endclass

virtual class proxy #(type T = int);
  pure virtual function void f(T s, ref T q[$]);
  pure virtual function T make();
endclass

class fwd_proxy #(type T = int);
  T v;
  virtual function T pass(T v); return v; endfunction
endclass

class PE extends proxy #(E);
  function void f(E s, ref E q[$]); q.push_back(s); endfunction
  function F make(); F r = new; return r; endfunction
endclass

class PF extends fwd_proxy #(F);
  function F pass(F v); return v; endfunction
endclass

module issue3701;
  P8 p8;
  PE pe;
  E q[$];
  E e;
  proxy #(E) base;
  initial begin
    p8 = new;
    pe = new;
    e = new;
    base = pe;
    base.f(e, q);
    p8.v = 8'hff;
    p8.v = p8.v + 1;
    if ($bits(p8.v) == 8 && p8.v == 0 && p8.pass(8'h5a) == 8'h5a
        && q.size() == 1 && base.make() != null)
      $display("PASSED");
    else
      $display("FAILED: bits=%0d v=%0d q=%0d", $bits(p8.v), p8.v, q.size());
  end
endmodule
