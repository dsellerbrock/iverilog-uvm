module sv_covergroup_ref_automatic_actual_unsupported;
  covergroup ref_cg(ref logic value);
    cp: coverpoint value;
  endgroup

  task automatic sample_automatic_actual;
    logic local_value;
    ref_cg cov;
    local_value = 0;
    cov = new(local_value);
    cov.sample();
  endtask

  initial sample_automatic_actual();
endmodule
