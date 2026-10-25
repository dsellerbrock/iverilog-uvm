// IEEE 1800-2017/2023 §8.20: virtual override argument directions must match.
class Base;
  virtual function int f(input int a); return a; endfunction
endclass

class Derived extends Base;
  function int f(output int a); a = 1; return a; endfunction
endclass

module n08_20_override_direction;
  Derived obj;
  initial obj = new;
endmodule
