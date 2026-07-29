// IEEE 1800-2017 6.23: type() references may only be compared with the
// equality operators (==, !=, ===, !==) -- relational comparisons (<,
// <=, >, >=) are not legal. This must be a clean, loud error, not a
// crash or a silently-wrong constant.
module type_operator_relational;
  int a;
  bit signed [31:0] b;
  bit r;
  initial begin
    r = (type(a) < type(b));
  end
endmodule
