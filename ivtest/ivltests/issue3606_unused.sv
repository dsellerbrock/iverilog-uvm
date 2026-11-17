class C #(int N = 1);
  typedef int T;
endclass
module top;
  typedef C::T bad_t;
endmodule
