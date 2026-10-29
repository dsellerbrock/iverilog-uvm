module issue1389_abort_condition_dist_2017;
  logic clk = 0;
  int f_accept = 0, f_reject = 0, f_sync_accept = 0, f_sync_reject = 0;

  always #5 clk = ~clk;

  ap_accept: assert property (@(posedge clk)
    accept_on(1'b1 dist {1'b1 := 1}) 1'b0) else f_accept++;
  ap_reject: assert property (@(posedge clk)
    reject_on(1'b1 dist {1'b1 := 1}) 1'b1) else f_reject++;
  ap_sync_accept: assert property (@(posedge clk)
    sync_accept_on(1'b1 dist {1'b1 := 1}) 1'b0) else f_sync_accept++;
  ap_sync_reject: assert property (@(posedge clk)
    sync_reject_on(1'b1 dist {1'b1 := 1}) 1'b1) else f_sync_reject++;

  initial begin
    repeat (3) @(negedge clk);
    if (f_accept != 0 || f_reject != 3 ||
        f_sync_accept != 0 || f_sync_reject != 3)
      $fatal(1, "abort expression_or_dist semantics mismatch");
    $display("PASSED");
    $finish(0);
  end
endmodule
