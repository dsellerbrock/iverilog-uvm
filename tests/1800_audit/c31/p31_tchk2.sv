`timescale 1ns/1ns

module p31_tchk2;
  reg rst_recovery = 0, clk_recovery = 0;
  reg rst_removal = 0, clk_removal = 0;
  reg clk_period = 0;
  reg clk_skew_ref = 0, clk_skew_data = 0;
  reg clk_setuphold = 0, data_setuphold = 0;
  reg clk_nochange = 0, data_nochange = 0;
  reg notifier = 0;
  integer notifier_changes = 0;

  specify
    $recovery(posedge rst_recovery, posedge clk_recovery, 3, notifier);
    $removal(posedge rst_removal, posedge clk_removal, 2, notifier);
    $period(posedge clk_period, 10, notifier);
    $skew(posedge clk_skew_ref, posedge clk_skew_data, 2, notifier);
    $setuphold(posedge clk_setuphold, data_setuphold, 3, 2, notifier);
    $nochange(posedge clk_nochange, data_nochange, 0, 0, notifier);
  endspecify

  always @(notifier) notifier_changes++;

  initial begin
    #10 rst_recovery = 1;
    #1 clk_recovery = 1;
  end

  initial begin
    #20 clk_removal = 1;
    #1 rst_removal = 1;
  end

  initial begin
    #30 clk_period = 1;
    #3 clk_period = 0;
    #3 clk_period = 1;
  end

  initial begin
    #40 clk_skew_ref = 1;
    #3 clk_skew_data = 1;
  end

  initial begin
    #49 data_setuphold = 1;
    #1 clk_setuphold = 1;
    #1 data_setuphold = 0;
  end

  initial begin
    #60 clk_nochange = 1;
    #1 data_nochange = 1;
    #3 clk_nochange = 0;
  end

  initial begin
    #70 $display("N %0d %b", notifier_changes, notifier);
  end
endmodule
