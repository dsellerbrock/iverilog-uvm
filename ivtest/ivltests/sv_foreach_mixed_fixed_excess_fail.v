// A fifth foreach variable exceeds two fixed ranks, queue, and packed int.
module top;
  int q[2][2][$];
  initial begin
    q[0][0].push_back(7);
    foreach (q[i,j,k,l,m]) $fatal(1, "excess index was accepted");
  end
endmodule
