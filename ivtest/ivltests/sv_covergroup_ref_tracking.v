module sv_covergroup_ref_tracking;
  bit sampled;
  bit sampled_other;
  const bit fixed_sample = 0;

  covergroup ref_cg(ref bit ref_value);
    option.auto_bin_max = 2;
    option.get_inst_coverage = 1;
    cp: coverpoint ref_value;
  endgroup

  covergroup input_cg(input bit input_value);
    option.auto_bin_max = 2;
    option.get_inst_coverage = 1;
    cp: coverpoint input_value;
  endgroup

  ref_cg ref_instance;
  ref_cg ref_other;
  ref_cg ref_fixed;
  input_cg input_instance;

  initial begin
    sampled = 0;
    sampled_other = 0;
    ref_instance = new(sampled);
    ref_other = new(sampled_other);
    ref_fixed = new(fixed_sample);
    input_instance = new(sampled);
    ref_instance.sample();
    ref_other.sample();
    ref_fixed.sample();
    input_instance.sample();
    if (ref_instance.get_inst_coverage() != 50.0)
      $fatal(1, "ref covergroup did not sample its initial actual");
    if (ref_other.get_inst_coverage() != 50.0)
      $fatal(1, "second ref covergroup did not sample its own actual");
    if (ref_fixed.get_inst_coverage() != 50.0)
      $fatal(1, "ref covergroup did not accept a const actual");

    sampled = 1;
    ref_instance.sample();
    if (ref_other.get_inst_coverage() != 50.0)
      $fatal(1, "ref covergroup instances shared their actual binding");
    if (ref_instance.get_inst_coverage() != 100.0)
      $fatal(1, "ref covergroup did not track its changed actual");

    sampled_other = 1;
    ref_other.sample();
    if (ref_other.get_inst_coverage() != 100.0)
      $fatal(1, "second ref covergroup did not track its own actual");

    input_instance.sample();
    if (input_instance.get_inst_coverage() != 50.0)
      $fatal(1, "input covergroup did not keep its construction-time value");
    $display("PASSED");
  end
endmodule
