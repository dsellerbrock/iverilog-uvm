// IEEE 1800-2023 16.13.2 / 16.12.7: multiclocked implications whose
// antecedent is unbounded or uses goto repetition. Every end point of the
// antecedent starts its own consequent check at the first c2 tick strictly
// after it. An unbounded antecedent keeps every attempt live forever, so
// many attempts are pending at once; the pass and fail times (with their
// multiplicity) are checked against a per-attempt reference model.
// u3 carries a local variable from the antecedent into every consequent
// check on the other clock (16.10); attempts with equal values may share
// a slot, attempts with different values may not.
module sva_multiclock_unbounded_antecedent;
  localparam int N = 80;
  bit clk = 0, c2 = 0;
  bit a, b, d;
  bit va[N+20], vb[N+20], vd[N+20];
  int x, y;
  int vx[N+20], vy[N+20];
  int pass_q[6][$], fail_q[6][$];
  int errors = 0, last;

  always #5 clk = ~clk;   // posedge 10k+5
  always #7 c2 = ~c2;     // posedge 14j+7; coincides with clk at 35, 175, ...

  u0: assert property (@(posedge clk) a ##[1:$] b |=> @(posedge c2) d)
        pass_q[0].push_back($time); else fail_q[0].push_back($time);
  u1: assert property (@(posedge clk) a[*1:$] ##1 b |=> @(posedge c2) d)
        pass_q[1].push_back($time); else fail_q[1].push_back($time);
  u2: assert property (@(posedge clk) b[->2] |=> @(posedge c2) d)
        pass_q[2].push_back($time); else fail_q[2].push_back($time);
  property p_local;
    int v;
    @(posedge clk) (a, v = x) ##[1:$] b |=> @(posedge c2) y == v;
  endproperty
  u3: assert property (p_local)
        pass_q[3].push_back($time); else fail_q[3].push_back($time);
  // u4: an unbounded consecutive repetition as the whole antecedent;
  // u5: a multiclocked sequence (not an implication) whose first-clock
  // prefix is unbounded: true iff some end point of the prefix is
  // followed by d at the next c2 tick (16.13.1).
  u4: assert property (@(posedge clk) a[*1:$] |=> @(posedge c2) d)
        pass_q[4].push_back($time); else fail_q[4].push_back($time);
  u5: assert property (@(posedge clk) a ##[1:$] b ##1 @(posedge c2) d)
        pass_q[5].push_back($time); else fail_q[5].push_back($time);

  localparam int PENDING = 1 << 30;
  function automatic int at(int x);
    return x / 10;
  endfunction
  function automatic int next_c2(int x);
    int y = 7;
    while (y <= x) y += 14;
    return y;
  endfunction

  // Verdict of one attempt from its end points (ticks) and the tick its
  // antecedent is done (PENDING: never).
  function automatic void judge(int id, int t, int ends[$], int done);
    int fail_at = PENDING, pass_at = done;
    foreach (ends[i]) begin
      int x = next_c2(10*ends[i] + 5);
      bit ok = id == 3 ? vy[at(x)] == vx[t] : vd[at(x)];
      if (!ok && x < fail_at) fail_at = x;
      if (x > pass_at) pass_at = x;
    end
    if (fail_at != PENDING) begin
      if (fail_at < last) fail_q[id].push_back(-fail_at);   // expected
    end else if (done != PENDING && pass_at < last)
      pass_q[id].push_back(-pass_at);
  endfunction

  initial begin
    void'($urandom(446));
    for (int k = 0; k < N + 20; k++) begin
      va[k] = $urandom_range(0, 2) != 0; vb[k] = $urandom_range(0, 3) == 0;
      vd[k] = $urandom_range(0, 5) != 0;
      vx[k] = $urandom_range(0, 1);
      vy[k] = $urandom_range(0, 5) != 0 ? vx[k > 0 ? k - 1 : 0] : 2;
    end
    {a, b, d} = {va[0], vb[0], vd[0]};
    x = vx[0]; y = vy[0];
    for (int k = 1; k < N; k++)
      @(negedge clk) begin {a, b, d} = {va[k], vb[k], vd[k]}; x = vx[k]; y = vy[k]; end
    last = $time;
    // Expected verdicts are queued as negative times next to the actual
    // ones, then separated.
    for (int t = 0; 10*t + 5 < last; t++) begin
      int ends[$];
      int done, n;
      // u0: a ##[1:$] b
      ends.delete();
      if (!va[t]) judge(0, t, ends, 10*t + 5);
      else begin
        for (int e = t + 1; 10*e + 5 < last; e++) if (vb[e]) ends.push_back(e);
        judge(0, t, ends, PENDING);
      end
      // u3: same antecedent shape, consequent compares with v = x at t
      ends.delete();
      if (!va[t]) judge(3, t, ends, 10*t + 5);
      else begin
        for (int e = t + 1; 10*e + 5 < last; e++) if (vb[e]) ends.push_back(e);
        judge(3, t, ends, PENDING);
      end
      // u1: a[*1:$] ##1 b -- end points while the run of a lasts
      ends.delete();
      done = PENDING;
      for (int e = t; 10*e + 5 < last + 200; e++) begin
        if (e > t && vb[e]) ends.push_back(e);
        if (!va[e]) begin done = 10*e + 5; break; end
      end
      judge(1, t, ends, done);
      // u4: a[*1:$] -- every tick of the run of a is an end point
      ends.delete();
      done = PENDING;
      for (int e = t; e < N + 20; e++) begin
        if (!va[e]) begin done = 10*e + 5; break; end
        ends.push_back(e);
      end
      judge(4, t, ends, done);
      // u5: exists an end point of a ##[1:$] b followed by d on c2
      if (!va[t]) fail_q[5].push_back(-(10*t + 5));
      else begin
        int first_ok;
        first_ok = PENDING;
        for (int e = t + 1; 10*e + 5 < last; e++)
          if (vb[e] && vd[at(next_c2(10*e + 5))] && next_c2(10*e + 5) < first_ok)
            first_ok = next_c2(10*e + 5);
        if (first_ok < last) pass_q[5].push_back(-first_ok);
      end
      // u2: b[->2] -- the second b at or after t
      ends.delete();
      n = 0;
      done = PENDING;
      for (int e = t; e < N + 20; e++)
        if (vb[e] && ++n == 2) begin ends.push_back(e); done = 10*e + 5; break; end
      judge(2, t, ends, done);
    end
    for (int id = 0; id < 6; id++) begin
      int ap[$], af[$], ep[$], ef[$];
      ap.delete(); af.delete(); ep.delete(); ef.delete();
      foreach (pass_q[id][i]) if (pass_q[id][i] < 0) ep.push_back(-pass_q[id][i]);
                              else if (pass_q[id][i] < last) ap.push_back(pass_q[id][i]);
      foreach (fail_q[id][i]) if (fail_q[id][i] < 0) ef.push_back(-fail_q[id][i]);
                              else if (fail_q[id][i] < last) af.push_back(fail_q[id][i]);
      ap.sort(); af.sort(); ep.sort(); ef.sort();
      if (ap != ep || af != ef) begin
        $display("FAIL u%0d: pass %p expected %p", id, ap, ep);
        $display("FAIL u%0d: fail %p expected %p", id, af, ef);
        errors++;
      end
    end
    if (errors == 0) $display("PASSED");
    $finish;
  end
endmodule
