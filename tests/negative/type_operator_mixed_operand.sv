// IEEE 1800-2017 6.23: type() may only be compared against another
// type() reference, never against an ordinary value expression. Must
// be a clean error, not a silent (wrong) comparison.
module type_operator_mixed_operand;
  int a;
  bit r;
  initial begin
    r = (type(a) == a);
  end
endmodule
