module until_implication_continuation;
  bit clk = 0;
  bit p = 1, q = 0, dis = 0;
  bit ti = 0, tl = 0, tr = 0, tk = 0, tb = 0, td = 0, te = 0;
  bit e1 = 0, a = 0, b = 0;
  int fi_u = 0, fi_su = 0, fi_uw = 0, fi_suw = 0;
  int fl_u = 0, fl_su = 0, fl_uw = 0, fl_suw = 0;
  int fr_u = 0, fr_su = 0, fr_uw = 0, fr_suw = 0;
  int fk_u = 0, fk_su = 0, fk_uw = 0, fk_suw = 0;
  int fb_u = 0, fb_su = 0, fb_uw = 0, fb_suw = 0;
  int fd_u = 0, fd_su = 0, fd_uw = 0, fd_suw = 0;
  int fe_u = 0, fe_su = 0, fe_uw = 0, fe_suw = 0;
  int f_empty1 = 0;

  always #5 clk = ~clk;

  // Each group uses the same profile but a distinct antecedent pulse.
  assert property (@(posedge clk) ti |=> p until q) else fi_u++;
  assert property (@(posedge clk) ti |=> p s_until q) else fi_su++;
  assert property (@(posedge clk) ti |=> p until_with q) else fi_uw++;
  assert property (@(posedge clk) ti |=> p s_until_with q) else fi_suw++;
  assert property (@(posedge clk) tl |=> p until q) else fl_u++;
  assert property (@(posedge clk) tl |=> p s_until q) else fl_su++;
  assert property (@(posedge clk) tl |=> p until_with q) else fl_uw++;
  assert property (@(posedge clk) tl |=> p s_until_with q) else fl_suw++;
  assert property (@(posedge clk) tr |=> p until q) else fr_u++;
  assert property (@(posedge clk) tr |=> p s_until q) else fr_su++;
  assert property (@(posedge clk) tr |=> p until_with q) else fr_uw++;
  assert property (@(posedge clk) tr |=> p s_until_with q) else fr_suw++;
  assert property (@(posedge clk) tk |=> p until q) else fk_u++;
  assert property (@(posedge clk) tk |=> p s_until q) else fk_su++;
  assert property (@(posedge clk) tk |=> p until_with q) else fk_uw++;
  assert property (@(posedge clk) tk |=> p s_until_with q) else fk_suw++;
  assert property (@(posedge clk) tb |=> p until q) else fb_u++;
  assert property (@(posedge clk) tb |=> p s_until q) else fb_su++;
  assert property (@(posedge clk) tb |=> p until_with q) else fb_uw++;
  assert property (@(posedge clk) tb |=> p s_until_with q) else fb_suw++;
  assert property (@(posedge clk) disable iff (dis) td |=> p until q) else fd_u++;
  assert property (@(posedge clk) disable iff (dis) td |=> p s_until q) else fd_su++;
  assert property (@(posedge clk) disable iff (dis) td |=> p until_with q) else fd_uw++;
  assert property (@(posedge clk) disable iff (dis) td |=> p s_until_with q) else fd_suw++;
  assert property (@(posedge clk) te |=> p until q) else fe_u++;
  assert property (@(posedge clk) te |=> p s_until q) else fe_su++;
  assert property (@(posedge clk) te |=> p until_with q) else fe_uw++;
  assert property (@(posedge clk) te |=> p s_until_with q) else fe_suw++;

  // Valid 16.9.2.1 empty-branch control: the [*0:$] empty branch of ##1 b is same-tick b.
  // The `a[*0] ##0 b` variant is a degenerate property and is checked
  // separately as a required compile-time rejection (16.12.22).
  assert property (@(posedge clk) e1 |-> a[*0:$] ##1 b) else f_empty1++;

  `define PULSE(sig) @(negedge clk) sig = 1; @(negedge clk) sig = 0;

  initial begin
    // Immediate bad: every variant fails (q is low, p is low at first consequent).
    p = 0; q = 0; `PULSE(ti) repeat (2) @(negedge clk);
    p = 1;

    // Late bad: all four variants must fail after one good consequent tick.
    `PULSE(tl) @(negedge clk); p = 0; repeat (2) @(negedge clk); p = 1;

    // q discharge: each variant succeeds after a valid prefix.
    `PULSE(tr) @(negedge clk); q = 1; repeat (2) @(negedge clk); q = 0;

    // q arrives after one good consequent tick with p low: until releases;
    // until_with retains its p requirement on the q tick.
    `PULSE(tk) @(negedge clk); p = 0; q = 1; repeat (2) @(negedge clk); p = 1; q = 0;

    // q tick with p low immediately: until succeeds, until_with fails.
    p = 0; q = 1; `PULSE(tb) repeat (2) @(negedge clk); p = 1; q = 0;

    // disable iff aborts an armed continuation before the late bad tick.
    `PULSE(td) @(negedge clk); dis = 1; p = 0;
    repeat (2) @(negedge clk); dis = 0; p = 1;

    // Valid empty ##1 branch is equivalent to same-tick b and succeeds.
    @(negedge clk) begin e1 = 1; b = 1; end
    @(negedge clk) begin e1 = 0; b = 0; end
    repeat (2) @(negedge clk);

    // Strong forms have one unresolved obligation at end of simulation.
    `PULSE(te)
    repeat (2) @(negedge clk);
    $finish(0);
  end

  final begin
    if (fi_u != 1 || fi_su != 1 || fi_uw != 1 || fi_suw != 1 ||
        fl_u != 1 || fl_su != 1 || fl_uw != 1 || fl_suw != 1 ||
        fr_u != 0 || fr_su != 0 || fr_uw != 0 || fr_suw != 0 ||
        fk_u != 0 || fk_su != 0 || fk_uw != 1 || fk_suw != 1 ||
        fb_u != 0 || fb_su != 0 || fb_uw != 1 || fb_suw != 1 ||
        fd_u != 0 || fd_su != 0 || fd_uw != 0 || fd_suw != 0 ||
        f_empty1 != 0 || fe_u != 0 || fe_su != 1 || fe_uw != 0 || fe_suw != 1)
      $fatal(1, "until regression i=%0d/%0d/%0d/%0d l=%0d/%0d/%0d/%0d r=%0d/%0d/%0d/%0d k=%0d/%0d/%0d/%0d b=%0d/%0d/%0d/%0d d=%0d/%0d/%0d/%0d e1=%0d eos=%0d/%0d/%0d/%0d",
             fi_u,fi_su,fi_uw,fi_suw, fl_u,fl_su,fl_uw,fl_suw,
             fr_u,fr_su,fr_uw,fr_suw, fk_u,fk_su,fk_uw,fk_suw, fb_u,fb_su,fb_uw,fb_suw,
             fd_u,fd_su,fd_uw,fd_suw, f_empty1,fe_u,fe_su,fe_uw,fe_suw);
    $display("PASS: implication until continuation");
  end
endmodule
