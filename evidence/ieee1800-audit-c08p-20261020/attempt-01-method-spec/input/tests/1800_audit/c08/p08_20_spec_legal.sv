// IEEE 1800-2023 §8.20 Example 3: legal :initial, :extends, and :final uses.
class base;
  function void f1(); $display("base.f1"); endfunction
  virtual function void f2(); $display("base.f2"); endfunction
  pure virtual function void f3();
endclass : base

class A extends base;
  function :initial void f1(); $display("A.f1"); endfunction
  virtual function :final :extends void f2(); $display("A.f2"); endfunction
  function :final void f4(); $display("A.f4"); endfunction
endclass : A

class B extends A;
  virtual function :initial void f1(); $display("B.f1"); endfunction
endclass : B

class ConcreteB extends B;
  function void f3(); $display("ConcreteB.f3"); endfunction
endclass : ConcreteB

class C extends base;
  extern function :initial void f5();
endclass : C

function void C::f5(); $display("C.f5"); endfunction

class ConcreteC extends C;
  function void f3(); $display("ConcreteC.f3"); endfunction
endclass : ConcreteC

module p08_20_spec_legal;
  ConcreteB b;
  ConcreteC c;
  initial begin
    b = new;
    b.f1();
    b.f2();
    b.f3();
    b.f4();
    c = new;
    c.f3();
    c.f5();
  end
endmodule
