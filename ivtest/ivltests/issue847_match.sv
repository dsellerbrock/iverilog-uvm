typedef int T;
class C;
  typedef int T;
  extern function void f(T x);
  extern task t(T x);
endclass
function void C::f(C::T x); endfunction
task C::t(C::T x); endtask
class D;
  extern function void f(T x);
endclass
function void D::f(T x); endfunction
module main;
  initial $display("PASS matched T resolution");
endmodule
