module p07_10_lv2;
  int q[$] = '{1, 2};
  initial begin q[$] = 9; $display("%0d", q[1]); end
endmodule
