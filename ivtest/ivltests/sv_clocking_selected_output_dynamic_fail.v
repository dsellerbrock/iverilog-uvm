module sv_clocking_selected_output_dynamic_fail;
  logic clk = 1'b0;
  logic [7:0] raw = '0;
  wire [7:0] bus;
  integer idx = 3;

  assign bus = raw;

  clocking cb @(posedge clk);
    output bus = raw;
  endclocking

  always #5 clk = ~clk;

  initial begin
    #1;
    cb.bus[idx] <= 1'b1;
    idx = 5;
    #6;
    if (raw !== 8'h08)
      $fatal(1, "FAILED selected clocking output did not capture index 3: %h", raw);
    $display("PASSED");
    $finish;
  end
endmodule
