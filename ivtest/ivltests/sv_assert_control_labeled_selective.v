module top;
  bit clk;
  bit start;
  bit done;
  int keep_fails;
  int selected_fails;
  int inflight_fails;

  keep_check: assert property (@(posedge clk) 1'b0)
    else keep_fails++;
  selected_check: assert property (@(posedge clk) 1'b0)
    else selected_fails++;
  inflight_check: assert property (@(posedge clk) start |=> done)
    else inflight_fails++;

  initial begin
    $assertoff(0, top.selected_check);

    #5 clk = 1;
    #1 clk = 0;
    if (keep_fails != 1 || selected_fails != 0)
      $fatal(1, "selective off failed: keep=%0d selected=%0d",
             keep_fails, selected_fails);

    start = 1;
    #4 clk = 1;
    #1 clk = 0;
    start = 0;
    $assertoff(0, top.inflight_check);

    #4 clk = 1;
    #1 clk = 0;
    if (inflight_fails != 1)
      $fatal(1, "off discarded an already-running attempt: %0d",
             inflight_fails);

    $asserton(0, top.selected_check);
    #4 clk = 1;
    #1 clk = 0;
    if (keep_fails != 4 || selected_fails != 1)
      $fatal(1, "selective on failed: keep=%0d selected=%0d",
             keep_fails, selected_fails);

    $display("PASSED");
    $finish;
  end
endmodule
