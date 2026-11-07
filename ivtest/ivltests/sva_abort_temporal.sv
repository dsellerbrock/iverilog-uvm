// IEEE 1800-2023 16.12.14: abort operators over temporal operands. Pass and
// fail times of each assertion are checked against a per-attempt reference
// model over random stimulus:
// - an abort decides an attempt still being evaluated (accept -> pass,
//   reject -> fail), and wins over an operand verdict in the same step;
// - the sync_ forms see the condition only at clock ticks;
// - the asynchronous forms also see a pulse between ticks (decided when it
//   falls, the first point the checker can see it held; user ruling
//   2026-11-06), but not a glitch that rises and falls in one time step,
//   because the condition is a sampled value;
// - nested aborts: the outer one wins a tie;
// - an aborted operand inside `and'.
module sva_abort_temporal;
  localparam int N = 70;
  bit clk = 0;
  bit a, b, c, d, x, z, y;
  bit va[N+4], vb[N+4], vc[N+4], vd[N+4], vx[N+4], vz[N+4];
  bit pulse[N+4], glitch[N+4];  // y high between tick k-1 and tick k
  int pass_q[7][$], fail_q[7][$];
  int errors = 0, last;

  always #5 clk = ~clk;  // tick k at 10k+5

  s0: assert property (@(posedge clk) sync_accept_on(x) (a ##1 b))
        pass_q[0].push_back($time); else fail_q[0].push_back($time);
  s1: assert property (@(posedge clk) sync_reject_on(x) (a |=> b ##1 c))
        pass_q[1].push_back($time); else fail_q[1].push_back($time);
  s2: assert property (@(posedge clk) accept_on(y) (a ##1 b ##1 c))
        pass_q[2].push_back($time); else fail_q[2].push_back($time);
  s3: assert property (@(posedge clk) reject_on(y) (a |=> b ##1 c))
        pass_q[3].push_back($time); else fail_q[3].push_back($time);
  s4: assert property (@(posedge clk) sync_accept_on(x) sync_reject_on(z) (a ##1 b ##1 c))
        pass_q[4].push_back($time); else fail_q[4].push_back($time);
  s5: assert property (@(posedge clk) (sync_accept_on(x) (a ##1 b)) and (c |-> ##1 d))
        pass_q[5].push_back($time); else fail_q[5].push_back($time);
  // A goto repetition is a sequence, not its boolean (#2672).
  s6: assert property (@(posedge clk) sync_reject_on(x) d[->2])
        pass_q[6].push_back($time); else fail_q[6].push_back($time);

  typedef struct { bit ok; int at; bit fall; } v_t;  // fall: at the y pulse
  function automatic v_t seq_ab(int t);       // a ##1 b
    v_t r; r.ok = va[t] && vb[t+1]; r.at = va[t] ? t+1 : t; return r;
  endfunction
  function automatic v_t seq_abc(int t);      // a ##1 b ##1 c
    v_t r;
    r.ok = va[t] && vb[t+1] && vc[t+2];
    r.at = !va[t] ? t : !vb[t+1] ? t+1 : t+2;
    return r;
  endfunction
  function automatic v_t imp_abc(int t);      // a |=> b ##1 c
    v_t r;
    r.ok = !va[t] || (vb[t+1] && vc[t+2]);
    r.at = !va[t] ? t : !vb[t+1] ? t+1 : t+2;
    return r;
  endfunction
  function automatic v_t imp_cd(int t);       // c |-> ##1 d
    v_t r; r.ok = !vc[t] || vd[t+1]; r.at = vc[t] ? t+1 : t; return r;
  endfunction
  // Synchronous abort on samples s[] at ticks t..r.at.
  function automatic v_t sync_abort(v_t r, int t, bit acc, ref bit s[N+4]);
    for (int k = t; k <= r.at; k++)
      if (s[k]) begin r.ok = acc; r.at = k; return r; end
    return r;
  endfunction
  // Asynchronous abort on y pulses: a pulse before tick k, t < k <= r.at,
  // decides when it falls, just before tick k. (y is low at every tick, and
  // glitches never count.)
  function automatic v_t async_abort(v_t r, int t, bit acc);
    for (int k = t + 1; k <= r.at; k++)
      if (pulse[k]) begin r.ok = acc; r.at = k; r.fall = 1; return r; end
    return r;
  endfunction
  function automatic v_t goto_d2(int t);     // d[->2]: pending until it
    v_t r; int n = 0;                         // matches (weak: never fails)
    r.ok = 1; r.at = 1 << 30;
    for (int k = t; k < N + 4; k++)
      if (vd[k] && ++n == 2) begin r.at = k; break; end
    return r;
  endfunction
  function automatic v_t p_and(v_t p, v_t q);
    v_t r;
    if (!p.ok && !q.ok) begin r.ok = 0; r.at = p.at < q.at ? p.at : q.at; end
    else if (!p.ok) r = p;
    else if (!q.ok) r = q;
    else begin r.ok = 1; r.at = p.at > q.at ? p.at : q.at; end
    return r;
  endfunction

  function automatic void check(int id);
    int ep[$], ef[$];
    for (int t = 0; t <= last; t++) begin
      v_t r;
      case (id)
        0: r = sync_abort(seq_ab(t), t, 1, vx);
        1: r = sync_abort(imp_abc(t), t, 0, vx);
        2: r = async_abort(seq_abc(t), t, 1);
        3: r = async_abort(imp_abc(t), t, 0);
        // inner reject first, then the outer accept: the outer wins a tie
        4: begin
             v_t inner = sync_abort(seq_abc(t), t, 0, vz);
             r = sync_abort(inner, t, 1, vx);
           end
        5: r = p_and(sync_abort(seq_ab(t), t, 1, vx), imp_cd(t));
        6: begin
             r = goto_d2(t);
             if (r.at > last) begin r.at = last; r = sync_abort(r, t, 0, vx);
               if (r.ok) continue; end
             else r = sync_abort(r, t, 0, vx);
           end
      endcase
      if (r.at > last) continue;
      if (r.ok) ep.push_back(10*r.at + (r.fall ? 3 : 5));
      else ef.push_back(10*r.at + (r.fall ? 3 : 5));
    end
    pass_q[id].sort(); fail_q[id].sort(); ep.sort(); ef.sort();
    if (pass_q[id] != ep || fail_q[id] != ef) begin
      $display("FAIL s%0d: pass %p expected %p", id, pass_q[id], ep);
      $display("FAIL s%0d: fail %p expected %p", id, fail_q[id], ef);
      errors++;
    end
  endfunction

  initial begin
    void'($urandom(723));
    for (int t = 0; t < N + 4; t++) begin
      va[t] = $urandom_range(0, 3) != 0; vb[t] = $urandom_range(0, 3) != 0;
      vc[t] = $urandom_range(0, 3) != 0; vd[t] = $urandom_range(0, 1);
      vx[t] = $urandom_range(0, 5) == 0; vz[t] = $urandom_range(0, 5) == 0;
      pulse[t] = t > 0 && $urandom_range(0, 5) == 0;
      glitch[t] = t > 0 && !pulse[t] && $urandom_range(0, 3) == 0;
    end
    {a, b, c, d, x, z} = {va[0], vb[0], vc[0], vd[0], vx[0], vz[0]};
    for (int t = 1; t < N + 4; t++) begin
      @(negedge clk) {a, b, c, d, x, z} = {va[t], vb[t], vc[t], vd[t], vx[t], vz[t]};
      // between tick t-1 (10t-5) and tick t (10t+5)
      #2;
      if (pulse[t]) begin y = 1; #1 y = 0; end
      else if (glitch[t]) begin y = 1; y = 0; end
    end
    @(posedge clk);
    #1 last = N + 3;
    for (int i = 0; i < 7; i++) check(i);
    if (errors == 0) $display("PASSED");
    $finish;
  end
endmodule
