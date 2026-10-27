module p07_10_lv4;
  int q[$] = '{1, 2};
  initial begin q[q.size()] = 50; $display("%0d %0d", q.size(), q[$]); end
endmodule
