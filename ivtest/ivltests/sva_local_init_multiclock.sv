// IEEE 1800-2023 16.13.7: a local variable declaration assignment in a
// property with two semantic leading clocks. Each operand gets its own
// copy of v, initialized from e at the first tick of its own clock
// strictly after the |=> antecedent (16.13.2), and uses only that copy.
// Pass and fail times are checked against a per-attempt reference model
// over random stimulus. clk, clk1 and clk2 have different periods, so the
// two copies of v generally get different values of e.
module sva_local_init_multiclock;
  localparam int N = 60;
  bit clk = 0, clk1 = 0, clk2 = 0;
  logic a, b, c, d, e, f;
  bit va[N+40], vb[N+40], vc[N+40], vd[N+40], ve[N+40], vf[N+40];
  int pass_q[$], fail_q[$];
  int errors = 0, last;

  always #5 clk = ~clk;    // posedge 10k+5
  always #7 clk1 = ~clk1;  // posedge 14j+7
  always #11 clk2 = ~clk2; // posedge 22j+11

  property p;
    logic v = e;
    (@(posedge clk1) (a == v)[*1:$] |-> b)
    and
    (@(posedge clk2) c[*1:$] |-> d == v);
  endproperty
  a1: assert property (@(posedge clk) f |=> p)
        pass_q.push_back($time); else fail_q.push_back($time);

  localparam int PENDING = 1 << 30;
  typedef struct { bit ok; int at; } v_t;
  function automatic int at(int x);   // stimulus index at time x
    return x / 10;
  endfunction
  function automatic int next_tick(int x, int period, int phase);
    int y = phase;
    while (y <= x) y += period;
    return y;
  endfunction
  // `run[*1:$] |-> good' started at tick s of a clock: every tick of the
  // run is an end point that needs `good'; the run ends at the first tick
  // where it does not hold.
  function automatic v_t repeat_imp(int s, int period, int which, bit v);
    v_t r;
    r.ok = 1; r.at = PENDING;
    for (int y = s; at(y) < N + 30; y += period) begin
      bit run = which == 1 ? (va[at(y)] == v) : vc[at(y)];
      bit good = which == 1 ? vb[at(y)] : (vd[at(y)] == v);
      if (!run) begin r.at = y; return r; end
      if (!good) begin r.ok = 0; r.at = y; return r; end
    end
    return r;
  endfunction

  initial begin
    int ep[$], ef[$];
    void'($urandom(873));
    for (int k = 0; k < N + 40; k++) begin
      ve[k] = $urandom_range(0, 1);
      va[k] = $urandom_range(0, 3) != 0 ? ve[k] : !ve[k];
      vb[k] = $urandom_range(0, 4) != 0;
      vc[k] = $urandom_range(0, 1);
      vd[k] = $urandom_range(0, 1);
      vf[k] = $urandom_range(0, 2) == 0;
    end
    {a, b, c, d, e, f} = {va[0], vb[0], vc[0], vd[0], ve[0], vf[0]};
    for (int k = 1; k < N + 40; k++)
      @(negedge clk) {a, b, c, d, e, f} = {va[k], vb[k], vc[k], vd[k], ve[k], vf[k]};
    last = $time;
    for (int t = 0; 10*t + 5 < 10*N; t++) begin
      int T, t1, t2;
      v_t r1, r2;
      T = 10*t + 5;
      if (!vf[t]) begin ep.push_back(T); continue; end
      t1 = next_tick(T, 14, 7);
      t2 = next_tick(T, 22, 11);
      r1 = repeat_imp(t1, 14, 1, ve[at(t1)]);
      r2 = repeat_imp(t2, 22, 2, ve[at(t2)]);
      if (!r1.ok || !r2.ok) begin
        int x;
        x = PENDING;
        if (!r1.ok) x = r1.at;
        if (!r2.ok && r2.at < x) x = r2.at;
        ef.push_back(x);
      end else if (r1.at != PENDING && r2.at != PENDING)
        ep.push_back(r1.at > r2.at ? r1.at : r2.at);
    end
    // only decisions inside the checked window
    while (pass_q.size() && pass_q[$] > 10*N) void'(pass_q.pop_back());
    while (fail_q.size() && fail_q[$] > 10*N) void'(fail_q.pop_back());
    for (int i = ep.size() - 1; i >= 0; i--) if (ep[i] > 10*N) ep.delete(i);
    for (int i = ef.size() - 1; i >= 0; i--) if (ef[i] > 10*N) ef.delete(i);
    pass_q.sort(); fail_q.sort(); ep.sort(); ef.sort();
    if (pass_q != ep || fail_q != ef) begin
      $display("FAIL: pass %p expected %p", pass_q, ep);
      $display("FAIL: fail %p expected %p", fail_q, ef);
      errors++;
    end
    if (errors == 0) $display("PASSED");
    $finish;
  end
endmodule
