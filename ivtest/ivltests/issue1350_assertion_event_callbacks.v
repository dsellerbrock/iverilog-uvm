module issue1350_assertion_event_callbacks;
  logic clk = 0, a = 0, b = 1, disabled = 1;
  always #5 clk = ~clk;

  p_vacuous: assert property (@(posedge clk) a |-> b);
  p_disabled: assert property (@(posedge clk) disable iff (disabled) a |-> b);

  initial begin
    #1 $issue1350_setup;
    #1 $assertoff;
    #1 $asserton;
    @(posedge clk);
    #1 $assertkill;
    #1 $issue1350_check;
    $finish;
  end
endmodule
