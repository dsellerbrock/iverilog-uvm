module sv_assert_multiclock_disable_branch_boundary_2023;
  reg c1 = 0, c2 = 0, c3 = 0;
  reg a = 0, b = 0, d = 1, e = 0, rst_n = 1;
  integer disabled_failures = 0, control_failures = 0;

  always #10 c1 = ~c1;
  always #15 c2 = ~c2;
  always #20 c3 = ~c3;
  always @(posedge c2)
    if ($time == 15) rst_n <= 0;

  assert property (@(posedge c1) disable iff (!rst_n)
                   ((a) or (b)) |->
                   @(posedge c2) d ##1 @(posedge c3) e)
  else disabled_failures++;

  assert property (@(posedge c1)
                   ((a) or (b)) |->
                   @(posedge c2) d ##1 @(posedge c3) e)
  else control_failures++;

  initial begin
    #1 a = 1;
    #10 a = 0;
    #14 begin rst_n = 1; a = 1; end
    #6 a = 0;
    #24 e = 1;
    #6;
    a = 1;
    #10 a = 0;
    #5;
    #1 rst_n = 0;
    #1;
    if (disabled_failures != 0 || control_failures != 1)
      $fatal(1, "disabled=%0d control=%0d",
             disabled_failures, control_failures);
    $display("PASSED");
    $finish;
  end
endmodule
