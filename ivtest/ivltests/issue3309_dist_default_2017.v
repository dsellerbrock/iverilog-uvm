module issue3309_dist_default_2017;
  reg clk, x;
  assert property (@(posedge clk) x dist {0, default :/ 1});
endmodule
