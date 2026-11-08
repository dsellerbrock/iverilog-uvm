// IEEE 1800-2023 16.12.1: an instance of a named property is a
// property_expr, so it can be an implication consequent. Pass and fail
// times are checked against a per-attempt reference model over random
// stimulus, for a sequence-shaped property, a property with its own
// implication and variable delay, a parameterized property, and the same
// shapes asserted inside a procedural block (clock inferred, 16.14.6).
module sva_named_property_consequent;
  localparam int N = 70;
  bit clk = 0;
  bit a, b, c, d;
  bit va[N+8], vb[N+8], vc[N+8], vd[N+8];
  int pass_q[4][$], fail_q[4][$];
  int errors = 0, last;

  always #5 clk = ~clk;

  property p_seq; b ##1 c; endproperty
  property p_imp; b |-> ##[1:2] d; endproperty
  property p_par(x, y); x |=> y; endproperty

  n0: assert property (@(posedge clk) a |-> p_seq)
        pass_q[0].push_back($time); else fail_q[0].push_back($time);
  n1: assert property (@(posedge clk) a |=> p_imp)
        pass_q[1].push_back($time); else fail_q[1].push_back($time);
  n2: assert property (@(posedge clk) a |-> p_par(c, d))
        pass_q[2].push_back($time); else fail_q[2].push_back($time);
  always @(posedge clk)
    n3: assert property ($fell(a) |=> p_imp)
          pass_q[3].push_back($time); else fail_q[3].push_back($time);

  typedef struct { bit ok; int at; } v_t;
  function automatic v_t mk(bit ok, int at);
    v_t r; r.ok = ok; r.at = at; return r;
  endfunction
  function automatic v_t imp_bd(int s);     // b |-> ##[1:2] d, from s
    if (!vb[s]) return mk(1, s);
    if (vd[s+1]) return mk(1, s+1);
    return mk(vd[s+2], s+2);
  endfunction
  function automatic v_t model(int id, int t);
    case (id)
      0: if (!va[t]) return mk(1, t);
         else return mk(vb[t] && vc[t+1], vb[t] ? t+1 : t);
      1: if (!va[t]) return mk(1, t);
         else return imp_bd(t+1);
      2: if (!va[t]) return mk(1, t);
         else return mk(!vc[t] || vd[t+1], vc[t] ? t+1 : t);
      3: if (!(t > 0 ? va[t-1] && !va[t] : 0)) return mk(1, t);  // $fell(a)
         else return imp_bd(t+1);
    endcase
  endfunction

  initial begin
    void'($urandom(918));
    for (int t = 0; t < N + 8; t++) begin
      va[t] = $urandom_range(0, 1); vb[t] = $urandom_range(0, 3) != 0;
      vc[t] = $urandom_range(0, 3) != 0; vd[t] = $urandom_range(0, 2) != 0;
    end
    {a, b, c, d} = {va[0], vb[0], vc[0], vd[0]};
    for (int t = 1; t < N + 4; t++)
      @(negedge clk) {a, b, c, d} = {va[t], vb[t], vc[t], vd[t]};
    @(posedge clk);
    #1 last = N + 3;
    for (int id = 0; id < 4; id++) begin
      int ep[$], ef[$];
      ep.delete(); ef.delete();
      for (int t = 0; t <= last; t++) begin
        v_t r;
        r = model(id, t);
        if (r.at > last) continue;
        if (r.ok) ep.push_back(10*r.at + 5); else ef.push_back(10*r.at + 5);
      end
      pass_q[id].sort(); fail_q[id].sort(); ep.sort(); ef.sort();
      if (pass_q[id] != ep || fail_q[id] != ef) begin
        $display("FAIL n%0d: pass %p expected %p", id, pass_q[id], ep);
        $display("FAIL n%0d: fail %p expected %p", id, fail_q[id], ef);
        errors++;
      end
    end
    if (errors == 0) $display("PASSED");
    $finish;
  end
endmodule
