// IEEE 1800-2017/2023 §8.20: default presence must match across an override.
class Base;
  virtual function int f(input int a = 1); return a; endfunction
endclass

class Derived extends Base;
  function int f(input int a); return a; endfunction
endclass

module n08_20_override_default_presence;
  Derived obj;
  initial obj = new;
endmodule
