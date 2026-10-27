// IEEE 1800-2023 §8.20 Example 3: overriding a :final virtual method.
class BaseN2;
  virtual function void f2(); endfunction
endclass
class A2 extends BaseN2;
  virtual function :final :extends void f2(); endfunction
endclass
class B2 extends A2;
  virtual function void f2(); endfunction
endclass
module p08_20_spec_n2;
endmodule
