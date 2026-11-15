// IEEE 1800-2017/2023 19.8: get_coverage() is a static method, available on
// a covergroup, coverpoint or cross type through ::, with or without the
// (ref int, ref int) outputs, as an expression or as a statement.
package pk;
  covergroup pcg with function sample(bit x);
    px: coverpoint x;
  endgroup
endpackage
module top;
  import pk::*;
  int a, b, c, d, covered, total; real r; int errors = 0;
  // the 19.8 example
  covergroup cg (int xb, yb, ref int x, y);
    cx: coverpoint x { bins xbins[] = { [0:xb] }; }
    cy: coverpoint y { bins ybins[] = { [0:yb] }; }
  endgroup
  covergroup xg with function sample(bit p, bit q);
    ca: coverpoint p;
    cb: coverpoint q;
    x: cross ca, cb;
  endgroup
  covergroup mg (int lo, hi) with function sample(int v);
    type_option.merge_instances = 1;
    p: coverpoint v { bins bb[] = { [lo:hi] }; }
  endgroup
  covergroup ng with function sample(bit p);
    e: coverpoint p;
  endgroup
  cg cv1 = new(1, 2, a, b); cg cv2 = new(3, 6, c, d);
  xg x1 = new; mg m1 = new(0, 1); mg m2 = new(1, 2); pcg p1 = new;
  task automatic check(string what, real got, real want, int wc, int wt);
    if (got < want - 0.01 || got > want + 0.01 || covered != wc || total != wt) begin
      errors += 1;
      $display("FAILED %s: %0.2f %0d/%0d, expected %0.2f %0d/%0d", what, got, covered, total, want, wc, wt);
    end
    covered = -1; total = -1;
  endtask
  initial begin
    covered = -1; total = -1;
    // before any sample: every bin defined, none covered
    check("cg::cx empty", cg::cx::get_coverage(covered, total), 0.0, 0, 6);
    check("cg empty", cg::get_coverage(covered, total), 0.0, 0, 16);
    a = 0; b = 1; cv1.sample(); c = 3; d = 6; cv2.sample(); a = 1; cv1.sample();
    check("cg::cx", cg::cx::get_coverage(covered, total), 62.5, 3, 6);
    check("cg::cy", cg::cy::get_coverage(covered, total), 23.81, 2, 10);
    check("cg", cg::get_coverage(covered, total), 43.15, 5, 16);
    // statement forms, with and without void'
    cg::cx::get_coverage(covered, total); check("stmt cg::cx", 0, 0, 3, 6);
    cg::get_coverage(covered, total); check("stmt cg", 0, 0, 5, 16);
    void'(cg::cy::get_coverage(covered, total)); check("void cg::cy", 0, 0, 2, 10);
    void'(cg::get_coverage(covered, total)); check("void cg", 0, 0, 5, 16);
    void'(cg::get_coverage());
    void'(cg::cx::get_coverage());
    // a cross type
    x1.sample(0, 0); x1.sample(1, 0);
    check("xg::x", xg::x::get_coverage(covered, total), 50.0, 2, 4);
    r = xg::x::get_coverage();
    if (r != 50.0) begin errors += 1; $display("FAILED xg::x no-arg %0.2f", r); end
    void'(xg::x::get_coverage());
    void'(xg::x::get_coverage(covered, total)); check("void xg::x", 0, 0, 2, 4);
    check("xg", xg::get_coverage(covered, total), 66.67, 5, 8);
    // merged instances: the union b[0], b[1], b[2] (19.11.3)
    m1.sample(0); m1.sample(1); m2.sample(1);
    check("mg merged", mg::get_coverage(covered, total), 66.67, 2, 3);
    check("mg::p merged", mg::p::get_coverage(covered, total), 66.67, 2, 3);
    // a type with no instance: zero is assigned to both (19.11 d)
    covered = 7; total = 7;
    r = ng::get_coverage(covered, total); check("no instance", r, 0.0, 0, 0);
    covered = 7; total = 7;
    r = ng::e::get_coverage(covered, total); check("no instance item", r, 0.0, 0, 0);
    // a covergroup type from a package
    p1.sample(1);
    check("pk::pcg", pk::pcg::get_coverage(covered, total), 50.0, 1, 2);
    check("pk::pcg::px", pk::pcg::px::get_coverage(covered, total), 50.0, 1, 2);
    pk::pcg::get_coverage(covered, total); check("stmt pk::pcg", 0, 0, 1, 2);
    if (errors == 0) $display("PASSED");
  end
endmodule
