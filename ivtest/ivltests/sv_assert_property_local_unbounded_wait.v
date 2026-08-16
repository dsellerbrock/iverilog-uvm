// IEEE 1800-2017 16.9.2, 16.10: Caliptra's deterministic unbounded-wait
// implication captures a full-width property local for each overlapping
// attempt.  !valid[*0:$] ##1 valid has exactly one endpoint: the first later
// valid tick.  The two values differ above bit 64 to catch a narrowed/shared
// local-variable carrier.
package sv_assert_property_local_unbounded_wait_pkg;
  parameter int KeyWidth = 256;
endpackage

module sv_assert_property_local_unbounded_wait;
  logic clk = 0;
  logic rst_n = 0;
  logic start = 0;
  logic valid = 0;
  logic [(sv_assert_property_local_unbounded_wait_pkg::KeyWidth/32)-1:0]
        [3:0][7:0] key = 0, observed = 0;
  int failures = 0;
  int wrong_time = 0;

  always #5 clk = ~clk;

  property captures_until_first_valid;
    logic [(sv_assert_property_local_unbounded_wait_pkg::KeyWidth/32)-1:0]
          [3:0][7:0] saved;
    @(posedge clk) disable iff (!rst_n)
      (start, saved = key) ##0 (!valid)[*0:$] ##1 valid
      |-> (observed == saved);
  endproperty

  ap: assert property (captures_until_first_valid)
        else begin
          failures++;
          wrong_time += ($time != 45);
        end

  initial begin
    @(negedge clk) rst_n = 1;

    // A starts at t=25 and B at t=35. Both terminate on the first valid at
    // t=45. A passes; B deliberately fails, proving independent captures.
    @(negedge clk);
    start = 1;
    key = 256'h0123456789abcdef_fedcba9876543210_1111222233334444_aaaabbbbccccdddd;
    @(negedge clk);
    key = 256'hdeadbeefcafef00d_0123456789abcdef_5555666677778888_9999aaaabbbbcccc;
    @(negedge clk);
    start = 0;
    valid = 1;
    observed = 256'h0123456789abcdef_fedcba9876543210_1111222233334444_aaaabbbbccccdddd;
    @(negedge clk) valid = 0;

    repeat (2) @(negedge clk);
    if (failures != 1 || wrong_time != 0)
      $fatal(1, "failures=%0d wrong_time=%0d", failures, wrong_time);
    $display("PASSED");
    $finish;
  end
endmodule
