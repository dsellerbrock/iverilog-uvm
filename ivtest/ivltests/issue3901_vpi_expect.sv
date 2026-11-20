`timescale 1ns/1ns
module top;
  bit clk;
  int fixed_pass, ranged_fail, fail_only_count, continued;

  always #5 clk = ~clk;

  task automatic original;
    expect (@(posedge clk) 1'b1) $display("uncalled pass");
    $display("uncalled sibling");
  endtask

  task automatic expect_only;
    expect (@(posedge clk) 1'b1) begin end
  endtask

  task automatic ranged_run;
    expect (@(posedge clk) 1'b1 ##[1:2] 1'b0) $fatal(1, "ranged pass");
    else begin : ranged_else
      int increment = 1;
      ranged_fail += increment;
    end
    continued += 1;
  endtask

  task automatic fail_only;
    expect (@(posedge clk) 1'b0) else fail_only_count += 1;
    continued += 1;
  endtask

  task automatic null_pass;
    expect (@(posedge clk) 1'b1) ;
    continued += 1;
  endtask

  task automatic null_else;
    expect (@(posedge clk) 1'b0) begin end else ;
  endtask

  initial begin
    fixed_run();
    if (fixed_pass != 1 || continued != 1 || $time != 15)
      $fatal(1, "fixed expect action or continuation");
    ranged_run();
    if (ranged_fail != 1 || continued != 2 || $time != 45)
      $fatal(1, "ranged expect action or continuation");
    fail_only();
    if (fail_only_count != 1 || continued != 3 || $time != 55)
      $fatal(1, "fail-only expect action or continuation");
    null_pass();
    if (continued != 4 || $time != 65)
      $fatal(1, "null pass expect continuation");
    null_else();
    if ($time != 75) $fatal(1, "null else expect continuation");
    expect_only();
    if ($time != 85) $fatal(1, "expect-only task continuation");
    $display("issue3901 execution PASSED");
    $finish(0);
  end

  initial #100 $fatal(1, "expect timeout");

  task automatic fixed_run;
    `line 120 "issue3901_labeled_source.sv" 0
    check_fixed:
      expect (@(posedge clk) 1'b1 ##1 1'b1) begin
        fixed_pass += 1;
      end else $fatal(1, "fixed fail");
    continued += 1;
  endtask
endmodule
