// Caliptra's exact nested shape: an unbounded inner antecedent can complete
// more than once, and every $rose endpoint opens its own one-cycle |=>
// consequence. The first endpoint passes and the second fails.
module sv_assert_nested_nonoverlap_unbounded;
  logic clk = 0;
  logic rst_n = 0;
  logic a = 0;
  logic b = 0;
  logic c = 0;
  int failures = 0;
  int wrong_time = 0;

  always #5 clk = ~clk;

  ap: assert property (@(posedge clk) disable iff (!rst_n)
        a |=> (##[1:$] $rose(b) |=> c))
      else begin
        failures++;
        wrong_time += ($time != 75);
      end

  initial begin
    @(negedge clk) rst_n = 1;
    @(negedge clk) a = 1;       // outer antecedent at t=25
    @(negedge clk) a = 0;
    @(negedge clk) b = 1;       // first endpoint at t=45
    @(negedge clk) begin
      b = 0;
      c = 1;                    // first obligation passes at t=55
    end
    @(negedge clk) begin
      b = 1;                    // second endpoint at t=65
      c = 0;
    end
    @(negedge clk) b = 0;       // second obligation fails at t=75

    repeat (3) @(negedge clk);
    if (failures != 1 || wrong_time != 0)
      $fatal(1, "failures=%0d wrong_time=%0d", failures, wrong_time);
    $display("PASSED");
    $finish;
  end
endmodule
