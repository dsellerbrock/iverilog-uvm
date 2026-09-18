// DD-042: IEEE 1800-2017/2023 19.6.1 (A.2.10)'s `with' suffixes the
// general, recursive select_expression -- not only the bare
// cross_identifier alternative sv_covergroup_cross_with.v exercises.
// `!binsof(cp) intersect {...} with (...)' and
// `(binsof(a) && binsof(b)) with (...)' are both legal, and both are used
// by real, unmodified OpenTitan DV source (hw/ip/csrng/dv/cov/csrng_cov_if.sv
// and hw/ip/pwm/dv/env/pwm_env_cov.sv) -- previously a raw `syntax error'
// since the grammar only accepted a bare bins_name before `with'. These two
// ignore_bins entries mirror the csrng file's own complementary
// `!binsof(...)  intersect {...} with (...)' / `binsof(...) intersect {...}
// with (...)' pair exactly (just against a smaller cross so the expected
// coverage math stays simple).
module sv_covergroup_cross_with_select_expr;
  bit [1:0] a;
  bit [1:0] b;

  covergroup cg;
    option.per_instance = 1;
    cp_a: coverpoint a {
      bins z = {0};
      bins o = {1};
      bins t = {2};
    }
    cp_b: coverpoint b {
      bins z = {0};
      bins o = {1};
    }
    axb: cross cp_a, cp_b {
      ignore_bins not2_and_rdy = !binsof(cp_a) intersect {2} with (cp_b == 1);
      ignore_bins is2_and_rdy  = binsof(cp_a) intersect {2} with (cp_b == 1);
    }
  endgroup

  cg cov = new;

  initial begin
    // Both ignore_bins entries together select every (a, b==1) tuple,
    // leaving only the three (a, b==0) tuples as real cross bins. Visit
    // those three, plus (a==0, b==1) just to complete cp_b's own bin
    // coverage (a coverpoint's own bin coverage is independent of any
    // cross ignore_bins over it) -- but deliberately never sample
    // (a==1, b==1) or (a==2, b==1) as cross tuples.
    a = 0; b = 0; cov.sample();
    a = 1; b = 0; cov.sample();
    a = 2; b = 0; cov.sample();
    a = 0; b = 1; cov.sample();
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "cross with-clause over a general select_expression left a tuple uncovered");

    // If the with-predicate over the general select_expression did NOT
    // actually exclude (a==1, b==1) and (a==2, b==1) from the cross's own
    // denominator, coverage would already have been below 100.0 above --
    // this second check makes the exclusion explicit: sampling them now
    // must not be NEEDED to reach (or stay at) 100%.
    a = 1; b = 1; cov.sample();
    a = 2; b = 1; cov.sample();
    if (cov.get_inst_coverage() != 100.0)
      $fatal(1, "sampling the excluded tuples changed coverage unexpectedly");

    $display("PASSED");
    $finish;
  end
endmodule
