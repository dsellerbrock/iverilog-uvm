`timescale 1ns/1ps
// Irregular clock intervals, an Off gap during a live attempt, and Kill.
module top;
  bit clk = 0, a = 0, b = 0, c = 0;
  p: assert property (@(posedge clk) a ##1 b ##1 c);

  initial begin
    #1 $m12ai_setup;
    a = 1;
    #4 clk = 1;                 // t=5: attempt A starts.
    #1 clk = 0; a = 0; b = 1; $assertoff(0, p);
    #7 clk = 1;                 // t=13: A advances, no new start.
    #1 clk = 0; b = 0;
    #11 clk = 1;                // t=25: A fails, start remains t=5.
    #1 clk = 0; $asserton(0, p); a = 1;
    #9 clk = 1;                 // t=35: another attempt starts.
    #1 clk = 0; a = 0; $assertkill(0, p);
    #12 clk = 1;                // t=48: killed attempt must stay gone.
    #1 clk = 0; $asserton(0, p);
    #11 clk = 1;                // t=60: immediate failure, start t=60.
    #1 clk = 0; $m12ai_check;
    #1 $finish;
  end
endmodule
