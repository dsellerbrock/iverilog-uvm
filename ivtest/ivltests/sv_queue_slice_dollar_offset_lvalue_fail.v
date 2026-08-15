// Parsed for symmetry with queue-slice expressions, but assignment to a
// bounded `$-offset' queue slice is intentionally loud until the l-value ABI
// can carry both run-time bounds.
module top;
  int q[$];
  initial begin
    q = {1, 2, 3};
    q[0:$-1] = {4, 5};
  end
endmodule
