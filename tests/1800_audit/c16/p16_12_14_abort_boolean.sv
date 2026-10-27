module test;
  bit clk = 0;
  int failures;

  always #5 clk = ~clk;

  assert property (@(posedge clk) accept_on(1'b1) 1'b0)
    else failures++;
  assert property (@(posedge clk) reject_on(1'b1) 1'b1)
    else failures++;
  assert property (@(posedge clk) sync_accept_on(1'b1) 1'b0)
    else failures++;
  assert property (@(posedge clk) sync_reject_on(1'b1) 1'b1)
    else failures++;

  initial begin
    @(posedge clk);
    #1;
    if (failures != 2) begin
      $display("FAIL: abort failures=%0d (expected 2)", failures);
      $fatal(1);
    end
    $display("PASSED: §16.12.14 Boolean abort semantics");
    $finish;
  end
endmodule
