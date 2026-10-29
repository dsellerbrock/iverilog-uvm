module issue1390_abort_cover_properties;
  logic clk = 0, condition = 1, p = 0;
  always #5 clk = ~clk;

  cp_accept: cover property (@(posedge clk) accept_on(condition) p);
  cp_reject: cover property (@(posedge clk) reject_on(condition) p);
  cp_sync_accept: cover property (@(posedge clk) sync_accept_on(condition) p);
  cp_sync_reject: cover property (@(posedge clk) sync_reject_on(condition) p);

  initial begin
    @(negedge clk);
    condition = 0;
    @(negedge clk);
    p = 1;
    @(negedge clk);
    if (_ivl_sva0_cnt0 !== 2 || _ivl_sva1_cnt0 !== 1 ||
        _ivl_sva2_cnt0 !== 2 || _ivl_sva3_cnt0 !== 1)
      $fatal(1, "abort cover counts: %0d %0d %0d %0d",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0,
             _ivl_sva2_cnt0, _ivl_sva3_cnt0);
    $display("abort cover counts: %0d %0d %0d %0d",
             _ivl_sva0_cnt0, _ivl_sva1_cnt0,
             _ivl_sva2_cnt0, _ivl_sva3_cnt0);
    $finish;
  end
endmodule
