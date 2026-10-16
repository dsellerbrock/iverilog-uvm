module sv_assert_multiclock_disable_branch;
  reg c1 = 0, c2 = 0, c3 = 0;
  reg a = 0, b = 0, c = 0, x = 0, y = 0, d = 1, e = 0, rst_n = 1;
  integer disabled_failures = 0, control_failures = 0;
  time control_last_failure = 0;

  always #10 c1 = ~c1;
  always #15 c2 = ~c2;
  always #20 c3 = ~c3;

  assert property (@(posedge c1) disable iff (!rst_n)
                   ((a ##1 b) or (c ##1 b) or (x ##2 y)) |->
                   @(posedge c2) d ##1 @(posedge c3) e)
  else disabled_failures++;

  assert property (@(posedge c1)
                   ((a ##1 b) or (c ##1 b) or (x ##2 y)) |->
                   @(posedge c2) d ##1 @(posedge c3) e)
  else begin
    control_failures++;
    control_last_failure = $time;
  end

  initial begin
    #1 begin a = 1; c = 1; x = 1; end
    #10 begin a = 0; c = 0; x = 0; b = 1; end
    #34 rst_n <= 0; // coincident with the c2 handoff edge
    #4 y = 1;
    #2 begin y = 0; rst_n <= 1; end
    #10 a = 1;
    #10 a = 0;
    #10 e = 1;
    #40 a = 1; // leave a partial branch pending when simulation ends
    #18 rst_n <= 0;
    #6;
    if (disabled_failures != 0 || control_failures != 2 ||
        control_last_failure != 60)
      $fatal(1, "disabled=%0d control=%0d last=%0t",
             disabled_failures, control_failures, control_last_failure);
    $display("PASSED");
    $finish;
  end
endmodule
