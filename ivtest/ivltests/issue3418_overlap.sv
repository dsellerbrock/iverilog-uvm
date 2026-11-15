module issue3418_overlap;
  logic [1:0] m [0:1];
  int idx;
  assign m[1][0] = 1'b1;
  initial begin
    m[1][0] = 1'b0;
    m[1][idx] = 1'b0;
    m[idx][1] = 1'b0;
  end
endmodule
