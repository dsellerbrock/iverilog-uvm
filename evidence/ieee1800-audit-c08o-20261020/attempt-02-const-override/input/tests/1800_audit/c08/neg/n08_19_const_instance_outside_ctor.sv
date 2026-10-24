// IEEE 1800-2017/2023 §8.19: an instance constant is assigned only in its constructor.
class BadInstanceConst;
  const int size;
  function new(); size = 1; endfunction
  function void set(); size = 2; endfunction
endclass

module n08_19_const_instance_outside_ctor;
  BadInstanceConst obj;
  initial begin obj = new; obj.set(); end
endmodule
