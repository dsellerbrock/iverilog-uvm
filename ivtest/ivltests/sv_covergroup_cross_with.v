// IEEE 1800-2017 19.6.1: a cross-bin with-clause filters product tuples
// using the contributing coverpoint values.
module sv_covergroup_cross_with;
  covergroup sleep_cg with function sample(bit enable, bit asleep);
    cg_en: coverpoint enable;
    core_asleep_value: coverpoint asleep;
    en_x_asleep: cross cg_en, core_asleep_value {
      ignore_bins impossible = en_x_asleep with
        ((cg_en == 0) && (core_asleep_value == 1));
    }
  endgroup

  sleep_cg coverage = new;

  initial begin
    // Visit every tuple except the ignored one. Both coverpoints and all
    // three remaining cross tuples must therefore be fully covered.
    coverage.sample(0, 0);
    coverage.sample(1, 0);
    coverage.sample(1, 1);
    if (coverage.get_inst_coverage() != 100.0)
      $fatal(1, "cross with filter did not remove the selected tuple");
    $display("PASSED");
    $finish;
  end
endmodule
