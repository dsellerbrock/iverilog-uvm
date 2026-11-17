typedef class Forward;
typedef Forward::T forward_bad_t;
class Forward #(int N = 1);
  typedef int T;
endclass
class C #(int N = 1);
  typedef int T;
endclass
module top;
  typedef C::T used_bad_t;
  typedef C::T unused_bad_t;
  used_bad_t value;
endmodule
