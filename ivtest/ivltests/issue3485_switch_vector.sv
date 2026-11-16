module top;
  supply1 hi;
  supply0 lo;
  reg en;
  wire [2:0] w, u;
  wire [5:0] wide;
  wire [1:0] full;

  rnmos a (w[0], hi, en);
  rpmos b (w[1], hi, 1'b0);
  rtran c (w[2], hi);
  rnmos d (u[0], hi, en);
  rpmos e (u[1], hi, 1'b0);
  rnmos f (wide[0], lo, en);
  rnmos g (wide[1], hi, en);
  rnmos h (wide[2], lo, en);
  rnmos i (wide[3], hi, en);
  rnmos j (wide[4], lo, en);
  rnmos k (full[0], lo, en);
  rnmos l (full[1], hi, en);

  initial begin
    en = 1;
    #1 $display("on:  %v %v %v %v", w, u, wide, full);
    en = 0;
    #1 $display("off: %v %v %v %v", w, u, wide, full);
    en = 1;
    #1 $display("on:  %v %v %v %v", w, u, wide, full);
  end
endmodule
