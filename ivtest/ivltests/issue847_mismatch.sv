typedef int T;
class C;
  extern function void f(T x);
  extern task t(T x);
  typedef int T;
endclass
function void C::f(T x); endfunction
task C::t(T x); endtask
module main; endmodule
