`timescale 1ns/1ps
module sv_clocking_selected_output_dynamic_capture;
  logic clk = 1'b0;
  logic [7:0] raw = '0;
  wire [7:0] bus;
  int selected_index = 2;
  int select_calls = 0;
  int failures = 0;

  assign bus = raw;

  clocking cb @(posedge clk);
    output #2 bus = raw;
  endclocking

  always #5 clk = ~clk;

  function automatic int choose_index;
    select_calls++;
    choose_index = selected_index;
  endfunction

  initial begin
    cb.bus[choose_index()] <= 1'b1;
    selected_index = 6;
    if (select_calls != 1) begin
      failures++;
      $display("FAILED direct selector evaluated %0d times", select_calls);
    end
    #6;
    if (raw !== 8'h00) begin
      failures++;
      $display("FAILED selected clocking drive landed before output skew: %h", raw);
    end
    #2;
    if (raw !== 8'h04) begin
      failures++;
      $display("FAILED direct drive did not capture index 2 with skew: %h", raw);
    end

    selected_index = 7;
    cb.bus[choose_index()] <= 1'b1;
    selected_index = 0;
    #10;
    if (raw !== 8'h84) begin
      failures++;
      $display("FAILED upper-bound selector did not drive bit 7: %h", raw);
    end

    selected_index = 8;
    cb.bus[choose_index() +: 1] <= 1'b1;
    selected_index = 1;
    #10;
    if (raw !== 8'h84) begin
      failures++;
      $display("FAILED out-of-range selector changed the output: %h", raw);
    end

    selected_index = 0;
    cb.bus[choose_index()] <= 1'b1;
    selected_index = 6;
    #10;
    if (raw !== 8'h85) begin
      failures++;
      $display("FAILED lower-bound selector did not drive bit 0: %h", raw);
    end
    if (select_calls != 4) begin
      failures++;
      $display("FAILED direct selector evaluated %0d times", select_calls);
    end
    if (failures != 0)
      $fatal(1, "%0d direct selected clocking checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
