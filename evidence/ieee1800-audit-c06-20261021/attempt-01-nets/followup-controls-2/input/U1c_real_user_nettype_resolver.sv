package P;
  function automatic real Rsum(input real d[]);
    Rsum = 0.0;
    foreach (d[i]) Rsum += d[i];
  endfunction
  nettype real wRsum with Rsum;
endpackage
module top;
  import P::*;
  real d1 = 1.5;
  real d2 = 2.0;
  wRsum n;
  assign n = d1;
  assign n = d2;
  initial begin
    #1 $display("%0.1f", n);
  end
endmodule
