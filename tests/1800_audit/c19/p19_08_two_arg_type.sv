module top;
  int a, b, c, d, cov, tot;
  covergroup cg (int xb, yb, ref int x, y);
    cx: coverpoint x { bins xbins[] = { [0:xb] }; }
    cy: coverpoint y { bins ybins[] = { [0:yb] }; }
  endgroup
  cg cv1 = new(1, 2, a, b); cg cv2 = new(3, 6, c, d);
  initial begin
    void'(cg::cx::get_coverage(cov, tot)); $display("%s 19.8.type_cp tot=%0d", tot == 6 ? "PASS" : "FAIL", tot);
    void'(cg::get_coverage(cov, tot)); $display("%s 19.8.type_cg tot=%0d", tot == 16 ? "PASS" : "FAIL", tot);
  end
endmodule
