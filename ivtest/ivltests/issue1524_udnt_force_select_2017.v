module top;
  nettype logic [3:0] user_net_t;
  user_net_t n;

  initial begin
    force n[0] = 1'b1;
    release n[0];
    force n[3:2] = 2'b11;
    release n[3:2];
  end
endmodule
