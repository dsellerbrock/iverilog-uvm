// IEEE 1800-2017/2023 §8.19 record-only: the standard says assign once in new,
// but does not specify a compile-time diagnostic for a second constructor write.
class DoubleAssignedConst;
  const int size;
  function new(); size = 3; size = 4; endfunction
endclass

module r08_19_const_double_assignment;
  DoubleAssignedConst obj;
  initial begin obj = new; $display("C5 %0d", obj.size); end
endmodule
