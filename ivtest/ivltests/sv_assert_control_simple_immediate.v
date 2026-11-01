module sv_assert_control_simple_immediate;
  bit clk = 0;
  int concurrent_fail = 0;
  int immediate_eval = 0;
  int immediate_fail = 0;
  int sibling_fail = 0;

  always #5 clk = ~clk;

  function automatic bit immediate_condition();
    immediate_eval++;
    return 1'b0;
  endfunction

  a1: assert property (@(posedge clk) 1'b0) else concurrent_fail++;

  always @(posedge clk) begin
    a2: assert (immediate_condition()) else immediate_fail++;
    sibling: assert (1'b0) else sibling_fail++;
  end

  initial begin
    #1 $assertoff(0, a1, a2);
    #20;
    if (concurrent_fail != 0 || immediate_eval != 0 || immediate_fail != 0
        || sibling_fail != 2)
      $fatal(1, "off %0d/%0d/%0d/%0d", concurrent_fail, immediate_eval,
             immediate_fail, sibling_fail);

    $asserton(0, a1, a2);
    #20;
    if (concurrent_fail != 2 || immediate_eval != 2 || immediate_fail != 2
        || sibling_fail != 4)
      $fatal(1, "on %0d/%0d/%0d/%0d", concurrent_fail, immediate_eval,
             immediate_fail, sibling_fail);

    $assertkill(0, a1, a2);
    #20;
    if (concurrent_fail != 2 || immediate_eval != 2 || immediate_fail != 2
        || sibling_fail != 6)
      $fatal(1, "kill %0d/%0d/%0d/%0d", concurrent_fail, immediate_eval,
             immediate_fail, sibling_fail);

    $asserton(0, a1, a2);
    #20;
    if (concurrent_fail != 4 || immediate_eval != 4 || immediate_fail != 4
        || sibling_fail != 8)
      $fatal(1, "restart %0d/%0d/%0d/%0d", concurrent_fail, immediate_eval,
             immediate_fail, sibling_fail);

    $assertoff;
    #20;
    if (concurrent_fail != 4 || immediate_eval != 4 || immediate_fail != 4
        || sibling_fail != 8)
      $fatal(1, "global off %0d/%0d/%0d/%0d", concurrent_fail,
             immediate_eval, immediate_fail, sibling_fail);

    $asserton;
    #20;
    if (concurrent_fail != 6 || immediate_eval != 6 || immediate_fail != 6
        || sibling_fail != 10)
      $fatal(1, "global on %0d/%0d/%0d/%0d", concurrent_fail,
             immediate_eval, immediate_fail, sibling_fail);
    $display("PASSED");
    $finish;
  end
endmodule
