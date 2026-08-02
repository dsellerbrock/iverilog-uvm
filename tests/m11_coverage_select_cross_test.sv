// IEEE 1800-2017 19.5/19.6: a coverpoint expression, not the width of
// its root sample formal, determines automatic bins. Cross tuple expansion
// also has no 256-tuple language limit.
module m11_coverage_select_cross_test;
  covergroup select_cg with function sample(bit [31:0] cfg);
    b0: coverpoint cfg[0];
    b1: coverpoint cfg[1];
    bx: cross b0, b1;
  endgroup

  covergroup ranges_cg with function sample(bit [5:0] a, bit [5:0] b);
    ca: coverpoint a {
      bins many = {0, 2, 4, 6, 8, 10, 12, 14, 16,
                   18, 20, 22, 24, 26, 28, 30, 32};
      ignore_bins rest = default;
    }
    cb: coverpoint b {
      bins many = {0, 2, 4, 6, 8, 10, 12, 14, 16,
                   18, 20, 22, 24, 26, 28, 30, 32};
      ignore_bins rest = default;
    }
    cx: cross ca, cb;
  endgroup

  select_cg selected = new;
  ranges_cg ranged = new;
  real cov;

  initial begin
    selected.sample(32'h0);
    selected.sample(32'h3);
    cov = selected.get_inst_coverage();
    // Two one-bit coverpoints are complete; two of four cross tuples hit.
    if (!(cov > 83.0 && cov < 84.0)) begin
      $display("FAIL: selected-expression auto bins coverage=%0f", cov);
      $fatal(1);
    end

    // Each named bin has 17 singleton ranges. Its cross range tuple has
    // 17*17=289 entries, which is legal and exceeds the old implementation
    // guard of 256.
    ranged.sample(0, 0);
    if (ranged.get_inst_coverage() != 100.0) begin
      $display("FAIL: large cross range tuple coverage=%0f",
               ranged.get_inst_coverage());
      $fatal(1);
    end

    $display("PASS: coverpoint select width and large cross tuple");
    $finish;
  end
endmodule
