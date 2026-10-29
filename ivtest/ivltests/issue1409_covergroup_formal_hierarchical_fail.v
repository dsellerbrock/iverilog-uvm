module issue1409_covergroup_formal_hierarchical_fail;
  int value = 1;
  covergroup cg(int sampled);
    cp: coverpoint sampled;
  endgroup
  cg cov = new(value);
  initial $display("FORMAL=%0d", cov.sampled);
endmodule
