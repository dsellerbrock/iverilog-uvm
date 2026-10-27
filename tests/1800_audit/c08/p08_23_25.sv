// IEEE 1800-2017 §§8.23–8.25.1 and 8.24; IEEE 1800-2023 §§8.24–8.25.1.
class S;
  static int count = 0;
  static function void inc(); count++; endfunction
endclass

class E;
  typedef enum {RED, GREEN} col_t;
endclass

class Outer;
  class Inner;
    int v = 7;
  endclass
endclass

class O;
  extern function int f(int a);
  extern task t(output int r);
endclass

function int O::f(int a);
  return a + 1;
endfunction

task O::t(output int r);
  r = 9;
endtask

class O2;
  typedef int T;
  extern function T g();
endclass

function O2::T O2::g();
  return 4;
endfunction

class C #(int p = 1, type T = int);
  extern static function T f();
endclass

function C::T C::f();
  return p + C::p;
endfunction

module p08_23_25;
  Outer::Inner oi;
  O o;
  int r;

  initial begin
    S::inc();
    S::inc();
    $display("SC1 %0d", S::count);
    $display("SC2 %0d", E::GREEN);

    oi = new;
    $display("SC3 %0d", oi.v);

    o = new;
    o.t(r);
    $display("OB1 %0d %0d", o.f(1), r);

    $display("OB2 %0d", O2::g());
    $display("PC1 %0d %0d", C#()::f(), C#(5)::f());
  end
endmodule
