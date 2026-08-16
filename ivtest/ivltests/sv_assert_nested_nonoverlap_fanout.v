// IEEE 1800-2017 A.2.10 / 16.12.7: a parenthesized implication is a legal
// consequent. Every match endpoint of its variable-length antecedent opens
// an independent consequent obligation; accepting the first must not erase
// a later endpoint from the same outer attempt.
module sv_assert_nested_nonoverlap_fanout;
  logic clk = 0;
  logic rst_n = 0;
  logic a = 0;
  logic b = 0;
  logic c = 0;
  int failures = 0;
  int wrong_time = 0;

  always #5 clk = ~clk;

  ap: assert property (@(posedge clk) disable iff (!rst_n)
        a |=> (##[1:3] b |=> c))
      else begin
        failures++;
        wrong_time += ($time != 65);
      end

  initial begin
    @(negedge clk) rst_n = 1;
    @(negedge clk) a = 1;       // outer antecedent at t=25
    @(negedge clk) a = 0;
    @(negedge clk) b = 1;       // first inner endpoint at t=45
    @(negedge clk) c = 1;       // second endpoint + first pass at t=55
    @(negedge clk) begin
      b = 0;
      c = 0;                    // second obligation fails at t=65
    end

    repeat (3) @(negedge clk);
    if (failures != 1 || wrong_time != 0)
      $fatal(1, "failures=%0d wrong_time=%0d", failures, wrong_time);
    $display("PASSED");
    $finish;
  end
endmodule
