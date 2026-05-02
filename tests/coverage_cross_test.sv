// Phase 62 / I1: covergroup cross declarations should generate
// cartesian-product bins.  Sample's runtime AND-of-all-records logic
// only increments a cross bin when ALL contributing coverpoint bins hit
// on the same sample.  get_inst_coverage dedups by prop_idx so multiple
// cov_bin_t records sharing the same cross-bin prop_idx are counted once.
`timescale 1ns/1ps
module top;
  class C;
    int x;
    int y;

    covergroup cg;
      cp_x: coverpoint x {
	bins lo = {[0:3]};
	bins hi = {[4:7]};
      }
      cp_y: coverpoint y {
	bins yl = {[0:1]};
	bins yh = {[2:3]};
      }
      cross cp_x, cp_y;
    endgroup

    function new(); cg = new(); endfunction
    function void do_sample(); cg.sample(); endfunction
    function real get_cov(); return cg.get_inst_coverage(); endfunction
  endclass

  initial begin
    real cov;
    C c = new();
    c.x = 2; c.y = 0; c.do_sample();  // cp_x.lo + cp_y.yl + xbin_0_0
    c.x = 5; c.y = 3; c.do_sample();  // cp_x.hi + cp_y.yh + xbin_1_1

    cov = c.get_cov();

    // 8 unique bins total (4 single + 4 cross).  Hits: 4 single + 2 cross = 6.
    // Coverage = 6/8 = 75.0%.  Tolerate small rounding.
    if (cov > 70.0 && cov < 80.0)
      $display("PASS: cross-coverage = %0.1f%% (expected ~75%%)", cov);
    else begin
      $display("FAIL: cross-coverage = %0.1f%% (expected ~75%%)", cov);
      $fatal(1, "cross coverage broken");
    end
    $finish;
  end
endmodule
