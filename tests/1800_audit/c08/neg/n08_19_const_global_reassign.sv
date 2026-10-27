// IEEE 1800-2017/2023 §8.19: a global constant cannot be assigned after declaration.
class BadGlobalConst;
  const int max_size = 9 * 1024;
  function new(); max_size = 5; endfunction
endclass

module n08_19_const_global_reassign;
  BadGlobalConst obj;
  initial obj = new;
endmodule
