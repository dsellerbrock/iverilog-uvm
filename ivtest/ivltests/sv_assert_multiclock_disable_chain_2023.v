module sv_assert_multiclock_disable_chain;
  reg c1 = 0, c2 = 0, c3 = 0;
  reg a = 0, b = 1, c = 0, rst_n = 1;
  integer disabled_failures = 0;
  integer control_failures = 0;

  always #10 c1 = ~c1;
  always #15 c2 = ~c2;
  always #20 c3 = ~c3;

  assert property (@(posedge c1) disable iff (!rst_n)
                   a |-> @(posedge c2) b ##1 @(posedge c3) c)
    else disabled_failures++;

  assert property (@(posedge c1)
                   a |-> @(posedge c2) b ##1 @(posedge c3) c)
    else control_failures++;

  initial begin
    #1 a = 1;
    #10 a = 0;
    #6 rst_n = 0;
    #1 rst_n = 1;
    #7 rst_n = 0;
    #6 rst_n = 1;
    #4 a = 1;
    #16 a = 0;
    #59;
    if (disabled_failures != 1 || control_failures != 2)
      $fatal(1, "disabled=%0d control=%0d",
             disabled_failures, control_failures);
    $display("PASSED");
    $finish;
  end
endmodule
