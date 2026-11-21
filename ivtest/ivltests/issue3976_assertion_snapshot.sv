`ifndef ISSUE3976_EDITION
`define ISSUE3976_EDITION "2017"
`endif

module issue3976_leaf #(parameter int CFG = 1)
    (input bit clk, input int sample, output int passes);
  p: assert property (@(posedge clk) 1'b1 |-> ##1 (sample == CFG))
       passes++;
     else $fatal(1, "assertion evaluation failed");
endmodule

module issue3976_assertion_snapshot #(parameter int CFG = 1);
  localparam int START = 0, STOP = 1, RESET = 2, MODULE = 10, HIER = 11,
                 ASSERTION = 20, TOGGLE = 23, ERROR = -1, NOCOV = 0, OK = 1;

  bit left_clk, right_clk;
  int sample = CFG;
  int left_passes, right_passes;
  string path = {"work/issue3976_assertion_snapshot_", `ISSUE3976_EDITION};
  string corrupt_path, missing_path;
  int source_fd, corrupt_fd, ch;

  issue3976_leaf #(CFG) left(left_clk, sample, left_passes);
  issue3976_leaf #(CFG) right(right_clk, sample, right_passes);

  task automatic check(input bit ok, input string message);
    if (!ok) $fatal(1, "%s", message);
  endtask

  task automatic hits(input int lhs, rhs);
    check($coverage_get(ASSERTION, MODULE, left) === lhs, "incorrect left hits");
    check($coverage_get(ASSERTION, MODULE, right) === rhs, "incorrect right hits");
    check($coverage_get(ASSERTION, HIER, $root) === lhs + rhs, "incorrect total hits");
    check($coverage_get_max(ASSERTION, HIER, $root) === 2, "incorrect maximum");
  endtask

  task automatic tick_left;
    #1 left_clk = 1;
    #1 left_clk = 0;
  endtask

  task automatic tick_right;
    #1 right_clk = 1;
    #1 right_clk = 0;
  endtask

  initial begin
    if ($value$plusargs("snapshot=%s", path)) begin end
    corrupt_path = {path, ".corrupt"};
    missing_path = {path, ".missing"};
    hits(0, 0);

    if ($test$plusargs("merge_only") || $test$plusargs("reject_only")) begin
      tick_right();
      tick_right();
      hits(0, 1);
      if ($test$plusargs("reject_only")) begin
        check($coverage_merge(ASSERTION, path) === ERROR, "different design accepted");
        hits(0, 1);
      end else begin
        check($coverage_merge(ASSERTION, path) === OK, "independent compile rejected");
        hits(1, 1);
      end
      $display("PASSED");
      $finish(0);
    end

    tick_left();
    tick_left();
    hits(1, 0);
    check($coverage_control(STOP, ASSERTION, MODULE, left) === OK, "STOP failed");
    if ($test$plusargs("save_error")) begin
      check($coverage_save(ASSERTION, path) === ERROR, "failed save reported success");
      hits(1, 0);
      $display("PASSED");
      $finish(0);
    end
    check($coverage_save(ASSERTION, path) === OK, "could not save a live hit");
    hits(1, 0);
    if ($test$plusargs("save_only")) begin
      $display("PASSED");
      $finish(0);
    end

    check($coverage_control(RESET, ASSERTION, HIER, $root) === OK, "RESET failed");
    tick_right();
    tick_right();
    hits(0, 1);

    check($coverage_merge(TOGGLE, path) === NOCOV, "wrong coverage type did not return NOCOV");
    hits(0, 1);
    check($coverage_merge(ASSERTION, missing_path) === ERROR, "missing database accepted");
    hits(0, 1);

    source_fd = $fopen(path, "rb");
    corrupt_fd = $fopen(corrupt_path, "wb");
    check(source_fd != 0 && corrupt_fd != 0, "could not create the corrupt copy");
    for (int i = 0; i < 4096; ++i) begin
      ch = $fgetc(source_fd);
      if (ch == -1) break;
      $fwrite(corrupt_fd, "%c", ch);
    end
    check(ch == -1, "test snapshot exceeds copy limit");
    $fwrite(corrupt_fd, "unexpected trailing data");
    $fclose(corrupt_fd);
    $fclose(source_fd);
    check($coverage_merge(ASSERTION, corrupt_path) === ERROR, "corrupt database accepted");
    hits(0, 1);

    check($coverage_merge(ASSERTION, path) === OK, "could not merge a live hit");
    hits(1, 1);
    check($coverage_merge(ASSERTION, path) === OK, "repeat merge failed");
    hits(1, 1);
    check(left_passes == 1 && right_passes == 1, "merge ran an assertion action");

    check($coverage_control(RESET, ASSERTION, HIER, $root) === OK, "second RESET failed");
    tick_left();
    tick_right();
    check(left_passes == 2 && right_passes == 2, "snapshot operation lost a pending attempt");
    hits(0, 1);
    check($coverage_control(START, ASSERTION, MODULE, left) === OK, "START failed");
    tick_left();
    hits(1, 1);

    $display("PASSED");
    $finish(0);
  end
endmodule

module issue3976_empty;
  string path;
  initial begin
    if (!$value$plusargs("snapshot=%s", path)) $fatal(1, "test requires snapshot path");
    if ($coverage_save(20, path) !== 0) $fatal(1, "empty design did not return NOCOV");
    $display("PASSED");
    $finish(0);
  end
endmodule
