`timescale 1ns/1ps
interface selected_drive_if(input logic clk);
  logic [7:0] raw = '0;
  wire [7:0] bus;
  assign bus = raw;

  clocking cb @(posedge clk);
    output #2 bus = raw;
  endclocking

  modport driver_mp(clocking cb);
endinterface

module sv_vif_clocking_selected_dynamic_capture;
  logic clk = 1'b0;
  selected_drive_if first_if(clk), second_if(clk);
  virtual selected_drive_if.driver_mp vifs[0:1];
  int selected_receiver = 0;
  int receiver_calls = 0;
  int selected_index = 0;
  int select_calls = 0;
  int failures = 0;

  always #5 clk = ~clk;

  function automatic int choose_receiver;
    receiver_calls++;
    choose_receiver = selected_receiver;
  endfunction

  function automatic int choose_index;
    select_calls++;
    choose_index = selected_index;
  endfunction

  initial begin
    #2;
    vifs[1] = first_if;
    vifs[0] = second_if;
    selected_receiver = 1;
    selected_index = 1;
    vifs[choose_receiver()].cb.bus[choose_index()] <= 1'b1;
    selected_receiver = 0;
    selected_index = 4;
    vifs[choose_receiver()].cb.bus[choose_index()] <= 1'b1;
    vifs[0] = first_if;
    vifs[1] = second_if;
    selected_receiver = 1;
    selected_index = 7;
    if (receiver_calls != 2 || select_calls != 2) begin
      failures++;
      $display("FAILED VIF receiver/index evaluated %0d/%0d times",
               receiver_calls, select_calls);
    end
    #4;
    if (first_if.raw !== 8'h00 || second_if.raw !== 8'h00) begin
      failures++;
      $display("FAILED VIF selected drive landed before output skew: %h %h",
               first_if.raw, second_if.raw);
    end
    #2;
    if (first_if.raw !== 8'h02 || second_if.raw !== 8'h10) begin
      failures++;
      $display("FAILED VIF receiver/index capture: first=%h second=%h",
               first_if.raw, second_if.raw);
    end
    if (failures != 0)
      $fatal(1, "%0d VIF selected clocking checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
