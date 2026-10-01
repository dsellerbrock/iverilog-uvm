// An output argument without a default must be supplied (IEEE 1800-2017/2023
// 13.5.3). Accepted only under -gcommercial-unsafe. The message counts
// arguments as written, not including a method's hidden receiver.
class util;
  static task automatic csr_rd(input int ptr, output int value);
    value = ptr;
  endtask
endclass
module test;
  initial util::csr_rd(.ptr(3));
endmodule
