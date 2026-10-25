module top;
  typedef struct { logic a; logic [3:0] b; } s_t;
  s_t v;
  always_comb v = '{1'b1, 4'h3};
  initial begin
    #1 $display("%b %h", v.a, v.b);
  end
endmodule
