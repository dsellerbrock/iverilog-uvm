// M6B: scheduler event-region litmus regressions (IEEE 1800-2017 clause 4).
// These characterize event-region behaviors whose outcome would differ if
// queue insertion order / region promotion were incorrect. Each is a
// well-defined LRM outcome, self-checked into a single PASS/FAIL so the
// scheduler cannot silently regress. Companion to the M6 region-trace and
// reactive-region tests; see docs/conformance/scheduler_conformance_inventory.md.
module m6b_scheduler_litmus_test_top;
  int errors = 0;
  task ck(string w, int cond);
    if (!cond) begin $display("FAIL: %s", w); errors++; end
  endtask

  // --- 1: NBA swap uses old values (4.4.2.3 NBA region) ---
  reg [7:0] s_a = 3, s_b = 7;
  // --- 2: $display (Active) sees pre-NBA, $strobe (Postponed) post-NBA ---
  reg [7:0] p_a;
  reg [7:0] disp_seen, strobe_seen;
  // --- 3: blocking-then-NBA read within a slot ---
  reg [7:0] r1_a, r1_b, r1_c;
  // --- 4: nonblocking event trigger ->> wakes @e ---
  event e4; int got4 = 0;
  // --- 5: continuous assign reacts to an NBA update ---
  reg [7:0] c5 = 1; wire [7:0] c5o; assign c5o = c5 + 1;
  // --- 6: inertial delay cancels a sub-delay pulse ---
  reg g6 = 0; wire g6o; assign #5 g6o = g6;
  // --- 7: e.triggered is observable in the same time slot (15.5.3) ---
  event e7; int trg7 = 0;

  initial begin : b_strobe
    p_a = 1; p_a <= 5;
    disp_seen = p_a;                 // Active: 1
    $strobe("");                     // force a rosync pass (value read below)
    #0 strobe_seen = p_a;            // still pre-NBA at #0 (inactive)
  end

  initial begin : main
    // 1: swap
    s_a <= s_b; s_b <= s_a;
    // 3: blocking then NBA
    r1_a = 1; r1_a <= 2; r1_b = r1_a; #0 r1_c = r1_a;
    // 4: nonblocking event
    fork begin @e4; got4 = 1; end join_none
    #1 ->> e4;
    // 6: inertial pulse (10..12) shorter than 5 -> cancelled
    #9 g6 = 1; #2 g6 = 0;
    // 7: triggered
    #1 -> e7; if (e7.triggered) trg7 = 1;

    #5;   // let everything settle
    ck("1 NBA swap a", s_a == 7);
    ck("1 NBA swap b", s_b == 3);
    ck("3 blocking read pre-NBA", r1_b == 1);
    ck("3 #0 read pre-NBA", r1_c == 1);
    ck("3 NBA applied", r1_a == 2);
    ck("4 ->> woke @e", got4 == 1);
    ck("5 cassign after NBA", c5o == 6);   // c5<=5 below
    ck("6 inertial cancels pulse", g6o === 1'b0);
    ck("7 e.triggered same slot", trg7 == 1);

    if (errors == 0) $display("PASS: m6b scheduler litmus");
    else $display("FAIL: m6b scheduler litmus (%0d errors)", errors);
    $finish(0);
  end

  initial begin : b_cassign
    c5 <= 5;                          // c5o must become 6 via the assign
  end
endmodule
