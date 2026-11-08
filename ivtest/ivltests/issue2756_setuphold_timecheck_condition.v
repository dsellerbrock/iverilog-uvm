`timescale 1ns/1ns
module issue2756_setuphold_timecheck_condition;
  reg clk = 0, d = 0, en = 0;
  reg notifier = 0;
  specify
    $setuphold(posedge clk, d, 3, 3, notifier, , en);
  endspecify

  initial begin
    // The first setup violation is disabled by timecheck_condition.
    #10 d = 1;
    #1 clk = 1;
    #1 clk = 0;
    en = 1;
    #4 d = 0;
    #1 d = 1;
    #1 clk = 1;
    #1 $display("notifier=%b", notifier);
  end
endmodule
