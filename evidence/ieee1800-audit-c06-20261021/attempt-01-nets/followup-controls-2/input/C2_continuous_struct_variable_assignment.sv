module top;
  typedef struct { logic a; logic [3:0] b; } s_t;
  s_t src;
  s_t dst;
  assign dst = src;
  initial begin
    src.a = 1'b1;
    src.b = 4'h3;
    #1 $display("%b %h", dst.a, dst.b);
  end
endmodule
