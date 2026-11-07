// IEEE 1800-2023 16.13.5/16.13.6: `seq.matched' on a sequence clocked by a
// different clock. The end point found on the source clock is seen by the
// first destination tick strictly after it (Annex F.6.1), and only by that
// tick. clk_a and clk_b coincide at t = 35, 105, ...: a match there is
// seen by the next clk_b tick, not the coincident one.
module sva_matched_cross_clock;
  localparam int N = 80;
  bit clk_a = 0, clk_b = 0;
  bit a, b, c;
  bit va[N+2], vb[N+2], vc[N+2];
  int pass_q[3][$], fail_q[3][$];
  int errors = 0;

  always #5 clk_a = ~clk_a;   // posedge at 10k+5
  always #7 clk_b = ~clk_b;   // posedge at 14j+7

  sequence src;
    @(posedge clk_a) a ##1 b;
  endsequence

  m0: assert property (@(posedge clk_b) src.matched)
        pass_q[0].push_back($time); else fail_q[0].push_back($time);
  m1: assert property (@(posedge clk_b) c |-> src.matched)
        pass_q[1].push_back($time); else fail_q[1].push_back($time);
  m2: assert property (@(posedge clk_b) c ##1 src.matched)
        pass_q[2].push_back($time); else fail_q[2].push_back($time);

  int last;
  // Value of c sampled at the clk_b tick at time t (c follows clk_a's grid).
  function automatic bit c_at(int t);
    return vc[(t - 1) / 10];
  endfunction

  initial begin
    int match_t[$], ep[3][$], ef[3][$], prev;
    bit seen_q[$];
    void'($urandom(896));
    for (int k = 0; k < N + 2; k++) begin
      va[k] = $urandom_range(0, 1); vb[k] = $urandom_range(0, 1);
      vc[k] = $urandom_range(0, 1);
    end
    {a, b, c} = {va[0], vb[0], vc[0]};
    for (int k = 1; k < N; k++) begin
      @(negedge clk_a) {a, b, c} = {va[k], vb[k], vc[k]};
    end
    last = $time;
    // Source end points: a at tick k-1 and b at tick k.
    for (int k = 1; k < N; k++)
      if (va[k-1] && vb[k] && 10*k + 5 < last) match_t.push_back(10*k + 5);
    prev = -1;
    for (int t = 7; t < last; t += 14) begin
      bit seen;
      seen = 0;
      foreach (match_t[i]) if (match_t[i] >= prev && match_t[i] < t) seen = 1;
      if (seen) ep[0].push_back(t); else ef[0].push_back(t);
      if (!c_at(t) || seen) ep[1].push_back(t); else ef[1].push_back(t);
      seen_q.push_back(seen);
      prev = t;
    end
    // c ##1 src.matched: c at tick j, then the end point seen at tick j+1.
    for (int j = 0; 7 + 14*j < last; j++) begin
      int t;
      t = 7 + 14*j;
      if (!c_at(t)) ef[2].push_back(t);
      else if (j + 1 < seen_q.size())
        if (seen_q[j+1]) ep[2].push_back(t + 14); else ef[2].push_back(t + 14);
    end
    ep[2].sort(); ef[2].sort();
    for (int i = 0; i < 3; i++) begin
      while (pass_q[i].size() && pass_q[i][$] > last) void'(pass_q[i].pop_back());
      while (fail_q[i].size() && fail_q[i][$] > last) void'(fail_q[i].pop_back());
      if (pass_q[i] != ep[i] || fail_q[i] != ef[i]) begin
        $display("FAIL m%0d: pass %p expected %p", i, pass_q[i], ep[i]);
        $display("FAIL m%0d: fail %p expected %p", i, fail_q[i], ef[i]);
        errors++;
      end
    end
    if (errors == 0) $display("PASSED");
    $finish;
  end
endmodule
