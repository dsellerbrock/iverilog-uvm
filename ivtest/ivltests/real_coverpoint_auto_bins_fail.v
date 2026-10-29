module real_coverpoint_auto_bins_fail;
  real value;
  covergroup cg; cp: coverpoint value; endgroup
  cg cov = new;
endmodule
