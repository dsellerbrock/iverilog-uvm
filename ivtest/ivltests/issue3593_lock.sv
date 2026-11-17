module top;
  bit clk = 0;
  integer failures = 0;
  always #5 clk = ~clk;
  pa: assert property (@(posedge clk) 1'b0) else failures = failures + 1;
  initial begin
    #1 $control_assertion(645); // lock enabled assertion
    $control_assertion(620); // disable must have no effect
    #10;
    if (failures != 1) $fatal(1, "FAILED locked enable: %0d", failures);
    $control_assertion(646); // unlock
    $control_assertion(620); // disable
    #10;
    if (failures != 1) $fatal(1, "FAILED disable: %0d", failures);
    $control_assertion(645); // lock disabled assertion
    $control_assertion(621); // enable must have no effect
    #10;
    if (failures != 1) $fatal(1, "FAILED locked disable: %0d", failures);
    $control_assertion(646);
    $control_assertion(621);
    #10;
    if (failures != 2) $fatal(1, "FAILED enable: %0d", failures);
    $check_controls;
    $display("PASSED");
    $finish;
  end
endmodule
