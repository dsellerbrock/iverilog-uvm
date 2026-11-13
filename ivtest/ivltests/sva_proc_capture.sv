// IEEE 1800-2023 16.14.6.1: a procedural concurrent assertion saves the
// values of its const expressions and automatic variables when its pending
// instance is queued; static variables are sampled in the Preponed region.
// Every queued instance is its own attempt, and its action blocks see the
// same saved values.
//
// Edges are at 5, 15, 25 and 35. The loops queue instances at the first two edges
// (cyc 0 and 1). foo = 01011 and bar = 00111, so for k = 0..3:
//   foo[k] = 1 1 0 1, bar[k] = 1 1 1 0, foo[k] && bar[k] = 1 1 0 0.
// The static si is 0 when sampled at the first edge (default) and 4 at the
// second (its final value from the previous run); foo[4] = bar[4] = 0.
// Results are counted per k and printed at the end, so the order of the
// actions of attempts that resolve in the same tick does not matter.
module sva_proc_capture;
  logic clk = 0;
  always #5 clk = ~clk;
  int cyc = 0;
  always @(posedge clk) cyc <= cyc + 1;

  logic [4:0] foo = 5'b01011, bar = 5'b00111;
  int p1[4], f1[4], p2[4], f2[4], p3[4], f3[4];
  int p4[4], f4[4], p5[4], f5[4], p6[4], f6[4], p10[4], f10[4];
  property pp(x); x; endproperty
  int f8[4];

  // a1-a3, a8: static si (16.14.6.1, first example). The example declares
  // si in the always procedure; it is a module variable here, which is the
  // same static lifetime.
  int si;
  always @(posedge clk) begin
    if (cyc < 2)
      for (si = 0; si < 4; si++) begin
        // a1: sampled si: 0 at the first edge, 4 at the second. Its actions
        // count by cyc, which the NBA region has already advanced: 1 at the
        // first edge, 2 at the second. A static si in an action block is not
        // saved (it reads 4), so a2, a3 and a8 index their counts by const'(si).
        a1: assert property (foo[si] && bar[si]) p1[cyc]++; else f1[cyc]++;
        // a2: foo[k] && bar[sampled si].
        a2: assert property (foo[const'(si)] && bar[si])
              p2[const'(si)]++; else f2[const'(si)]++;
        // a3: foo[k] && bar[k].
        a3: assert property (foo[const'(si)] && bar[const'(si)])
              p3[const'(si)]++; else f3[const'(si)]++;
        // a8: the action sees const'(si) = k. ($sampled in an action
        // block is #709.)
        a8: assert property (foo[const'(si)] && bar[si])
              else f8[const'(si)]++;
      end
  end

  // a4-a6: an automatic loop variable is saved whether or not it is cast.
  always @(posedge clk) begin
    if (cyc < 2)
      for (int i = 0; i < 4; i++) begin
        a4: assert property (foo[i] && bar[i]) p4[i]++; else f4[i]++;
        a5: assert property (foo[const'(i)] && bar[i]) p5[i]++; else f5[i]++;
        a6: assert property (foo[const'(i)] && bar[const'(i)])
              p6[i]++; else f6[i]++;
        // a10: a named property's actual argument (16.14.6.1 is titled
        // "Arguments to procedural concurrent assertions").
        a10: assert property (pp(foo[i])) p10[i]++; else f10[i]++;
      end
  end

  // a7: the saved value stays in effect for later clocks of the attempt.
  // Queued once at the first edge; bar7 is 01 at the second edge.
  logic [1:0] foo7 = 2'b11, bar7 = 2'b00;
  logic w7 = 1;
  int p7[2], f7[2];
  initial #10 bar7 = 2'b01;
  always @(posedge clk) begin
    if (cyc == 0)
      for (int i = 0; i < 2; i++)
        a7: assert property (foo7[i] |=> bar7[i] ##1 w7) p7[i]++; else f7[i]++;
  end

  // a9: a saved automatic value wider than 32 bits is not truncated.
  logic [39:0] wide = 40'hAB_0000_0001;
  int p9 = 0, f9 = 0;
  always @(posedge clk) begin
    automatic logic [39:0] big = 40'hAB_0000_0001;
    if (cyc < 2)
      a9: assert property (wide == big) p9++; else f9++;
  end

  // Issue #1192's repro: one fail with i=0 and one pass with i=1.
  logic [1:0] fr = 2'b10;
  int pr[2], fr_[2];
  always @(posedge clk) begin
    if (cyc == 0)
      for (int i = 0; i < 2; i++)
        ar: assert property (fr[i]) pr[i]++; else fr_[i]++;
  end

  // a11: user ruling 2026-11-11 (Q6): when attempts of one procedural
  // assertion resolve in the same tick, their action blocks run in the order
  // their instances were queued, whatever slots they hold. At the first edge
  // (cyc 0) A (k=1) takes slot 0 and B (k=3) slot 1; A passes at the second
  // edge and frees slot 0, which C (k=3), queued at the third edge (cyc 2),
  // takes. B and C both pass at the fourth edge: queue order is B, C (saved
  // e = 0, 2), slot order would be C, B.
  int ord11[3], n11 = 0;
  always @(posedge clk) begin
    automatic int k, e;
    e = cyc;
    for (int n = 0; n < 2; n++) begin
      k = (cyc == 0) ? (n == 0 ? 1 : 3) : (cyc == 2 && n == 0) ? 3 : 0;
      if (k != 0)
        a11: assert property (##[1:4] (cyc == k)) begin
          ord11[n11] = e;
          n11++;
        end
    end
  end

  // a12: a match-item call's argument (16.11) reads the value its instance
  // saved: "An automatic variable may be passed as a constant input for a
  // subroutine call from an assertion statement in procedural code." Two
  // instances queued at the first edge log i = 0 and 1 at the second.
  string log12 = "";
  task automatic t12(input int c); log12 = {log12, $sformatf(" %0t:%0d", $time, c)}; endtask
  always @(posedge clk) begin
    if (cyc == 0)
      for (int i = 0; i < 2; i++)
        a12: assert property (1'b1 ##1 (1'b1, t12(i))) else ;
  end

  initial begin
    #40;
    // a1 counts by edge: 4 passes at the first, 4 failures at the second.
    $display("a1 pass/edge %0d %0d fail/edge %0d %0d", p1[1], p1[2], f1[1], f1[2]);
    $display("a2 pass %0d %0d %0d %0d fail %0d %0d %0d %0d",
             p2[0], p2[1], p2[2], p2[3], f2[0], f2[1], f2[2], f2[3]);
    $display("a3 pass %0d %0d %0d %0d fail %0d %0d %0d %0d",
             p3[0], p3[1], p3[2], p3[3], f3[0], f3[1], f3[2], f3[3]);
    $display("a4 pass %0d %0d %0d %0d fail %0d %0d %0d %0d",
             p4[0], p4[1], p4[2], p4[3], f4[0], f4[1], f4[2], f4[3]);
    $display("a5 pass %0d %0d %0d %0d fail %0d %0d %0d %0d",
             p5[0], p5[1], p5[2], p5[3], f5[0], f5[1], f5[2], f5[3]);
    $display("a6 pass %0d %0d %0d %0d fail %0d %0d %0d %0d",
             p6[0], p6[1], p6[2], p6[3], f6[0], f6[1], f6[2], f6[3]);
    $display("a10 pass %0d %0d %0d %0d fail %0d %0d %0d %0d",
             p10[0], p10[1], p10[2], p10[3], f10[0], f10[1], f10[2], f10[3]);
    $display("a7 pass %0d %0d fail %0d %0d", p7[0], p7[1], f7[0], f7[1]);
    $display("a8 fail %0d %0d %0d %0d", f8[0], f8[1], f8[2], f8[3]);
    $display("a9 pass %0d fail %0d", p9, f9);
    $display("issue1192 pass %0d %0d fail %0d %0d", pr[0], pr[1], fr_[0], fr_[1]);
    $display("a11 order %0d %0d %0d (%0d)", ord11[0], ord11[1], ord11[2], n11);
    $display("a12%s", log12);
    $finish;
  end
endmodule
