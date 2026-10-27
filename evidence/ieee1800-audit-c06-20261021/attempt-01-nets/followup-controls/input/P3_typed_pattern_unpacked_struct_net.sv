module top;
  typedef struct { logic a; logic [3:0] b; } s_t;
  wire s_t w;
  assign w = s_t'{1'b1, 4'h3};
  initial #1 $display("%b %h", w.a, w.b);
endmodule
