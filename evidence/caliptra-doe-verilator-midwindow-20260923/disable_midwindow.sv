`timescale 1ns/1ps
module tb;
  bit clk = 0;
  always #5 clk = ~clk;
  bit rst_b = 1;
  bit clear = 0;
  bit status = 0;
  integer gated_failures = 0;
  integer control_failures = 0;

  a_gated: assert property (@(posedge clk) disable iff (!rst_b) clear |=> status)
    else begin gated_failures++; $display("GATED_FAILURE at %0t", $time); end
  a_control: assert property (@(posedge clk) clear |=> status)
    else begin control_failures++; $display("CONTROL_FAILURE at %0t", $time); end

  initial begin
    #2 clear = 1;
    #8 clear = 0;
    #1 rst_b = 0;
    #1 rst_b = 1;
    #8;
    $display("RESULT gated=%0d control=%0d", gated_failures, control_failures);
    if (control_failures != 1) $fatal(1, "control stimulus invalid");
    if (gated_failures != 0) $fatal(1, "mid-window disable ignored");
    $finish;
  end
endmodule
