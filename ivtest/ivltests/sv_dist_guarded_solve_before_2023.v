// A dist under an `if' whose condition is decided earlier by `solve ... before'
// is an ordinary weighted draw once the condition is known (IEEE 1800-2017/2023
// 18.5.4, 18.5.10). It fell back to the optimizer and always produced the
// heaviest value: `ov dist { True :/ 70, False :/ 30 }' gave True every time
// (OpenTitan entropy_src fw_over_enable_c).
class guarded_c;
  rand bit sel;
  rand bit ov;
  constraint sel_c { sel dist { 1 :/ 30, 0 :/ 70 }; }
  constraint ov_c {
    solve sel before ov;
    if (sel) ov dist { 1 :/ 70, 0 :/ 30 };
    else     ov dist { 1 :/ 50, 0 :/ 50 };
  }
endclass

module main;
  int errors;
  initial begin
    guarded_c g;
    int n_sel1, n_ov_sel1, n_sel0, n_ov_sel0;
    g = new;
    repeat (500) begin
      if (!g.randomize()) begin $display("FAILED randomize"); errors++; end
      if (g.sel) begin n_sel1++; n_ov_sel1 += g.ov; end
      else begin n_sel0++; n_ov_sel0 += g.ov; end
    end
    // sel=1 about 30% of 500 (150 +- 5 sigma = 40); ov=1 given sel=1 about 70%.
    if (n_sel1 < 100 || n_sel1 > 200) begin
      $display("FAILED sel split %0d/500", n_sel1); errors++;
    end
    if (n_ov_sel1 * 100 < n_sel1 * 50 || n_ov_sel1 * 100 > n_sel1 * 88) begin
      $display("FAILED ov|sel=1 %0d/%0d (expect 70%%)", n_ov_sel1, n_sel1); errors++;
    end
    if (n_ov_sel0 * 100 < n_sel0 * 38 || n_ov_sel0 * 100 > n_sel0 * 62) begin
      $display("FAILED ov|sel=0 %0d/%0d (expect 50%%)", n_ov_sel0, n_sel0); errors++;
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
