// IEEE 1800-2017/2023 11.3.1 Table 11-1: bitwise and shift operators
// require integral operands.
module sv_real_bitwise_ops_fail;
  real r = 5.5, q;

  initial begin
    q = ~r;
    r <<= 1;
    r >>= 1;
    r <<<= 1;
    r >>>= 1;
    r &= 1;
    r |= 1;
    r ^= 1;
  end
endmodule
