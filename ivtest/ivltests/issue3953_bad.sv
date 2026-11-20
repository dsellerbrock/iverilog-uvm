module issue3953_bad;
  bit clk;
  event ready;
  global clocking gc @(posedge clk); endclocking

  assert property (@($global_clock) $future_gclk(ready.triggered));
  initial $display("%b", $future_gclk(clk));

  issue3953_free_checker check_free(clk);
endmodule

checker issue3953_free_checker(input bit clk);
  rand bit [1:0] candidate;
  assert property (@(posedge clk) $future_gclk(candidate[1]));
endchecker
