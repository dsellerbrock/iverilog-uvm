// IEEE 1800-2017/2023 §8.20: a virtual override return type must match or be derived.
class Base;
  virtual function int f(); return 1; endfunction
endclass

class Derived extends Base;
  function byte f(); return 1; endfunction
endclass

module n08_20_override_return_type;
  Derived obj;
  initial obj = new;
endmodule
