// M9C: SVA `until` family (IEEE 1800-2017 16.12.10) — until, until_with,
// s_until, s_until_with. Previously all four were loud sorries.
//
// Under overlapping-attempt semantics (a fresh attempt every clock) the
// aggregate obligation of `p until q` collapses to a per-cycle boolean:
//   until       fails at any cycle with (!p && !q)
//   until_with  fails at any cycle with (!p)          [q irrelevant]
// The strong forms add a liveness obligation (q must eventually hold);
// with a profile where q does arrive and the pending flag clears by the
// end, the strong forms fail exactly where their weak counterparts do.
// (The liveness end-of-simulation failure is exercised separately in
// m9c_until_live_test.sv.)
module m9c_until_test_top;
  logic clk = 0, p = 1, q = 1;
  int f_u = 0, f_uw = 0, f_su = 0, f_suw = 0;
  int errors = 0;
  always #5 clk = ~clk;

  u:   assert property (@(posedge clk) p until        q) else f_u++;
  uw:  assert property (@(posedge clk) p until_with   q) else f_uw++;
  su:  assert property (@(posedge clk) p s_until      q) else f_su++;
  suw: assert property (@(posedge clk) p s_until_with q) else f_suw++;

  // Profile (q eventually arrives; pending clears by the end).
  //  idx: 0 1 2 3 4 5 6 7
  //  p:   1 1 0 1 0 1 1 0
  //  q:   0 0 1 0 0 0 1 1
  // weak until  fails (!p&&!q): idx4                 -> 1
  // until_with  fails (!p):     idx2, idx4, idx7     -> 3
  localparam int N = 8;
  bit [0:N-1] pv = 8'b1101_0110;
  bit [0:N-1] qv = 8'b0010_0011;

  task check(string w, int got, int exp);
    if (got !== exp) begin
      $display("FAIL: %s got=%0d exp=%0d", w, got, exp);
      errors++;
    end
  endtask

  initial begin
    // Two neutral idle cycles (p=1,q=1): no fail, pending cleared.
    p=1; q=1; @(posedge clk); #1;
    p=1; q=1; @(posedge clk); #1;
    for (int i = 0; i < N; i++) begin
      p = pv[i]; q = qv[i];
      @(posedge clk); #1;
    end
    // Trailing neutral cycles to settle.
    p=1; q=1; @(posedge clk); #1;
    p=1; q=1; @(posedge clk); #1;

    check("until",        f_u,   1);
    check("until_with",   f_uw,  3);
    check("s_until",      f_su,  1);   // weak part only (q arrives)
    check("s_until_with", f_suw, 3);   // weak part only (q arrives)

    if (errors == 0) $display("PASS: m9c until family");
    else $display("FAIL: m9c until family (%0d errors)", errors);
    $finish(0);
  end
endmodule
