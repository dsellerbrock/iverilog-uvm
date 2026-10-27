module p07_10_lv1;
  int q[$] = '{1, 2};
  initial begin q[$+1] = 50; $display("%0d %0d", q.size(), q[$]); end
endmodule
