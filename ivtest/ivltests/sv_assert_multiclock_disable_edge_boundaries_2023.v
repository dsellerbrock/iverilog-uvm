module sv_assert_multiclock_disable_edge_boundaries_2023;
  reg c1 = 0, c2 = 0, c3 = 0;
  reg a = 0, d = 1, e = 0;
  reg start_rst_n = 1, end_rst_n = 1;
  integer start_disabled = 0, end_disabled = 0;
  integer start_control = 0, end_control = 0;

  always #10 c1 = ~c1;
  always #15 c2 = ~c2;
  always #20 c3 = ~c3;
  always @(posedge c1)
    if ($time == 10) start_rst_n <= 0;
  always @(posedge c3)
    if ($time == 20) end_rst_n <= 0;

  assert property (@(posedge c1) disable iff (!start_rst_n)
                   a |-> @(posedge c2) d ##1 @(posedge c3) e)
  else start_disabled++;

  assert property (@(posedge c1) disable iff (!end_rst_n)
                   a |-> @(posedge c2) d ##1 @(posedge c3) e)
  else end_disabled++;

  assert property (@(posedge c1)
                   a |-> @(posedge c2) d ##1 @(posedge c3) e)
  else start_control++;

  assert property (@(posedge c1)
                   a |-> @(posedge c2) d ##1 @(posedge c3) e)
  else end_control++;

  initial begin
    #1 a = 1;
    #10 a = 0;
    #15;
    if (start_disabled != 0 || end_disabled != 0 ||
        start_control != 1 || end_control != 1)
      $fatal(1, "start=%0d/%0d end=%0d/%0d",
             start_disabled, start_control, end_disabled, end_control);
    $display("PASSED");
    $finish;
  end
endmodule
