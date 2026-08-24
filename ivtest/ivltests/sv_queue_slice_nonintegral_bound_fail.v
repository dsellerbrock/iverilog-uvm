// IEEE 1800-2017 7.10.1 permits arbitrary integral queue-slice bounds, but
// does not permit real-valued bounds.
module top;
  int q[$];
  int r[$];
  real lower;
  int upper;

  initial begin
    lower = 1.0;
    upper = 2;
    r = q[lower:upper];
    r = q[lower +: 1];
    r = q[0 +: lower];
  end
endmodule
