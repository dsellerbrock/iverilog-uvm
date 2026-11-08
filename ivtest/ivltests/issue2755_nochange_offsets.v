`timescale 1ns/1ps
module issue2755_nochange_expanded(input clk, input d, output reg notifier);
  specify
    $nochange(posedge clk, d, 1, 1, notifier);
  endspecify
endmodule

module issue2755_nochange_shrunk(input clk, input d, output reg notifier);
  specify
    $nochange(posedge clk, d, -1, -1, notifier);
  endspecify
endmodule

module issue2755_nochange_start_expanded(input clk, input d, output reg notifier);
  specify
    $nochange(posedge clk, d, 1, 0, notifier);
  endspecify
endmodule

module issue2755_nochange_offsets;
  reg expanded_clk = 0, expanded_data = 0;
  reg start_clk = 0, start_data = 0;
  reg shrunk_clk = 0, shrunk_data = 0;
  wire expanded_notifier, start_notifier, shrunk_notifier;
  issue2755_nochange_expanded expanded(
    expanded_clk, expanded_data, expanded_notifier);
  issue2755_nochange_shrunk shrunk(
    shrunk_clk, shrunk_data, shrunk_notifier);
  issue2755_nochange_start_expanded start_expanded(
    start_clk, start_data, start_notifier);

  initial begin
    #9.5 start_data = 1;
    #0.5 start_clk = 1;
  end

  initial begin
    #10 expanded_clk = 1;
    #10 expanded_clk = 0;
    #0.5 expanded_data = 1;

    #9.5 shrunk_clk = 1;
    #0.5 shrunk_data = 1; // outside the window: start edge is at t=20
    #4 shrunk_data = 0;   // inside the window
    #5 shrunk_clk = 0;
    #0.5 shrunk_data = 1; // outside the window: end edge is at t=29

    #1;
    $display("expanded=%b start=%b shrunk=%b", expanded_notifier,
             start_notifier, shrunk_notifier);
    if (expanded_notifier !== 1'b1 || start_notifier !== 1'b1 ||
        shrunk_notifier !== 1'b1)
      $fatal(1, "$nochange offset window mismatch");
    $finish;
  end
endmodule
