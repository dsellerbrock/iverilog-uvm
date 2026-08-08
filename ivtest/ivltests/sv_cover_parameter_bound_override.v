// IEEE 1800-2017 16.9.2: an overridable module parameter used in a cover
// property delay or exact consecutive-repetition bound is resolved separately
// for every elaborated instance. The declaration default is intentionally
// unlike either override so parse-time default folding cannot pass this test.
module cover_parameter_bound_checker #(
  parameter int N = 9
) (
  input logic clk,
  input logic a,
  input logic b
);
  cw: cover property (@(posedge clk) a |-> ##[0:N] b);  // inst 0
  cr: cover property (@(posedge clk) a[* (N+1)]);       // inst 1
endmodule

module sv_cover_parameter_bound_override;
  logic clk = 0;
  logic a = 0;
  logic b = 0;

  always #5 clk = ~clk;

  cover_parameter_bound_checker #(.N(0)) zero (.*);
  cover_parameter_bound_checker #(.N(2)) two  (.*);

  initial begin
    // Three consecutive a samples, with b true only on the third. For N=0,
    // only the same-tick window matches while [*1] matches all three starts.
    // For N=2, all three windows see b and [*3] has one exact match.
    @(negedge clk) a = 1;
    @(negedge clk) a = 1;
    @(negedge clk) begin a = 1; b = 1; end
    @(negedge clk) begin a = 0; b = 0; end
    @(negedge clk);

    if (zero._ivl_sva0_cnt0 !== 1 || zero._ivl_sva1_cnt0 !== 3) begin
      $display("FAILED: N=0 covers were %0d,%0d, expected 1,3",
               zero._ivl_sva0_cnt0, zero._ivl_sva1_cnt0);
      $finish_and_return(1);
    end
    if (two._ivl_sva0_cnt0 !== 3 || two._ivl_sva1_cnt0 !== 1) begin
      $display("FAILED: N=2 covers were %0d,%0d, expected 3,1",
               two._ivl_sva0_cnt0, two._ivl_sva1_cnt0);
      $finish_and_return(1);
    end

    $display("PASSED");
    $finish;
  end
endmodule
