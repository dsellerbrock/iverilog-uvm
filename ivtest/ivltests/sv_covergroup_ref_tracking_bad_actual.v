module sv_covergroup_ref_tracking_bad_actual;
  bit sampled;

  covergroup ref_cg(ref bit ref_value);
    cp: coverpoint ref_value;
  endgroup

  ref_cg ref_instance;

  initial ref_instance = new(sampled & 1'b1);
endmodule
