module p07_10_lv3;
  int q[$] = '{1, 2};
  initial begin q[$-1] = 8; $display("%0d", q[0]); end
endmodule
