module p07_10_lv5;
  int b[$:3] = '{1, 2, 3, 4};
  initial begin b[$+1] = 6; $display("%0d", b.size()); end
endmodule
