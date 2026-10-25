// IEEE 1800-2017/2023 §8.19: an instance constant cannot be assigned externally.
class InstanceConst;
  const int size;
  function new(); size = 3; endfunction
endclass

module n08_19_const_external_write;
  InstanceConst obj;
  initial begin obj = new; obj.size = 5; end
endmodule
