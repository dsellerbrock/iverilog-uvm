// IEEE 1800-2023 16.12.6 (if-else with property branches) and 16.12.7 with
// a property operator as the implication consequent. Pass and fail times
// of each assertion are checked against a per-attempt reference model over
// random stimulus. i3's antecedent has two possible end points, each
// starting its own consequent evaluation; i4 is the 16.12.14 example shape
// (synchronous form), i5 its asynchronous form with stop pulsing between
// ticks.
module sva_property_if_consequent;
  localparam int N = 70;
  bit clk = 0;
  bit a, b, c, d, f, g, stop;
  bit va[N+6], vb[N+6], vc[N+6], vd[N+6], vf[N+6], vg[N+6];
  bit pulse[N+6];  // stop high between tick k-1 and tick k
  int pass_q[6][$], fail_q[6][$];
  int errors = 0, last;

  always #5 clk = ~clk;  // tick k at 10k+5

  i0: assert property (@(posedge clk) if (c) (a |=> b) else (d ##1 f))
        pass_q[0].push_back($time); else fail_q[0].push_back($time);
  i1: assert property (@(posedge clk) if (c) (a |=> b))
        pass_q[1].push_back($time); else fail_q[1].push_back($time);
  i2: assert property (@(posedge clk) a ##1 b |-> if (c) (d |=> f) else (f ##1 d))
        pass_q[2].push_back($time); else fail_q[2].push_back($time);
  i3: assert property (@(posedge clk) a ##[1:2] b |=> (c |-> d) and (f |-> ##1 d))
        pass_q[3].push_back($time); else fail_q[3].push_back($time);
  i4: assert property (@(posedge clk) g ##1 a[*2] |-> sync_reject_on(c) b[->2])
        pass_q[4].push_back($time); else fail_q[4].push_back($time);
  i5: assert property (@(posedge clk) g ##1 a[*2] |-> reject_on(stop) b[->2])
        pass_q[5].push_back($time); else fail_q[5].push_back($time);

  localparam int PENDING = 1 << 30;
  typedef struct { bit ok; int at; } v_t;
  function automatic v_t mk(bit ok, int at);
    v_t r; r.ok = ok; r.at = at; return r;
  endfunction
  function automatic v_t imp_ab(int t);   // a |=> b
    return mk(!va[t] || vb[t+1], va[t] ? t+1 : t);
  endfunction
  function automatic v_t seq_df(int t);   // d ##1 f
    return mk(vd[t] && vf[t+1], vd[t] ? t+1 : t);
  endfunction
  function automatic v_t p_and(v_t p, v_t q);
    if (!p.ok && !q.ok) return mk(0, p.at < q.at ? p.at : q.at);
    if (!p.ok) return p;
    if (!q.ok) return q;
    return mk(1, p.at > q.at ? p.at : q.at);
  endfunction
  // Implication from its end points: fail at the first failing
  // evaluation, else succeed when the antecedent is done and every
  // evaluation has succeeded.
  function automatic v_t implication(int done, v_t evals[$]);
    v_t r = mk(1, done);
    int first_fail = PENDING;
    foreach (evals[i]) begin
      if (!evals[i].ok && evals[i].at < first_fail) first_fail = evals[i].at;
      if (evals[i].at > r.at) r.at = evals[i].at;
    end
    if (first_fail != PENDING) return mk(0, first_fail);
    return r;
  endfunction

  function automatic v_t model(int id, int t);
    v_t ev[$];
    case (id)
      0: return vc[t] ? imp_ab(t) : seq_df(t);
      1: return vc[t] ? imp_ab(t) : mk(1, t);
      2: begin
           if (va[t] && vb[t+1]) begin
             int e = t + 1;
             // if (c) (d |=> f) else (f ##1 d), started at e
             ev.push_back(vc[e] ? mk(!vd[e] || vf[e+1], vd[e] ? e+1 : e)
                                : mk(vf[e] && vd[e+1], vf[e] ? e+1 : e));
           end
           return implication(va[t] ? t+1 : t, ev);
         end
      3: begin
           for (int e = t + 1; e <= t + 2; e++)
             if (va[t] && vb[e]) begin
               int s = e + 1;  // |=>
               ev.push_back(p_and(mk(!vc[s] || vd[s], s),
                                  mk(!vf[s] || vd[s+1], vf[s] ? s+1 : s)));
             end
           return implication(va[t] ? t+2 : t, ev);
         end
      4, 5: begin
           int done = !vg[t] ? t : !va[t+1] ? t+1 : t+2;
           if (vg[t] && va[t+1] && va[t+2]) begin
             int e = t + 2, n = 0;
             v_t r = mk(1, PENDING);
             for (int k = e; k < N + 6; k++)
               if (vb[k] && ++n == 2) begin r.at = k; break; end
             if (id == 4) begin
               for (int k = e; k <= r.at && k < N + 6; k++)
                 if (vc[k]) begin r = mk(0, k); break; end
             end else begin
               // a pulse between ticks k-1 and k, e < k, decides when it
               // falls, just before tick k (user ruling 2026-11-06)
               for (int k = e + 1; k <= r.at && k < N + 6; k++)
                 if (pulse[k]) begin r = mk(0, k); break; end
             end
             ev.push_back(r);
           end
           return implication(done, ev);
         end
    endcase
  endfunction

  function automatic void check(int id);
    int ep[$], ef[$];
    for (int t = 0; t <= last; t++) begin
      v_t r = model(id, t);
      if (r.at > last) continue;
      // i5 fails only on a stop pulse, which falls at 10k+3
      if (r.ok) ep.push_back(10*r.at + 5); else ef.push_back(10*r.at + (id == 5 ? 3 : 5));
    end
    pass_q[id].sort(); fail_q[id].sort(); ep.sort(); ef.sort();
    if (pass_q[id] != ep || fail_q[id] != ef) begin
      $display("FAIL i%0d: pass %p expected %p", id, pass_q[id], ep);
      $display("FAIL i%0d: fail %p expected %p", id, fail_q[id], ef);
      errors++;
    end
  endfunction

  initial begin
    void'($urandom(874));
    for (int t = 0; t < N + 6; t++) begin
      va[t] = $urandom_range(0, 3) != 0; vb[t] = $urandom_range(0, 1);
      vc[t] = $urandom_range(0, 2) == 0; vd[t] = $urandom_range(0, 3) != 0;
      vf[t] = $urandom_range(0, 1);      vg[t] = $urandom_range(0, 1);
      pulse[t] = t > 0 && $urandom_range(0, 4) == 0;
    end
    {a, b, c, d, f, g} = {va[0], vb[0], vc[0], vd[0], vf[0], vg[0]};
    for (int t = 1; t < N + 4; t++) begin
      @(negedge clk) {a, b, c, d, f, g} = {va[t], vb[t], vc[t], vd[t], vf[t], vg[t]};
      #2 if (pulse[t]) begin stop = 1; #1 stop = 0; end
    end
    @(posedge clk);
    #1 last = N + 3;
    for (int i = 0; i < 6; i++) check(i);
    if (errors == 0) $display("PASSED");
    $finish;
  end
endmodule
