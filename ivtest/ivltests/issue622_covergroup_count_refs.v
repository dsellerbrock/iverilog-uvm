// IEEE 1800-2017/2023 19.8, 19.11: get_coverage(ref int, ref int) and
// get_inst_coverage(ref int, ref int) on a covergroup, a coverpoint and a
// cross assign the covered and the total bin counts.
module top;
  int a, b, c, d, covered, total; real r; int errors = 0;
  // IEEE 1800-2017/2023 19.8 example
  covergroup cg (int xb, yb, ref int x, y);
    cx: coverpoint x { bins xbins[] = { [0:xb] }; }
    cy: coverpoint y { bins ybins[] = { [0:yb] }; }
  endgroup
  covergroup mg (int lo, hi) with function sample(int v);
    type_option.merge_instances = 1;
    p: coverpoint v { bins bb[] = { [lo:hi] }; }
  endgroup
  covergroup xg with function sample(bit p, bit q);
    option.per_instance = 1;
    ca: coverpoint p { bins zero = {0}; bins one = {1}; }
    cb: coverpoint q { bins zero = {0}; bins one = {1}; }
    x: cross ca, cb;
  endgroup
  covergroup eg with function sample(bit p);
    e: coverpoint p { ignore_bins all = {0, 1}; }
  endgroup
  covergroup rg (int hi) with function sample(int v);
    p: coverpoint v { bins bb[] = { [0:hi] }; }
  endgroup
  class holder;
    bit f;
    covergroup ecg;
      pf: coverpoint f;
    endgroup
    function new(); ecg = new; endfunction
    // the embedded group named from inside its class
    function real item_counts(ref int n, ref int t);
      return ecg.pf.get_inst_coverage(n, t);
    endfunction
    function void group_counts(ref int n, ref int t);
      this.ecg.get_coverage(n, t);
    endfunction
  endclass
  cg cv1 = new(1, 2, a, b); cg cv2 = new(3, 6, c, d);
  mg m1 = new(0, 1); mg m2 = new(1, 2);
  xg x1 = new; eg e1 = new;
  rg keep = new(1); rg gone = new(3); holder h = new;
  task automatic check(string what, real got, real want, int wc, int wt);
    if (got < want - 0.01 || got > want + 0.01 || covered != wc || total != wt) begin
      errors += 1;
      $display("FAILED %s: %0.2f %0d/%0d, expected %0.2f %0d/%0d", what, got, covered, total, want, wc, wt);
    end
    covered = -1; total = -1;
  endtask
  initial begin
    covered = -1; total = -1;
    a = 0; b = 1; cv1.sample(); c = 3; d = 6; cv2.sample(); a = 1; cv1.sample();
    // instance counts: the numerator and denominator of the score
    check("cv1.cx inst", cv1.cx.get_inst_coverage(covered, total), 100.0, 2, 2);
    check("cv1.cy inst", cv1.cy.get_inst_coverage(covered, total), 33.33, 1, 3);
    check("cv1 inst", cv1.get_inst_coverage(covered, total), 66.67, 3, 5);
    check("cv2 inst", cv2.get_inst_coverage(covered, total), 19.64, 2, 11);
    // type counts through an instance: summed over all instances
    check("cv1.cx type", cv1.cx.get_coverage(covered, total), 62.5, 3, 6);
    check("cv2.cy type", cv2.cy.get_coverage(covered, total), 23.81, 2, 10);
    check("cv1 type", cv1.get_coverage(covered, total), 43.15, 5, 16);
    // statement calls keep their outputs
    cv1.cx.get_inst_coverage(covered, total); check("stmt item inst", 0, 0, 2, 2);
    cv2.cx.get_coverage(covered, total); check("stmt item type", 0, 0, 3, 6);
    cv1.get_inst_coverage(covered, total); check("stmt group inst", 0, 0, 3, 5);
    void'(cv2.get_coverage(covered, total)); check("void group type", 0, 0, 5, 16);
    void'(cv2.cy.get_inst_coverage(covered, total)); check("void item inst", 0, 0, 1, 7);
    // merged instances: the union b[0], b[1], b[2] (19.11.3)
    m1.sample(0); m1.sample(1); m2.sample(1);
    check("m1 type merged", m1.get_coverage(covered, total), 66.67, 2, 3);
    check("m2.p type merged", m2.p.get_coverage(covered, total), 66.67, 2, 3);
    // crosses
    x1.sample(0, 0); x1.sample(1, 0);
    check("x1.x inst", x1.x.get_inst_coverage(covered, total), 50.0, 2, 4);
    check("x1.x type", x1.x.get_coverage(covered, total), 50.0, 2, 4);
    check("x1 inst", x1.get_inst_coverage(covered, total), 66.67, 5, 8);
    // zero denominator assigns zero to both (19.11 d)
    e1.sample(0);
    covered = 7; total = 7; r = e1.e.get_inst_coverage(covered, total); check("empty item inst", 0, 0, 0, 0);
    covered = 7; total = 7; r = e1.e.get_coverage(covered, total); check("empty item type", 0, 0, 0, 0);
    covered = 7; total = 7; r = e1.get_inst_coverage(covered, total); check("empty group inst", 0, 0, 0, 0);
    covered = 7; total = 7; r = e1.get_coverage(covered, total); check("empty group type", 0, 0, 0, 0);
    // an instance that no longer exists still counts in its type
    gone.sample(0); gone.sample(2); keep.sample(1);
    check("rg type", keep.get_coverage(covered, total), 50.0, 3, 6);
    gone = null;
    check("rg type, one retired", keep.get_coverage(covered, total), 50.0, 3, 6);
    check("rg.p type, one retired", keep.p.get_coverage(covered, total), 50.0, 3, 6);
    // a class-embedded group
    h.f = 1; h.ecg.sample();
    check("embedded item", h.item_counts(covered, total), 50.0, 1, 2);
    h.group_counts(covered, total); check("embedded group stmt", 0, 0, 1, 2);
    check("embedded from outside", h.ecg.pf.get_coverage(covered, total), 50.0, 1, 2);
    if (errors == 0) $display("PASSED");
  end
endmodule
