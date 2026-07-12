// M6 item 2: program-block processes schedule in the Reactive region
// set (IEEE 1800-2017 4.4.2.5 Reactive, 4.4.2.6 Re-Inactive, 4.4.2.7
// Re-NBA; clause 24 programs).  Characterizes the required orderings:
//
//  (a) A program process woken by a clock edge observes the design's
//      post-NBA state for that same edge, race-free (the reactive
//      TB-vs-DUT sampling guarantee that motivates programs).
//  (b) #0 in a program defers to Re-Inactive, which runs BEFORE the
//      program's own nonblocking updates (Re-NBA).
//  (c) A program's nonblocking update is observable within the same
//      time slot after the Re-NBA region runs.
//  (d) A design process triggered by a program's blocking write runs
//      in the Active region (iterative loopback) before the program's
//      next #0 continuation.
module m6_reactive_region_test;
  logic clk = 0;
  logic [7:0] count = 0;
  int errors = 0;

  always #5 clk = ~clk;
  always @(posedge clk) count <= count + 1;

  // (d) design reaction to a program's blocking write
  logic pv = 0;
  int seen = 0;
  always @(posedge pv) seen = seen + 1;

  initial begin
    #100;
    $display("FAIL (timeout)");
    $finish;
  end
endmodule

program m6_reactive_tb;
  int errors = 0;
  logic [7:0] x = 0;

  initial begin
    // (a) post-NBA sampling at the clock edge
    @(posedge m6_reactive_region_test.clk);
    if (m6_reactive_region_test.count !== 8'd1) begin
      $display("FAIL a: count=%0d at first edge (expect post-NBA 1)",
               m6_reactive_region_test.count);
      errors++;
    end
    @(posedge m6_reactive_region_test.clk);
    if (m6_reactive_region_test.count !== 8'd2) begin
      $display("FAIL a2: count=%0d at second edge (expect 2)",
               m6_reactive_region_test.count);
      errors++;
    end

    // (b) #0 (Re-Inactive) runs before the program's NBA (Re-NBA)
    x <= 8'hAA;
    #0;
    if (x !== 8'h00) begin
      $display("FAIL b: x=%h after #0 (Re-Inactive must precede Re-NBA)", x);
      errors++;
    end

    // (c) the Re-NBA update is observable in the same time slot
    @(x);
    if (x !== 8'hAA) begin
      $display("FAIL c: x=%h after @(x) (expect Re-NBA value AA)", x);
      errors++;
    end

    // (d) program blocking write -> design Active loopback -> program
    //     #0 continuation sees the design's reaction
    m6_reactive_region_test.pv = 1;
    #0;
    if (m6_reactive_region_test.seen !== 1) begin
      $display("FAIL d: seen=%0d (design loopback must run before program #0)",
               m6_reactive_region_test.seen);
      errors++;
    end

    if (errors == 0) $display("PASS");
    $finish;
  end
endprogram
