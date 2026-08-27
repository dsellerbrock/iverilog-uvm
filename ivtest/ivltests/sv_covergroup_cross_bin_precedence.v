// IEEE 1800-2017/2023 19.6: named cross-bin selections are evaluated
// independently, with illegal_bins taking precedence over ignore_bins and
// ignore_bins taking precedence over ordinary bins.  The declaration order
// below is deliberately adversarial: both ordinary bins come first, the broad
// ignore comes next, and the narrower illegal bin is last.
module top;
  bit [1:0] a;
  bit [1:0] b;

  function automatic bit near(real got, real want);
    return got > want - 0.01 && got < want + 0.01;
  endfunction

  covergroup cg;
    option.per_instance = 1;
    cp_a: coverpoint a {
      bins zero = {0};
      bins one  = {1};
      bins two  = {2};
    }
    cp_b: coverpoint b {
      bins zero = {0};
      bins one  = {1};
      bins two  = {2};
    }
    axb: cross cp_a, cp_b {
      bins broad_normal = binsof(cp_a) intersect {1, 2};
      bins overlap_normal = binsof(cp_b.zero);
      ignore_bins broad_ignore = binsof(cp_a) intersect {0, 1};
      illegal_bins late_illegal =
          binsof(cp_a.one) && binsof(cp_b.two);
    }
  endgroup

  cg cov = new;

  initial begin
    // The legal tuple belongs to both ordinary named bins.  Each must count.
    a = 2;
    b = 0;
    cov.sample();
    if (!near(cov.get_inst_coverage(), 55.5556))
      $fatal(1, "overlapping ordinary cross bins did not count independently");

    // The broad ignore selection wins over both ordinary selections, while
    // leaving the source coverpoints sampled.
    a = 0;
    b = 1;
    cov.sample();
    if (!near(cov.get_inst_coverage(), 77.7778))
      $fatal(1, "ignore cross precedence or source sampling is incorrect");

    // Exactly one non-fatal illegal-bin diagnostic is expected between these
    // markers.  The illegal selection is declared after an overlapping ignore,
    // and must nevertheless win.  It must not suppress either source
    // coverpoint; this sample completes both coverpoints to 100%.
    $display("EXPECT_ILLEGAL_BEGIN");
    a = 1;
    b = 2;
    cov.sample();
    $display("EXPECT_ILLEGAL_END");
    if (!near(cov.get_inst_coverage(), 100.0))
      $fatal(1, "illegal cross changed source coverpoint sampling");

    $display("PASSED");
    $finish;
  end
endmodule
