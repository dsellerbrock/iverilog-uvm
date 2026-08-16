// IEEE 1800-2017 16.10: a property-local packed variable is assigned by a
// sequence match item and retains a distinct value for every overlapping
// attempt.  The three packed dimensions mirror Caliptra's AES-key property;
// the 256-bit value also catches the former fixed-64-bit synthesized carrier.
package sv_assert_property_local_packed_pkg;
  parameter int KeyWidth = 256;
endpackage

module sv_assert_property_local_packed;
  logic clk = 0;
  logic rst_n = 0;
  logic start = 0;
  logic [(sv_assert_property_local_packed_pkg::KeyWidth/32)-1:0][3:0][7:0]
        key = 0, observed = 0;
  int failures = 0;

  always #5 clk = ~clk;

  property captures_each_attempt;
    logic [(sv_assert_property_local_packed_pkg::KeyWidth/32)-1:0][3:0][7:0]
          saved;
    @(posedge clk) disable iff (!rst_n)
      (start, saved = key) |=> (observed == saved);
  endproperty

  ap: assert property (captures_each_attempt)
        else failures++;

  initial begin
    @(negedge clk) rst_n = 1;

    // The first obligation observes A while a second attempt captures B.
    // A shared/live rather than per-attempt saved value fails this tick.
    @(negedge clk);
    start = 1;
    key = 256'h0123456789abcdef_fedcba9876543210_1111222233334444_aaaabbbbccccdddd;
    @(negedge clk);
    key = 256'hdeadbeefcafef00d_0123456789abcdef_5555666677778888_9999aaaabbbbcccc;
    observed = 256'h0123456789abcdef_fedcba9876543210_1111222233334444_aaaabbbbccccdddd;
    @(negedge clk);
    start = 0;
    observed = 256'hdeadbeefcafef00d_0123456789abcdef_5555666677778888_9999aaaabbbbcccc;

    repeat (2) @(negedge clk);
    if (failures != 0)
      $fatal(1, "property-local packed capture failures=%0d", failures);
    $display("PASSED");
    $finish;
  end
endmodule
