// IEEE 1800-2017/2023 §8.20: virtual override argument names must match.
class Base;
  virtual function int f(input int a); return a; endfunction
endclass

class Derived extends Base;
  function int f(input int b); return b; endfunction
endclass

module n08_20_override_arg_name;
  Derived obj;
  initial obj = new;
endmodule
