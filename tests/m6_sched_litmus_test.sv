// M6 scheduler litmus tests (characterization regressions for the
// scheduler audit — docs/conformance/scheduler_audit_2026_07.md).
// Each checks an IEEE 1800-2017 clause-4 required ordering that the
// current stratified queues deliver; they must stay green through any
// scheduler restructuring.
module m6_sched_litmus_test;
  int errors = 0;

  // (a) NBA update is not visible to blocking reads in the same slot
  // before the NBA region runs (4.9.3): b reads the OLD value of a.
  int a = 1, b = 0;
  initial begin
    a <= 2;
    b = a;                  // Active region: must see a==1
    if (b !== 1) begin $display("FAIL litmus-a b=%0d", b); errors++; end
    #1;
    if (a !== 2) begin $display("FAIL litmus-a2 a=%0d", a); errors++; end
  end

  // (b) #0 defers to the Inactive region: the peer initial block's
  // active-region assignment is visible after #0 (4.4.2.3).
  int x = 0;
  initial begin
    #0;
    if (x !== 5) begin $display("FAIL litmus-b x=%0d", x); errors++; end
  end
  initial x = 5;

  // (c) $strobe runs in the Postponed region and sees the NBA result;
  // an immediate check in the Active region sees the old value (4.4.2.9).
  int c = 10;
  initial begin
    c <= 20;
    if (c !== 10) begin $display("FAIL litmus-c1 c=%0d", c); errors++; end
    $strobe("strobe c=%0d (expect 20)", c);
  end

  initial begin
    #2;
    if (errors == 0) $display("PASS");
    $finish;
  end
endmodule
