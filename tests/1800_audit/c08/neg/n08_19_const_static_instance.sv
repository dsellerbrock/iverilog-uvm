// IEEE 1800-2017/2023 §8.19: an instance constant cannot be declared static.
class BadStaticConst;
  static const int size;
  function new(); size = 3; endfunction
endclass

module n08_19_const_static_instance;
  BadStaticConst obj;
  initial obj = new;
endmodule
