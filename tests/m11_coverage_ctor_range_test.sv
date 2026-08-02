// IEEE 1800-2017 19.3/19.5: constructor-dependent arrayed bin ranges
// have a different active bin set in each covergroup instance.
module m11_coverage_ctor_range_test;
  covergroup cg(int maximum) with function sample(int value);
    cp: coverpoint value {
      bins values[] = {[1:maximum]};
    }
  endgroup

  cg short_range, long_range;
  real short_cov, long_cov;

  initial begin
    short_range = new(2);
    long_range = new(4);
    short_range.sample(1);
    short_range.sample(2);
    long_range.sample(1);
    long_range.sample(2);

    short_cov = short_range.get_inst_coverage();
    long_cov = long_range.get_inst_coverage();
    if (short_cov != 100.0 || long_cov != 50.0) begin
      $display("M11 COVERGROUP CTOR RANGE TEST: FAIL short=%0.1f long=%0.1f",
               short_cov, long_cov);
      $finish(1);
    end
    $display("M11 COVERGROUP CTOR RANGE TEST: PASS");
    $finish(0);
  end
endmodule
