package p;
  class db #(type T = int);
    function bit exists(); return 1; endfunction
  endclass
  class user #(type T = int);
    static db #(T) item;
  endclass
  typedef user #(byte) user_byte_t;
endpackage
module top;
  import p::*;
  user #(shortint) u;
  initial begin #1; $display("PASSED"); end
endmodule
