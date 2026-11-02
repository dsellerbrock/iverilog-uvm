package seq_pkg;
  sequence one;
    1'b0;
  endsequence
endpackage

sequence unit_one;
  1'b0;
endsequence

module top;
  logic clk = 0;
  int package_failures = 0;
  int unit_failures = 0;
  always #5 clk = ~clk;

  package_sequence: assert property (@(posedge clk) seq_pkg::one)
    else package_failures++;
  unit_sequence: assert property (@(posedge clk) unit_one)
    else unit_failures++;

  initial begin
    repeat (3) @(posedge clk);
    #1;
    if (package_failures == 0 || unit_failures == 0) begin
      $display("FAILED package=%0d unit=%0d", package_failures, unit_failures);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule
