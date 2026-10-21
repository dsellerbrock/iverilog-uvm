typedef C;
typedef C::T c_t; c_t y;
class C; typedef int T; endclass
module p06_18d; initial $display("TYPEBITS=%0d",$bits(y)); endmodule
