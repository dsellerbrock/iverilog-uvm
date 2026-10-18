module top;
  int a, b, c, d;
  covergroup cg (int xb, yb, ref int x, y);
    coverpoint x { bins xbins[] = {[0:xb]}; }
    coverpoint y { bins ybins[] = {[0:yb]}; }
  endgroup
  cg cv1 = new(1, 2, a, b); cg cv2 = new(3, 6, c, d);
  initial begin
    a = 0; b = 0; cv1.sample();
    a = 1; cv1.sample();
    $display("INFO cv1 coverage=%f expected 66.666667", cv1.get_inst_coverage());
    $display("%s 19.3.ref_and_bins", (cv1.get_inst_coverage() > 66.6 && cv1.get_inst_coverage() < 66.7) ? "PASS" : "FAIL");
    $display("%s 19.3.instances_independent", cv2.get_inst_coverage() == 0.0 ? "PASS" : "FAIL");
  end
endmodule
