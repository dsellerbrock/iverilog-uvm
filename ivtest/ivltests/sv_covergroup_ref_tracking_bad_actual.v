module sv_covergroup_ref_tracking_bad_actual;
  bit sampled;

  covergroup ref_cg(ref bit ref_value);
    cp: coverpoint ref_value;
  endgroup

  ref_cg instance;

  initial instance = new(sampled & 1'b1);
endmodule
