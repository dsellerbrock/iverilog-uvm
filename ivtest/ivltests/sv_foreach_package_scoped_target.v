// IEEE 1800-2017/2023 12.7.3 -- foreach over a PACKAGE-SCOPED array target.
//
// The lexer returns PACKAGE_IDENTIFIER, not IDENTIFIER, for a package it has
// already seen (lexor.lex), and foreach_array_identifier carried an
// IDENTIFIER K_SCOPE_RES IDENTIFIER alternative but no PACKAGE_IDENTIFIER one.
// `foreach (pkg::q[i])' therefore matched no production at all and died as a
// bare "syntax error" naming no mechanism.
//
// OpenTitan reaches this through sec_cm_pkg::sec_cm_if_proxy_q, a package-level
// queue that every sec_cm interface pushes onto and rstmgr_cnsty_chk's tb.sv
// walks with `foreach (sec_cm_pkg::sec_cm_if_proxy_q[i])'.
//
// Every check below is red as a syntax error on the pre-change compiler.
//
// Deliberately NOT covered, because they are separate unsupported shapes that
// still fail loudly and are recorded as such: a package-scoped name used as an
// assignment l-value (`pkg::d = new[3]', `pkg::q[0] = 9'); a method call on an
// INDEXED package-scoped name (`pkg::m[0].push_back(4)', where the unindexed
// `pkg::q.push_back(4)' does work); and foreach over a PACKED-array parameter
// (`localparam logic [3:0][1:0] M; foreach (M[i])'), which fails identically
// with no package involved at all.

package fe_pkg;
  int           q[$];               // queue variable
  parameter int A[3] = '{5, 6, 7};  // unpacked parameter array
endpackage

module main;

  int errors = 0;
  int seen;
  int idx_sum;

  task automatic check(string what, int got, int exp);
    if (got !== exp) begin
      $display("FAILED: %0s got %0d want %0d", what, got, exp);
      errors += 1;
    end
  endtask

  initial begin

    // ---- package-scoped queue: the OpenTitan shape -------------------------
    fe_pkg::q.push_back(11);
    fe_pkg::q.push_back(22);
    fe_pkg::q.push_back(33);
    seen = 0; idx_sum = 0;
    foreach (fe_pkg::q[i]) begin
      seen += fe_pkg::q[i];
      idx_sum += i;
    end
    check("queue sum", seen, 66);
    check("queue index sum", idx_sum, 3);

    // an EMPTY package queue must run the body zero times, not once
    fe_pkg::q.delete();
    seen = 0;
    foreach (fe_pkg::q[i]) seen += 1;
    check("empty queue iterations", seen, 0);

    // ---- package-scoped unpacked PARAMETER array ---------------------------
    seen = 0; idx_sum = 0;
    foreach (fe_pkg::A[i]) begin
      seen += fe_pkg::A[i];
      idx_sum += i;
    end
    check("parameter sum", seen, 18);
    check("parameter index sum", idx_sum, 3);

    // ---- control: a LOCAL queue iterates exactly as it always did ----------
    begin
      automatic int lq[$];
      lq.push_back(7);
      lq.push_back(8);
      seen = 0;
      foreach (lq[i]) seen += lq[i];
      check("local queue control", seen, 15);
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d error(s)", errors);
  end

endmodule
