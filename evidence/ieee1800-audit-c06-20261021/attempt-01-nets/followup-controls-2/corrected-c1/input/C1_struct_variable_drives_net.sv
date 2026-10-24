module top;
  typedef struct { logic a; logic [3:0] b; } s_t;
  s_t v;
  wire s_t n;
  assign n = v;
  initial begin
    v.a = 1'b1;
    v.b = 4'h3;
    #1 $display("%b %h", n.a, n.b);
  end
endmodule
