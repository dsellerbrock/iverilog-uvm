module issue3803_scoped(output bit done);
  logic start = 0, ending = 0, rhs_start = 0, rhs_end = 0, unused = 0;
  logic value = 1, stop = 0;
  bit history_ready = 1;
  localparam int HISTORY_TICKS = 1;
  assert property (@(posedge ending) 1'b1) rhs_start = 1;
  sequence suffix;
    value;
  endsequence
  sequence left;
    @(posedge start) 1'b1 ##1 @(posedge ending) suffix;
  endsequence

  for (genvar i = 0; i < 2; ++i) begin : copies
    logic start = 0;
    logic value = 1;
    logic ready = 0;
    sequence suffix;
      value;
    endsequence
    sequence right;
      @(posedge rhs_start) (ready && $past(history_ready, HISTORY_TICKS))
        ##1 @(posedge rhs_end) suffix;
    endsequence
    property asym_p;
      disable iff (stop) left |=> right();
    endproperty

    if (1) begin : inner
      logic rhs_start = 0;
      logic value = 0, ready = 0, stop = 1;
      localparam int HISTORY_TICKS = 2;
      sequence right;
        1'b0;
      endsequence
      int passes = 0;
      assert property (@(posedge unused) asym_p) passes++;
        else $fatal(1, "asymmetric implication failed in copy %0d", i);
    end
  end

  task check_passes(input int expected);
    if (copies[0].inner.passes != expected || copies[1].inner.passes != expected)
      $fatal(1, "asymmetric implication at %0t expected %0d passes, got %0d and %0d",
             $time, expected, copies[0].inner.passes, copies[1].inner.passes);
  endtask

  initial begin
    #2 start = 1;
    #1 start = 0;
    // The Reactive action drives a coincident RHS edge while ready is
    // false. The LHS endpoint samples value before the blocking write.
    #2 value = 0;
    ending = 1;
    #1 {ending, rhs_start} = 2'b00;
    check_passes(0);

    copies[0].ready = 1;
    copies[1].ready = 1;
    #2 rhs_start = 1;
    #1 rhs_start = 0;
    check_passes(0);
    // The RHS suffix reads each enclosing generate iteration's value.
    #2 copies[0].value = 0;
    copies[1].value = 0;
    rhs_end = 1;
    #1 check_passes(1);
    done = 1;
  end
endmodule

module issue3803;
  logic clk = 0, clk1 = 0, clk2 = 0;
  logic a = 1, b = 1, c = 1, d = 1, pause = 0;
  int passes = 0, failures = 0, passes2 = 0, failures2 = 0, hits = 0;
  int default_passes = 0, default_failures = 0;
  wire scoped_done;
  issue3803_scoped scoped_test(scoped_done);

  // IEEE 1800-2017/2023 16.13.4(a), (e).
  sequence s1;
    a ##1 b;
  endsequence
  sequence s2;
    c ##1 d;
  endsequence
  sequence mult_s;
    @(posedge clk) a ##1 @(posedge clk1) s1 ##1 @(posedge clk2) s2;
  endsequence
  property mult_p;
    mult_s |=> mult_s;
  endproperty

  assert property (mult_p) passes++; else failures++;
  assert property (disable iff (pause) mult_p) passes2++; else failures2++;
  cover property (mult_p) hits++;
  if (1) begin : use_default_disable
    assert property (mult_p) default_passes++; else default_failures++;
    default disable iff (pause);
  end

  task tick(input bit [2:0] edges);
    #2 {clk, clk1, clk2} = edges;
    #1 {clk, clk1, clk2} = 0;
  endtask

  task check(input int p, f, p2, f2, h);
    if (passes != p || failures != f || passes2 != p2 || failures2 != f2 || hits != h)
      $fatal(1, "at %0t expected %0d/%0d %0d/%0d %0d, got %0d/%0d %0d/%0d %0d",
             $time, p, f, p2, f2, h, passes, failures, passes2, failures2, hits);
    if (default_passes != p2 || default_failures != f2)
      $fatal(1, "default disable at %0t expected %0d/%0d, got %0d/%0d",
             $time, p2, f2, default_passes, default_failures);
  endtask

  initial begin
    tick(3'b100);
    tick(3'b010);
    tick(3'b010);
    tick(3'b001);
    a = 0;
    tick(3'b101); // LHS completes. Coincident clk gives only a new vacuous attempt.
    check(1, 0, 1, 0, 0);

    a = 1;
    tick(3'b100); // First strictly future RHS clock, and a second LHS start.
    tick(3'b010);
    tick(3'b010);
    tick(3'b001);
    check(1, 0, 1, 0, 0);
    // Cancel two instances before the final edge, in that edge's time slot.
    #2 pause = 1;
    #0 pause = 0;
    #0 clk2 = 1;
    #1 clk2 = 0;
    check(2, 0, 1, 0, 1);

    tick(3'b100);
    tick(3'b010);
    tick(3'b010);
    tick(3'b001);
    check(2, 0, 1, 0, 1);
    d = 0;
    tick(3'b001); // Last stage misses in both an RHS and a parallel LHS.
    check(3, 1, 2, 0, 1);
    if (!scoped_done) $fatal(1, "asymmetric implication test did not complete");
    $display("PASSED");
    $finish(0);
  end
endmodule
