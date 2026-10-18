module top;
  int a, b, c, d, cov, tot;
  covergroup cg (int xb, yb, ref int x, y);
    cx: coverpoint x { bins xbins[] = { [0:xb] }; }
    cy: coverpoint y { bins ybins[] = { [0:yb] }; }
  endgroup
  cg cv1 = new(1, 2, a, b); cg cv2 = new(3, 6, c, d);
  initial begin
    a = 0; b = 0; cv1.sample();
    void'(cv1.cx.get_inst_coverage(cov, tot)); $display("%s 19.8.cp_inst cov=%0d tot=%0d", (cov == 1 && tot == 2) ? "PASS" : "FAIL", cov, tot);
    void'(cv1.get_inst_coverage(cov, tot)); $display("%s 19.8.cg_inst cov=%0d tot=%0d", (cov == 2 && tot == 5) ? "PASS" : "FAIL", cov, tot);
  end
endmodule
