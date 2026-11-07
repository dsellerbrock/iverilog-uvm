// IEEE 1800-2023 16.13.4 example (g): clock flow through an if-else
// property whose branches change clock, checked against a per-attempt
// reference model over random stimulus.
//   c true : (1 |=> @(posedge clk1) d)   d at the first clk1 tick strictly
//                                        after the antecedent end point
//   c false: e ##1 @(posedge clk2) f     e at that end point, then f at the
//                                        first clk2 tick strictly after it
// clk and clk1 coincide at t = 35, 175, ...: an end point there is checked
// at the next clk1 tick, not the coincident one (16.13.1, 16.13.2).
module sva_property_if_multiclock;
  localparam int N = 60;
  bit clk = 0, clk1 = 0, clk2 = 0;
  bit a, b, c, d, e, f;
  bit va[N+8], vb[N+8], vc[N+8], vd[N+8], ve[N+8], vf[N+8];
  int pass_q[$], fail_q[$];
  int errors = 0, last;

  always #5 clk = ~clk;    // posedge 10k+5
  always #7 clk1 = ~clk1;  // posedge 14j+7
  always #11 clk2 = ~clk2; // posedge 22j+11

  property mult_p8;
    @(posedge clk) a ##1 b |->
      if (c)
        (1 |=> @(posedge clk1) d)
      else
        e ##1 @(posedge clk2) f;
  endproperty
  p8: assert property (mult_p8) pass_q.push_back($time); else fail_q.push_back($time);

  // The value a signal has at time x (stimulus changes at 10k).
  function automatic int at(int x);
    return x / 10;
  endfunction
  function automatic int next_tick(int x, int period, int phase);
    int y = phase;
    while (y <= x) y += period;
    return y;
  endfunction

  initial begin
    int ep[$], ef[$];
    void'($urandom(874));
    for (int k = 0; k < N + 8; k++) begin
      va[k] = $urandom_range(0, 3) != 0; vb[k] = $urandom_range(0, 3) != 0;
      vc[k] = $urandom_range(0, 1);      vd[k] = $urandom_range(0, 3) != 0;
      ve[k] = $urandom_range(0, 3) != 0; vf[k] = $urandom_range(0, 3) != 0;
    end
    {a, b, c, d, e, f} = {va[0], vb[0], vc[0], vd[0], ve[0], vf[0]};
    for (int k = 1; k < N; k++)
      @(negedge clk) {a, b, c, d, e, f} = {va[k], vb[k], vc[k], vd[k], ve[k], vf[k]};
    last = $time;
    for (int t = 0; 10*t + 5 < last; t++) begin
      int te, x;
      bit ok;
      te = 10*(t+1) + 5;
      if (!va[t]) begin ep.push_back(10*t + 5); continue; end       // vacuous
      if (te >= last) continue;
      if (!vb[t+1]) begin ep.push_back(te); continue; end           // vacuous
      if (vc[t+1]) begin
        x = next_tick(te, 14, 7);  ok = vd[at(x)];
      end else if (!ve[t+1]) begin
        x = te; ok = 0;
      end else begin
        x = next_tick(te, 22, 11); ok = vf[at(x)];
      end
      if (x >= last) continue;
      if (ok) ep.push_back(x); else ef.push_back(x);
    end
    while (pass_q.size() && pass_q[$] >= last) void'(pass_q.pop_back());
    while (fail_q.size() && fail_q[$] >= last) void'(fail_q.pop_back());
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
