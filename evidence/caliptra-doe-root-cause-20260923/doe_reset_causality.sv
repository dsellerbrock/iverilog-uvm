`timescale 1ns/1ps

module doe_reset_causality;
  bit clk = 0;
  always #5 clk = ~clk;
  bit clock_enable = 1;
  wire gated_clk = clk & clock_enable;
  bit rst_b = 1;
  bit clear_pre = 0;
  bit clear_post = 0;
  bit status = 0;
  int pre_failures = 0;
  int post_failures = 0;
  int control_failures = 0;

  p_pre: assert property (@(posedge gated_clk) disable iff (!rst_b)
                          clear_pre |=> status)
    else pre_failures++;
  p_post: assert property (@(posedge gated_clk) disable iff (!rst_b)
                           clear_post |=> status)
    else post_failures++;
  p_control: assert property (@(posedge gated_clk) clear_pre |=> status)
    else control_failures++;

  initial begin
    #2 clear_pre = 1;
    #8 begin clear_pre = 0; clock_enable = 0; end
    #1 rst_b = 0;
    #1 rst_b = 1;
    #8 clock_enable = 1;
    #10 clear_post = 1;
    #10 clear_post = 0;
    #10;
    $display("RESULT pre=%0d post=%0d control=%0d",
             pre_failures, post_failures, control_failures);
    if (pre_failures != 0 || post_failures != 1 || control_failures != 1)
      $fatal(1, "reset-window causal controls were not distinguished");
    $finish(0);
  end
endmodule
