module sv_assert_first_match_continuation;
  bit clk = 0;
  bit start = 0, a = 0, b = 0, c = 0;
  bit later_start = 0, later_a = 0, later_b = 0, later_c = 0;
  int fail_count = 0, later_fail_count = 0;

  always #5 clk = ~clk;

  ap: assert property (@(posedge clk)
    start |-> first_match(a ##[1:2] b) ##1 c)
  else fail_count++;

  ap_later: assert property (@(posedge clk)
    later_start |-> first_match(later_a ##[1:2] later_b) ##1 later_c)
  else later_fail_count++;

  initial begin
    #1;
    start = 1;
    a = 1;
    later_start = 1;
    later_a = 1;
    #5;
    start = 0;
    a = 0;
    later_start = 0;
    later_a = 0;
    b = 1;
    #10;
    later_b = 1;
    #10;
    b = 0;
    c = 1;
    later_b = 0;
    later_c = 1;
    #14;
    $assertoff(0, ap);
    $assertoff(0, ap_later);
    if (fail_count != 1 || later_fail_count != 0) begin
      $fatal(1, "failures=%0d later_failures=%0d",
             fail_count, later_fail_count);
    end
    $display("PASSED");
    $finish(0);
  end
endmodule
