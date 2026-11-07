// IEEE 1800-2023 16.12.4 (or) and 16.12.5 (and) with full property operands.
// Each assertion's pass/fail times are checked against an independent
// per-attempt reference model over random stimulus. The operands resolve at
// different ticks, so a wrong pairing of operand attempts, a missed early
// decision, or a double report changes the logged times.
module sva_property_and_or;
  localparam int N = 60;
  bit clk = 0, rst = 0;
  bit a, b, c, d, e, f;
  bit va[N+4], vb[N+4], vc[N+4], vd[N+4], ve[N+4], vf[N+4];
  int pass_q[7][$], fail_q[7][$];
  int errors = 0;

  always #5 clk = ~clk;

  property q_ab; a |=> b; endproperty
  property q_cd; c |-> ##2 d; endproperty

  a0: assert property (@(posedge clk) (a |=> b) and (c |-> ##2 d))
        pass_q[0].push_back($time); else fail_q[0].push_back($time);
  a1: assert property (@(posedge clk) (a |=> b) or (c |-> ##2 d))
        pass_q[1].push_back($time); else fail_q[1].push_back($time);
  a2: assert property (@(posedge clk) q_ab and q_cd)
        pass_q[2].push_back($time); else fail_q[2].push_back($time);
  a3: assert property (@(posedge clk) (e ##1 f) or (c |-> ##2 d))
        pass_q[3].push_back($time); else fail_q[3].push_back($time);
  a4: assert property (@(posedge clk) (not (e ##1 f)) and (a |=> b))
        pass_q[4].push_back($time); else fail_q[4].push_back($time);
  a5: assert property (@(posedge clk) ((a |=> b) and (c |-> ##2 d)) or (e |-> f))
        pass_q[5].push_back($time); else fail_q[5].push_back($time);
  a6: assert property (@(posedge clk) disable iff (rst) (a |=> b) and (c |-> ##2 d))
        pass_q[6].push_back($time); else fail_q[6].push_back($time);

  // Operand verdict of one attempt: truth and the tick it is known.
  typedef struct { bit ok; int at; } v_t;
  function automatic v_t imp1(int t);   // a |=> b
    v_t r; r.ok = !va[t] || vb[t+1]; r.at = va[t] ? t+1 : t; return r;
  endfunction
  function automatic v_t imp2(int t);   // c |-> ##2 d
    v_t r; r.ok = !vc[t] || vd[t+2]; r.at = vc[t] ? t+2 : t; return r;
  endfunction
  function automatic v_t seq_ef(int t); // e ##1 f
    v_t r; r.ok = ve[t] && vf[t+1]; r.at = ve[t] ? t+1 : t; return r;
  endfunction
  function automatic v_t imp_ef(int t); // e |-> f
    v_t r; r.ok = !ve[t] || vf[t]; r.at = t; return r;
  endfunction
  function automatic v_t p_and(v_t x, v_t y);
    v_t r;
    if (!x.ok && !y.ok) begin r.ok = 0; r.at = x.at < y.at ? x.at : y.at; end
    else if (!x.ok) begin r.ok = 0; r.at = x.at; end
    else if (!y.ok) begin r.ok = 0; r.at = y.at; end
    else begin r.ok = 1; r.at = x.at > y.at ? x.at : y.at; end
    return r;
  endfunction
  function automatic v_t p_or(v_t x, v_t y);
    v_t r;
    if (x.ok && y.ok) begin r.ok = 1; r.at = x.at < y.at ? x.at : y.at; end
    else if (x.ok) begin r.ok = 1; r.at = x.at; end
    else if (y.ok) begin r.ok = 1; r.at = y.at; end
    else begin r.ok = 0; r.at = x.at > y.at ? x.at : y.at; end
    return r;
  endfunction
  function automatic v_t p_not(v_t x);
    v_t r = x; r.ok = !x.ok; return r;
  endfunction

  localparam int RST = 25;  // rst is high at the tick of cycle RST
  int last;                 // last tick simulated

  function automatic void check(int id, string name);
    int ep[$], ef[$];
    for (int t = 0; t <= last; t++) begin
      v_t r;
      case (id)
        0, 2, 6: r = p_and(imp1(t), imp2(t));
        1: r = p_or(imp1(t), imp2(t));
        3: r = p_or(seq_ef(t), imp2(t));
        4: r = p_and(p_not(seq_ef(t)), imp1(t));
        5: r = p_or(p_and(imp1(t), imp2(t)), imp_ef(t));
      endcase
      if (r.at > last) continue;
      // disable iff: no attempt starts at RST, and every attempt still
      // undecided when rst rises (just before tick RST) is cancelled.
      if (id == 6 && (t == RST || (t < RST && r.at >= RST))) continue;
      if (r.ok) ep.push_back(10*r.at + 5); else ef.push_back(10*r.at + 5);
    end
    pass_q[id].sort(); fail_q[id].sort(); ep.sort(); ef.sort();
    if (pass_q[id] != ep || fail_q[id] != ef) begin
      $display("FAIL %s: pass %p expected %p", name, pass_q[id], ep);
      $display("FAIL %s: fail %p expected %p", name, fail_q[id], ef);
      errors++;
    end
  endfunction

  initial begin
    void'($urandom(1800));
    for (int t = 0; t < N + 4; t++) begin
      va[t] = $urandom_range(0, 1); vb[t] = $urandom_range(0, 3) != 0;
      vc[t] = $urandom_range(0, 1); vd[t] = $urandom_range(0, 3) != 0;
      ve[t] = $urandom_range(0, 1); vf[t] = $urandom_range(0, 1);
    end
    {a, b, c, d, e, f} = {va[0], vb[0], vc[0], vd[0], ve[0], vf[0]};
    for (int t = 1; t < N + 4; t++) begin
      @(negedge clk);
      {a, b, c, d, e, f} = {va[t], vb[t], vc[t], vd[t], ve[t], vf[t]};
      rst = (t == RST);
    end
    @(posedge clk);
    #1 last = N + 3;
    check(0, "and");
    check(1, "or");
    check(2, "named and");
    check(3, "sequence or implication");
    check(4, "not and");
    check(5, "nested");
    check(6, "disable iff");
    if (errors == 0) $display("PASSED");
    $finish;
  end
endmodule
