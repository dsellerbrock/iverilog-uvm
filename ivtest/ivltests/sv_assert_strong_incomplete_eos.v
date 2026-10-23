// IEEE 1800-2017/2023 16.12.15: a strong sequence that is still
// incomplete when simulation ends cannot match in any continuation and
// therefore fails. The otherwise identical weak sequence does not fail.
module sv_assert_strong_incomplete_eos;
  logic clk = 0;
  int strong_failures = 0;
  int weak_failures = 0;

  always #5 clk = ~clk;

  strong_seq: assert property (@(posedge clk)
      strong(1'b1 ##1 1'b1))
    else strong_failures++;

  weak_seq: assert property (@(posedge clk)
      weak(1'b1 ##1 1'b1))
    else weak_failures++;

  initial begin
    @(posedge clk);
    #1 $finish(0);
  end

  final begin
    if (strong_failures != 1) begin
      $display("FAILED: incomplete strong sequence reported %0d failures, want 1",
               strong_failures);
      $finish_and_return(1);
    end
    if (weak_failures != 0) begin
      $display("FAILED: incomplete weak sequence reported %0d failures, want 0",
               weak_failures);
      $finish_and_return(1);
    end
    $display("PASSED");
  end
endmodule
